import SwiftUI

struct BulkRenameView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedURLs: [URL] = []
    @State private var request = BulkRenameRequest.empty
    @State private var previews: [BulkRenamePreviewItem] = []
    @State private var showingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button("Choose Files", systemImage: "doc.badge.plus") {
                    chooseFiles()
                }
                Button("Refresh Preview", systemImage: "arrow.clockwise") {
                    refreshPreview()
                }
                Button("Apply Rename", systemImage: "checkmark.circle") {
                    showingConfirmation = true
                }
                .disabled(!environment.bulkRenameEngine.canApply(previews))
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Prefix")
                    TextField("Prefix", text: $request.prefix)
                    Text("Suffix")
                    TextField("Suffix", text: $request.suffix)
                }
                GridRow {
                    Text("Find")
                    TextField("Find", text: $request.findText)
                    Text("Replace")
                    TextField("Replace", text: $request.replaceText)
                }
                GridRow {
                    Toggle("Sequence", isOn: $request.sequenceEnabled)
                    Stepper("Start \(request.sequenceStart)", value: $request.sequenceStart, in: 0...9999)
                    Toggle("Preserve extension", isOn: $request.preserveExtension)
                    EmptyView()
                }
            }

            if previews.isEmpty {
                ContentUnavailableView("No rename preview", systemImage: "textformat", description: Text("Choose files and configure a rename pattern."))
            } else {
                if !previews.contains(where: \.changed) {
                    Label("No selected files would be renamed.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                if previews.contains(where: \.hasCollision) {
                    Label("Resolve collisions before applying.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                ForEach(previews) { item in
                    HStack {
                        Image(systemName: item.hasCollision ? "exclamationmark.triangle.fill" : "arrow.right.circle")
                            .foregroundStyle(item.hasCollision ? .orange : .secondary)
                        Text(item.originalURL.lastPathComponent)
                        Image(systemName: "arrow.right")
                        Text(item.newName)
                            .fontWeight(item.changed ? .semibold : .regular)
                        Spacer()
                        if item.hasCollision {
                            Text("Collision")
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .onChange(of: request) { _, _ in refreshPreview() }
        .sheet(isPresented: $showingConfirmation) {
            BulkRenameConfirmationView(
                previews: previews.filter(\.changed),
                onCancel: { showingConfirmation = false },
                onApply: applyRename
            )
        }
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            selectedURLs = panel.urls
            refreshPreview()
        }
    }

    private func refreshPreview() {
        previews = environment.bulkRenameEngine.preview(urls: selectedURLs, request: request)
    }

    private func applyRename() {
        let originalPreviews = previews
        let results = environment.bulkRenameEngine.apply(previews: previews)
        results.forEach(environment.append)
        selectedURLs = originalPreviews.map { $0.changed && !$0.hasCollision ? $0.newURL : $0.originalURL }
        showingConfirmation = false
        refreshPreview()
    }
}

private struct BulkRenameConfirmationView: View {
    var previews: [BulkRenamePreviewItem]
    var onCancel: () -> Void
    var onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apply Rename?")
                .font(.headline)
            Text("\(previews.count) file(s) will be renamed. Renames can be confusing to undo manually, so review the list before applying.")
                .foregroundStyle(.secondary)

            List(Array(previews.prefix(100))) { item in
                HStack {
                    Text(item.originalURL.lastPathComponent)
                    Image(systemName: "arrow.right")
                    Text(item.newName)
                        .fontWeight(.semibold)
                }
            }
            .frame(minHeight: 220)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Apply", systemImage: "checkmark.circle", action: onApply)
                    .disabled(previews.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 380)
    }
}
