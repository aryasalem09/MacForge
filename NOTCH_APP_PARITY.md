# Notch App Parity Audit

Date: June 9, 2026

MacForge now targets practical NotchNook-style user-visible parity while staying inside public macOS APIs, explicit user consent, and honest limitations. The comparison below is based on inspected MacForge code and public competitor descriptions from The Verge, MacStories, MediaMate, App Store listings, and Boring Notch.

## Sources Inspected

- MacForge code: `Core/Notch`, `UI/Notch`, `App/AppEnvironment.swift`, `Core/LiveIsland`, `Core/Files`, `Core/Dock`, `Core/Desktop`, and tests.
- The Verge described NotchNook as expanding from the notch with media controls, widgets, a file/app tray, click/swipe/hover-style access, and non-notched Mac fallback: https://www.theverge.com/2024/7/21/24202914/notchnook-mac-app-dynamic-island-iphone
- MacStories described MediaMate's notch style, media controls, and external-display floating fallback: https://www.macstories.net/reviews/notchnook-and-mediamate-two-apps-to-add-a-dynamic-island-to-the-mac/
- MediaMate's site lists Now Playing in the notch and all-Mac support: https://wouter01.github.io/MediaMate/
- App Store listings for notch shelf apps describe timers, file trays, media, weather/calendar-like widgets, and non-notched fallbacks: https://apps.apple.com/us/app/dynamic-notch-island-perch/id6742724228
- Boring Notch lists media controls, visualizations, a file shelf, calendar/reminders, and system HUD-style surfaces: https://theboring.name/

## Parity Matrix

| Behavior | Status | MacForge implementation | Limitation |
| --- | --- | --- | --- |
| 1. Collapsed notch pill | Already implemented | `NotchIslandCollapsedView` is a tiny black pill, and `NotchGeometryService` anchors it below public safe-area/notch geometry. | It cannot draw into hidden camera pixels. |
| 2. Hover/click/swipe expansion | Implement now | Hover/click existed in `NotchIslandView`; this sprint adds vertical swipe expand/collapse and horizontal media previous/next gestures when supported. | Trackpad gesture recognition is app-panel local, not an OS gesture hook. |
| 3. Music now playing | Implement now | `AppleMusicProvider` and `SpotifyProvider` poll public Automation/AppleScript for title, artist, album, playback state, elapsed, and duration when the app is running. | Requires macOS Automation consent. No private MediaRemote usage. |
| 4. Media controls | Implement now | Apple Music and Spotify support play/pause/next/previous/open app. QuickTime supports best-effort play/pause/open app. | Browser controls need the optional bridge; generic media apps expose open-only. |
| 5. Video playback display | Implement best-effort | `QuickTimeProvider` reads front-document title, playing state, position, and duration when public Automation exposes it. `GenericMediaAppProvider` detects known video apps. | Universal per-app video state is blocked without private APIs, injection, or screen recording. |
| 6. Browser media display | Implement best-effort / Requires companion extension | `BrowserMediaProvider` optionally reads active tab title/URL for Safari, Chrome, Brave, and Edge and labels it honestly as possible browser media. `MacForgeBrowserBridge` scaffolds future Media Session API metadata. | Exact browser playback state and artwork require the user-installed extension bridge. |
| 7. Tray/drop zone | Implement now | Expanded island has a temporary drag-and-drop tray. Dropped files can be revealed and cleared; files are never moved or mutated. | It is a temporary tray, not a full file manager or AirDrop replacement. |
| 8. Downloads activity | Implement now | `DownloadsProvider` watches only the user-selected folder bookmark for `.download`, `.crdownload`, and `.part` files. | Progress is indeterminate unless a future browser/manager bridge provides total bytes. |
| 9. Widgets | Already implemented / Implement now | Existing clock/current app/window/preset/folder widgets remain; timer controls and live snapshot cards were added. | Weather/calendar widgets are not implemented in this sprint. |
| 10. Recent activity/results | Already implemented | `NotchIslandActivityCenter` and command results show window, preset, file rule, duplicate scan, wallpaper, Dock, folder, timer, tray, and error activity. | Long-running progress is only as accurate as each MacForge task reports. |
| 11. Customization | Implement now | Live Island settings cover source toggles, privacy mode, artwork, media persistence, downloads folder, diagnostics, and test providers. Existing island size/material/hover/click settings remain. | No private system HUD replacement or OS-level media API toggle. |
| 12. Non-notched display fallback | Already implemented | `NotchGeometryService` uses public auxiliary top areas when available and safe top-center fallback otherwise; Classic Shelf remains available. | Main display remains the primary placement path. |

## Safety Classification

- Implemented with public APIs: collapsed/compact/expanded panel, hover/click/swipe, Music/Spotify Automation, QuickTime Automation, browser active-tab hints, downloads watcher, timer, tray, task/result display, settings, privacy mode.
- Best-effort: QuickTime/video state, browser media without extension, generic media app presence, download progress.
- Requires companion extension: exact browser Media Session metadata, browser artwork, reliable browser playback position/state, browser media controls.
- Blocked without private/unsafe APIs: universal system-wide media metadata across every app, hidden OS-level live activities, menu bar/SystemUIServer replacement, physical camera cutout drawing, cross-app injection-based controls.
