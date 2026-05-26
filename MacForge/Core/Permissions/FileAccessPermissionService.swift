import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
struct FileAccessPermissionService {
    func chooseFolder(prompt: String = "Choose a folder for MacForge") -> URL? {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseImage(prompt: String = "Choose a wallpaper image") -> URL? {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
