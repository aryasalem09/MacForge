import SwiftUI

@main
struct MacForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup("MacForge", id: "main") {
            ContentView()
                .environmentObject(environment)
                .environmentObject(environment.liveIslandCoordinator)
                .environmentObject(environment.agentActivityCenter)
                .environmentObject(environment.notchIslandActivityCenter)
                .onAppear {
                    environment.refreshPermissions()
                    environment.refreshWallpaperStates()
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("MacForge") {
                Button("Toggle Notch Shelf") {
                    environment.toggleNotchShelf()
                }
                Divider()
                Button("Refresh Windows") {
                    Task { await environment.refreshWindows() }
                }
            }
        }

        MenuBarExtra("MacForge", systemImage: "hammer") {
            MacForgeMenuBarExtra()
                .environmentObject(environment)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(environment)
                .frame(width: 720, height: 560)
        }
    }
}
