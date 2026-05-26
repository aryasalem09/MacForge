import SwiftUI

struct NotchShelfView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        HStack(spacing: 10) {
            if environment.notchConfig.showClock {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    NotchWidgetView(systemImage: "clock") {
                        Text(context.date, style: .time)
                            .monospacedDigit()
                    }
                }
            }

            if environment.notchConfig.showCurrentApp {
                NotchWidgetView(systemImage: "app.dashed") {
                    Text(NSWorkspace.shared.frontmostApplication?.localizedName ?? "No App")
                        .lineLimit(1)
                        .frame(maxWidth: 120)
                }
            }

            if environment.notchConfig.showWindowActions {
                HStack(spacing: 6) {
                    shelfButton(.leftHalf)
                    shelfButton(.rightHalf)
                    shelfButton(.maximize)
                    shelfButton(.center)
                }
            }

            if environment.notchConfig.showFolders, let folder = environment.pinnedFolders.first {
                Button {
                    environment.openFolder(folder)
                } label: {
                    Label(folder.name, systemImage: "folder")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
            }

            if environment.notchConfig.showPresets, let preset = environment.appPresets.first {
                Button {
                    Task { await environment.runPreset(preset) }
                } label: {
                    Label(preset.name, systemImage: preset.iconName)
                        .lineLimit(1)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: environment.notchConfig.cornerRadius))
        }
        .clipShape(RoundedRectangle(cornerRadius: environment.notchConfig.cornerRadius))
    }

    private func shelfButton(_ layout: WindowLayoutType) -> some View {
        Button {
            Task { await environment.tileFocusedWindow(layout) }
        } label: {
            Image(systemName: layout.symbolName)
        }
        .help(layout.label)
        .buttonStyle(.borderless)
    }
}
