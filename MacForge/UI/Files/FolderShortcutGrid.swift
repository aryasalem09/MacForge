import SwiftUI

struct FolderShortcutGrid: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        if environment.pinnedFolders.isEmpty {
            ContentUnavailableView("No pinned folders", systemImage: "folder.badge.plus", description: Text("Add a folder to enable File Hub actions."))
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                ForEach(environment.pinnedFolders) { folder in
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.teal)
                        Text(folder.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(folder.displayPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack {
                            Button("Open", systemImage: "arrow.up.forward.app") {
                                environment.openFolder(folder)
                            }
                            Button("Reveal", systemImage: "magnifyingglass") {
                                environment.revealFolder(folder)
                            }
                            Spacer()
                            Menu {
                                ForEach(FolderTemplate.allCases) { template in
                                    Button(template.label) {
                                        environment.createFolderTemplate(named: template, in: folder)
                                    }
                                }
                                Divider()
                                Button("Forget Access", role: .destructive) {
                                    environment.forgetFolder(folder)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
