import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable {
    case dashboard
    case permissions
    case notchShelf
    case windows
    case dock
    case desktop
    case files
    case presets
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .permissions: "Permissions"
        case .notchShelf: "Notch Shelf"
        case .windows: "Windows"
        case .dock: "Dock"
        case .desktop: "Desktop"
        case .files: "Files"
        case .presets: "Presets"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .permissions: "lock.shield"
        case .notchShelf: "macbook.gen2"
        case .windows: "rectangle.3.group"
        case .dock: "dock.rectangle"
        case .desktop: "photo.on.rectangle"
        case .files: "folder"
        case .presets: "sparkles.rectangle.stack"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var selection: SidebarDestination? = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .permissions:
                    PermissionsView()
                case .notchShelf:
                    NotchShelfSettingsView()
                case .windows:
                    WindowManagerView()
                case .dock:
                    DockSettingsView()
                case .desktop:
                    WallpaperView()
                case .files:
                    FileHubView()
                case .presets:
                    PresetsView()
                case .settings:
                    SettingsView()
                }
            }
            .navigationTitle((selection ?? .dashboard).title)
        }
        .frame(minWidth: 1020, minHeight: 680)
        .task {
            environment.refreshPermissions()
            await environment.refreshWindows()
        }
    }
}
