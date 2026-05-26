import SwiftUI

struct WallpaperPickerView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Button("Add Wallpaper Preset", systemImage: "photo.badge.plus") {
            environment.addWallpaperPreset()
        }
    }
}
