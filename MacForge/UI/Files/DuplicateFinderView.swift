import SwiftUI

struct DuplicateFinderView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selectedFolderID: UUID?
    @State private var groups: [DuplicateGroup] = []
    @State private var isScanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Folder", selection: Binding(get: {
                    selectedFolderID ?? environment.pinnedFolders.first?.id
                }, set: { selectedFolderID = $0 })) {
                    ForEach(environment.pinnedFolders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
                Button(isScanning ? "Scanning..." : "Scan", systemImage: "magnifyingglass") {
                    scan()
                }
                .disabled(isScanning || environment.pinnedFolders.isEmpty)
            }

            if groups.isEmpty {
                ContentUnavailableView("No duplicate groups", systemImage: "doc.on.doc", description: Text("MacForge groups by file size first, then hashes only candidates with matching sizes."))
            } else {
                ForEach(groups) { group in
                    DisclosureGroup("\(group.files.count) files, \(ByteCountFormatter.string(fromByteCount: group.sizeBytes, countStyle: .file))") {
                        ForEach(group.files) { file in
                            HStack {
                                Text(file.url.path)
                                    .lineLimit(1)
                                Spacer()
                                Button("Reveal", systemImage: "magnifyingglass") {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func scan() {
        guard let id = selectedFolderID ?? environment.pinnedFolders.first?.id,
              let shortcut = environment.pinnedFolders.first(where: { $0.id == id }) else {
            return
        }

        isScanning = true
        environment.notchIslandActivityCenter.showActivity(
            kind: .duplicateScan,
            title: "Duplicate Scan",
            message: shortcut.name,
            symbolName: "doc.on.doc",
            progress: nil
        )
        Task {
            groups = await environment.folderAccessStore.withResolvedURL(shortcut) { url in
                await environment.duplicateFinder.findDuplicates(in: url)
            }
            environment.append(.success("Duplicate Scan", "Found \(groups.count) duplicate group(s)."))
            isScanning = false
        }
    }
}
