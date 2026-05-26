import SwiftUI

struct BulkRenameView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedURLs: [URL] = []
    @State private var request = BulkRenameRequest.empty
    @State private var previews: [BulkRenamePreviewItem] = []

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
                    applyRename()
                }
                .disabled(previews.isEmpty || previews.contains { $0.hasCollision })
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
        var results: [CommandResult] = []
        for preview in previews where preview.changed && !preview.hasCollision {
            do {
                try FileManager.default.moveItem(at: preview.originalURL, to: preview.newURL)
                results.append(.success("Rename", "Renamed \(preview.originalURL.lastPathComponent) to \(preview.newName)."))
            } catch {
                results.append(.failure("Rename", "Could not rename \(preview.originalURL.lastPathComponent).", details: [error.localizedDescription]))
            }
        }
        results.forEach(environment.append)
        selectedURLs = previews.map(\.newURL)
        refreshPreview()
    }
}
