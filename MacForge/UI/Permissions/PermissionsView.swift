import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("MacForge only uses permissions after you grant them. Window controls use Accessibility, File Hub uses selected folders, and Dock tweaks stay disabled until you explicitly enable the experimental switch.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(environment.permissionStates) { state in
                    PermissionRowView(state: state, action: action(for: state))
                }

                HStack {
                    Button("Refresh Permissions", systemImage: "arrow.clockwise") {
                        environment.refreshPermissions()
                    }
                    Button("Add Folder Access", systemImage: "folder.badge.plus") {
                        environment.addPinnedFolder()
                    }
                }
            }
            .padding(24)
        }
    }

    private func action(for state: PermissionState) -> (() -> Void)? {
        switch state.id {
        case "accessibility":
            return { environment.requestAccessibility() }
        case "file-access":
            return { environment.addPinnedFolder() }
        default:
            return nil
        }
    }
}
