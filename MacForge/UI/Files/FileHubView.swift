import SwiftUI

struct FileHubView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Add Pinned Folder", systemImage: "folder.badge.plus") {
                    environment.addPinnedFolder()
                }
                Spacer()
                Text("\(environment.pinnedFolders.count) folder(s)")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            TabView {
                ScrollView {
                    FolderShortcutGrid()
                        .padding(24)
                }
                .tabItem { Label("Pinned", systemImage: "folder") }

                ScrollView {
                    FileRuleEditorView()
                        .padding(24)
                }
                .tabItem { Label("Rules", systemImage: "line.3.horizontal.decrease.circle") }

                ScrollView {
                    BulkRenameView()
                        .padding(24)
                }
                .tabItem { Label("Rename", systemImage: "textformat") }

                ScrollView {
                    DuplicateFinderView()
                        .padding(24)
                }
                .tabItem { Label("Duplicates", systemImage: "doc.on.doc") }
            }
        }
    }
}
