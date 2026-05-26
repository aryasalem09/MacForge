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

                HStack {
                    Button("Save Rule", systemImage: "plus.circle") {
                        saveRule()
                    }
                    .disabled(environment.pinnedFolders.isEmpty)

                    Button("Preview First Matching Rule", systemImage: "eye") {
                        previewFirstRule()
                    }
                    .disabled(environment.fileRules.isEmpty)
                }
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
                HStack {
                    Image(systemName: rule.dryRunOnly ? "eye" : "play.circle")
                    VStack(alignment: .leading) {
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
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
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

    private func previewFirstRule() {
        guard let rule = environment.fileRules.first,
              let sourceID = rule.sourceFolderID,
              let shortcut = environment.pinnedFolders.first(where: { $0.id == sourceID }),
              let sourceURL = environment.folderAccessStore.resolve(shortcut) else {
            previewLines = ["Missing source folder access."]
            return
        }

        let previews = environment.fileOrganizerService.preview(rule: rule, sourceURL: sourceURL) { folderID in
            environment.pinnedFolders.first(where: { $0.id == folderID }).flatMap { environment.folderAccessStore.resolve($0) }
        }
        previewLines = previews.prefix(20).map { "\($0.fileURL.lastPathComponent): \($0.actionDescription)" }
        if previewLines.isEmpty {
            previewLines = ["No files matched."]
        }
    }
}
