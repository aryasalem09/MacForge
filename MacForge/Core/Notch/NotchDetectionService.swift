import AppKit
import Foundation

struct NotchInfo: Hashable {
    var screenName: String
    var hasLikelyNotch: Bool
    var topSafeAreaInset: CGFloat
    var frame: CGRect
    var visibleFrame: CGRect
}

struct NotchDetectionService {
    func detect(on screen: NSScreen? = NSScreen.main) -> NotchInfo? {
        guard let screen else { return nil }
        let topInset = screen.safeAreaInsets.top
        return NotchInfo(
            screenName: screen.localizedName,
            hasLikelyNotch: topInset > 0,
            topSafeAreaInset: topInset,
            frame: screen.frame,
            visibleFrame: screen.visibleFrame
        )
    }
}
