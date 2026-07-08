import Foundation

struct AutomationPermissionNotes {
    static let appleEventsUsage = "The now-playing widgets (Music, Spotify, QuickTime, browser hints) read playback state with Apple Events. macOS shows a consent prompt per app the first time each source is used; everything else in MacForge works without Automation."
    static let dockTweaksUsage = "Experimental Dock Tweaks use local /usr/bin/defaults commands and restart Dock with /usr/bin/killall Dock. They do not use root access, private APIs, or shell interpolation."
}
