import Foundation

struct AutomationPermissionNotes {
    static let appleEventsUsage = "MacForge does not use AppleScript for core features. If a future workflow needs Apple Events, macOS will show a consent prompt before any target app is automated."
    static let dockTweaksUsage = "Experimental Dock Tweaks use local /usr/bin/defaults commands and restart Dock with /usr/bin/killall Dock. They do not use root access, private APIs, or shell interpolation."
}
