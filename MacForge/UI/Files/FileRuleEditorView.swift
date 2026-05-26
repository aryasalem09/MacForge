import SwiftUI

private enum RuleActionChoice: String, CaseIterable, Identifiable {
    case move
    case copy
    case trash

    var id: String { rawValue }
    var label: String {
        switch self {
        case .move: "Move"
        case .copy: "Copy"
        case .trash: "Move to Trash"
        }
    }
}

struct FileRuleEditorView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var ruleName = "Images"
    @State private var extensionText = "png"
    @State private var sourceFolderID: UUID?
    @State private var destinationFolderID: UUID?
    @State private var actionChoice: RuleActionChoice = .move
    @State private var dryRunOnly = true
    @State private var previewLines: [String] = []
    @State private var rulePendingConfirmation: FileRule?
    @State private var confirmationPreviews: [FileRulePreview] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create File Rule")
                    .font(.headline)
                TextField("Rule name", text: $ruleName)
                TextField("File extension", text: $extensionText)
                Picker("Source folder", selection: Binding(get: {
                    sourceFolderID ?? environment.pinnedFolders.first?.id
                }, set: { sourceFolderID = $0 })) {
                    ForEach(environment.pinnedFolders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
                Picker("Action", selection: $actionChoice) {
                    ForEach(RuleActionChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                if actionChoice != .trash {
                    Picker("Destination folder", selection: Binding(get: {
                        destinationFolderID ?? environment.pinnedFolders.first?.id
                    }, set: { destinationFolderID = $0 })) {
                        ForEach(environment.pinnedFolders) { folder in
                            Text(folder.name).tag(Optional(folder.id))
                        }
                    }
                }
                Toggle("Dry run only", isOn: $dryRunOnly)

                Button("Save Rule", systemImage: "plus.circle") {
                    saveRule()
                }
                .disabled(environment.pinnedFolders.isEmpty)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            if !previewLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview")
                        .font(.headline)
                    ForEach(previewLines, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            Text("Rules")
                .font(.headline)
            ForEach(environment.fileRules) { rule in
                ruleRow(rule)
            }
        }
        .sheet(item: $rulePendingConfirmation) { rule in
            FileRuleApplyConfirmationView(
                rule: rule,
                previews: confirmationPreviews,
                onCancel: {
                    rulePendingConfirmation = nil
                    confirmationPreviews = []
                },
                onApply: {
                    applyConfirmed(rule)
                }
            )
        }
    }

    private func ruleRow(_ rule: FileRule) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: rule.dryRunOnly ? "eye" : "play.circle")
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                Text("\(rule.matchKind.label) -> \(rule.action.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(
                get: { rule.isEnabled },
                set: { newValue in
                    if let index = environment.fileRules.firstIndex(where: { $0.id == rule.id }) {
                        environment.fileRules[index].isEnabled = newValue
                    }
                }
            ))
            .labelsHidden()
            Button("Preview", systemImage: "eye") {
                preview(rule)
            }
            .disabled(!rule.isEnabled)
            Button("Apply", systemImage: "checkmark.circle") {
                prepareApply(rule)
            }
            .disabled(!rule.isEnabled)
            Button("Remove", systemImage: "trash", role: .destructive) {
                environment.fileRules.removeAll { $0.id == rule.id }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func saveRule() {
        let sourceID = sourceFolderID ?? environment.pinnedFolders.first?.id
        let destinationID = destinationFolderID ?? environment.pinnedFolders.first?.id
        let action: FileRuleAction
        switch actionChoice {
        case .move:
            guard let destinationID else { return }
            action = .moveToFolder(destinationID)
        case .copy:
            guard let destinationID else { return }
            action = .copyToFolder(destinationID)
        case .trash:
            action = .moveToTrash
        }

        let rule = FileRule(
            name: ruleName.isEmpty ? "Untitled Rule" : ruleName,
            sourceFolderID: sourceID,
            matchKind: .fileExtension(extensionText),
            action: action,
            dryRunOnly: dryRunOnly
        )
        environment.fileRules.append(rule)
        environment.append(.success("File Rule", "Saved \(rule.name)."))
    }

    private func preview(_ rule: FileRule) {
        switch environment.previewFileRule(rule) {
        case .success(let previews):
            previewLines = previews.prefix(30).map { "\($0.fileURL.lastPathComponent): \($0.actionDescription)" }
            if previewLines.isEmpty {
                previewLines = ["No files matched."]
            }
        case .failure(let result):
            previewLines = [result.message] + result.details
            environment.append(result)
        }
    }

    private func prepareApply(_ rule: FileRule) {
        switch environment.previewFileRule(rule) {
        case .success(let previews):
            confirmationPreviews = previews
            if rule.dryRunOnly {
                previewLines = previews.isEmpty
                    ? ["Dry run is enabled. No files matched."]
                    : ["Dry run is enabled. No files were changed."] + previews.prefix(30).map { "\($0.fileURL.lastPathComponent): \($0.actionDescription)" }
                environment.append(.success("File Rule Preview", "Dry run is enabled for \(rule.name). No files were changed."))
            } else {
                rulePendingConfirmation = rule
            }
        case .failure(let result):
            previewLines = [result.message] + result.details
            environment.append(result)
        }
    }

    private func applyConfirmed(_ rule: FileRule) {
        let results = environment.applyFileRule(rule, dryRun: false)
        results.forEach(environment.append)
        previewLines = results.map { "\($0.title): \($0.message)" }
        rulePendingConfirmation = nil
        confirmationPreviews = []
    }
}

private struct FileRuleApplyConfirmationView: View {
    var rule: FileRule
    var previews: [FileRulePreview]
    var onCancel: () -> Void
    var onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apply \(rule.name)?")
                .font(.headline)
            Text("\(previews.count) matched file(s). \(rule.action.effectDescription)")
                .foregroundStyle(.secondary)

            if previews.contains(where: \.isDestructive) {
                Label("This action moves files to Trash. Nothing is permanently deleted.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            List(Array(previews.prefix(80))) { preview in
                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.fileURL.lastPathComponent)
                    Text(preview.actionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 180)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Apply", systemImage: "checkmark.circle", action: onApply)
                    .disabled(previews.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 360)
    }
}
