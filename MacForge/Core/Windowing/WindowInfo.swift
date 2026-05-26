import CoreGraphics
import Foundation

struct WindowInfo: Identifiable, Codable, Hashable {
    var id: UUID
    var appName: String
    var bundleIdentifier: String?
    var pid: Int32
    var title: String
    var frame: CGRect
    var screenIdentifier: String?
    var isFocused: Bool
    var canMove: Bool
    var canResize: Bool

    init(
        id: UUID = UUID(),
        appName: String,
        bundleIdentifier: String? = nil,
        pid: Int32,
        title: String,
        frame: CGRect,
        screenIdentifier: String? = nil,
        isFocused: Bool = false,
        canMove: Bool = true,
        canResize: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.title = title
        self.frame = frame
        self.screenIdentifier = screenIdentifier
        self.isFocused = isFocused
        self.canMove = canMove
        self.canResize = canResize
    }
}
