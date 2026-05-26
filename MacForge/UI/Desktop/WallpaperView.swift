import SwiftUI

struct WallpaperView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    WallpaperPickerView()
                    Button("Refresh Current Wallpaper", systemImage: "arrow.clockwise") {
                        environment.refreshWallpaperStates()
                    }
                }

                SectionHeader("Current Displays")
                ForEach(environment.wallpaperStates) { state in
                    HStack {
                        Image(systemName: "display")
                        VStack(alignment: .leading) {
                            Text(state.localizedName)
                            Text(state.imagePath ?? "No wallpaper URL available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                SectionHeader("Wallpaper Presets")
                if environment.wallpaperPresets.isEmpty {
                    ContentUnavailableView("No wallpaper presets", systemImage: "photo", description: Text("Choose a local image file to save a preset."))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                        ForEach(environment.wallpaperPresets) { preset in
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.pink)
                                Text(preset.name)
                                    .font(.headline)
                                Text(preset.imagePath)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Button("Apply", systemImage: "checkmark.circle") {
                                    Task { await environment.applyWallpaperPreset(preset) }
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

struct SectionHeader: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .padding(.top, 4)
    }
}
