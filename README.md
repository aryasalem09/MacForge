# MacForge

MacForge is a native macOS customization and organization command center for macOS 14 or newer. It is built with SwiftUI plus AppKit bridges for system features that SwiftUI does not expose directly.

The project is intentionally conservative: MacForge uses public Apple APIs, user-selected files and folders, previews before risky file operations, and clear failures when macOS requires permission or does not expose a safe control surface.

## Tested Configuration

This project was created and locally verified on:

- macOS 26.5 (25F71)
- MacBook Pro `Mac17,2`
- Apple M5, 24 GB memory
- Xcode 26.2

## What It Can Customize

- Menu bar quick actions for common MacForge workflows.
- A Notch Island mode with camera-anchored collapsed, compact activity, and expanded panel states using public `NSScreen` geometry and `NSPanel`.
- Provider-based Live Island sources for Apple Music, Spotify, QuickTime, browser media hints, downloads, timers, MacForge tasks, and recent command results.
- NotchNook-style practical interactions: idle pill, hover/click/swipe expansion, media controls where supported, temporary drag-and-drop tray, and expanded widgets.
- A Classic Shelf mode for the older wide top-center HUD.
- Accessibility-based window layouts for the focused window.
- Experimental local Dock settings through whitelisted `/usr/bin/defaults` and `/usr/bin/killall Dock` commands.
- Local wallpaper presets through `NSWorkspace`.
- Pinned folders using security-scoped bookmarks.
- Folder templates, file rule previews/applies, duplicate scanning, and bulk rename previews.
- Presets that combine shelf, Dock, wallpaper, window, folder, and file-rule actions.
- Shortcuts/App Intents for selected app requests where the running app can safely perform the work.

## What It Cannot Customize

- It cannot bypass macOS permissions.
- It cannot modify protected system behavior Apple does not expose through public APIs.
- It cannot inject into Dock, Finder, SystemUIServer, or other apps.
- It does not use private APIs, root escalation, kernel extensions, or SIP bypasses.
- It cannot read a private physical camera cutout rectangle or become a true OS-level iPhone island.
- It cannot draw into pixels hidden by the MacBook camera cutout; interactive controls are positioned below the safe camera/menu-bar area.
- It cannot guarantee exact universal now-playing metadata for every app without private APIs or unsafe injection.
- Browser media is best-effort unless the user installs a future companion extension bridge.
- Mac App Store distribution would need Experimental Dock Tweaks disabled or carefully redesigned.

MacForge also does not permanently delete files. Destructive file workflows must move files to Trash only, with confirmation and a `CommandResult`.

## Required Permissions

- Accessibility: required for reading and moving other apps' windows.
- File and folder access: granted per user-selected folder or file through the system open panel and persisted with security-scoped bookmarks.
- Wallpaper images: granted per picked image before a wallpaper preset can apply.
- Launch at Login: optional, managed through public Service Management APIs.
- Experimental Dock Tweaks: optional in-app safety switch required before Dock commands run.
- Automation: optional, requested by macOS only when Live Island sources control or read Apple Music, Spotify, QuickTime, or enabled browser hints.
- Downloads watcher: optional, limited to the user-selected folder saved as a security-scoped bookmark.

## Troubleshooting

### Dock Disappeared Or Stayed Hidden

Open Settings -> Safety and run Restore Dock Managed Settings or Panic Reset Everything MacForge Changed. If the app cannot be opened, run the backed-up emergency commands in `EMERGENCY_RESET.md`.

MacForge only restores keys it manages: `autohide`, `autohide-delay`, `autohide-time-modifier`, `tilesize`, `magnification`, `largesize`, `orientation`, and `show-recents`. It does not delete the entire Dock preferences domain.

### Apple Music Is Playing But Not Showing

1. Confirm Notch Shelf is enabled and Mode is Notch Island.
2. Confirm Live Island Sources and Apple Music are enabled.
3. In Notch settings, enable Provider diagnostics and click Test Music Provider.
4. If permission is needed, allow MacForge under System Settings -> Privacy & Security -> Automation -> MacForge -> Music.
5. If Music is running but has no readable current track, MacForge reports the provider unavailable instead of showing fake metadata.

To reset the prompt:

```sh
tccutil reset AppleEvents com.aryasalem.MacForge
```

Then quit and relaunch MacForge from Xcode while Music is playing.

### Notch Island Placement

The island measures the physical camera cutout directly from `NSScreen.auxiliaryTopLeftArea`/`auxiliaryTopRightArea` and attaches to it automatically — no manual calibration is needed or offered. The collapsed island is a pure-black shape sized exactly to the notch, so it is invisible until you hover, click, or an activity appears.

Use Copy Notch Geometry Debug Info (Settings -> Notch Shelf -> Island Size) when reporting placement bugs. It copies the screen frame, safe-area insets, auxiliary top areas, measured notch frame, per-state shape sizes and panel frames, current panel frame, and window level. The Show placement debug overlay toggle renders the live state and measured notch size on the island itself.

If a stale configuration from an older build misbehaves, use Settings -> Safety -> Repair Notch Island Layout (or Reset Island Layout in Notch settings); both re-derive everything from the current notch geometry.

For isolated visual testing, launch with `--macforge-force-notch-test` (optionally plus `--macforge-force-notch-expanded`). These flags self-heal on the next normal launch.

### Force A Notch Media Card

Use Settings -> Notch Shelf -> Test Providers -> Force Now Playing Test Card to verify the coordinator-to-UI path and visual attachment without depending on Apple Music Automation permission.

### Old Build Still Running

Quit MacForge completely before launching from Xcode. A stale app bundle can keep older Classic Shelf or provider behavior alive even after the branch builds.

Settings -> About and Settings -> Notch Shelf -> Diagnostics show the build label, branch, bundle path, config path, panel frame, and window level. For this branch, confirm the build label is `v0.27-dynamic-notch-island`.

To collect visual evidence after a clean build:

```sh
Scripts/capture_notch_visual_evidence.sh
```

Review `VisualEvidence/after_idle.png`, `VisualEvidence/after_expanded.png`, and `VisualEvidence/diagnostics.txt`.

## Build Instructions

Open `MacForge.xcodeproj` in Xcode, select the `MacForge` scheme, choose `My Mac`, and press Run.

Command-line build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' build
```

Clean build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' clean build
```

The `DEVELOPER_DIR` prefix is useful on this Mac because full Xcode is installed at `/Applications/Xcode.app`.

## Test Instructions

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' test
```

Current test coverage includes window layout frame calculations, Dock command whitelist behavior, file rule matching and guarded apply behavior, bulk rename preview and collision detection, duplicate grouping, preset rollback metadata, and security-scoped bookmark record encoding/decoding.

Tests should avoid real system mutation. They must not require Accessibility permission, real Dock modification, real wallpaper changes, Shortcuts execution, protected folders, or external drives.

## Continuous Integration

GitHub Actions runs build and test on `macos-26` so CI has an Xcode 26 toolchain. The project was locally verified with Xcode 26.2.

## Safety Model

- Dock commands are structured `SafeCommand` values, never arbitrary shell strings.
- Dock execution is blocked unless Experimental Dock Tweaks is enabled.
- Notch Island geometry uses public `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea` where available, with safe top-center fallbacks.
- Live Island media providers use public Automation/AppleScript only. They do not use private MediaRemote APIs, code injection, SIP bypasses, screen recording, or root behavior.
- Browser hints read active tab title/URL only after the user enables the source and macOS grants Automation consent. The `MacForgeBrowserBridge` scaffold documents a future opt-in Media Session API extension path.
- File rules default to dry-run preview and require confirmation before applying changes.
- Bulk Rename shows old-to-new previews, blocks collisions, and requires confirmation before applying.
- Duplicate Finder groups by size first, hashes candidate duplicates, and never deletes files.
- Accessibility actions check permission first and convert AX failures into `CommandResult` details.
- Security-scoped bookmark access is scoped to helper closures so started access is stopped with `defer`.
- All important operations surface success or failure through `CommandResult`.

## Known Limitations

- Experimental Dock Tweaks are local, user-enabled, and not designed for Mac App Store distribution in their current form.
- Accessibility-based window management depends on each target app accepting AX move and resize requests.
- Wallpaper rollback can only restore previous image paths that remain accessible to the app.
- File-rule rollback is intentionally unavailable in v0.2 because automatic reversal of moves, copies, tags, or Trash operations can be unsafe.
- Shortcuts support is limited to app-observed request wiring for selected actions; richer AppEntity selection is future work.
- Finder tag writing depends on SDK and OS availability and can be refused by protected or cloud-backed locations.
- Notch Island placement is main-display MVP. External displays fall back to a top-center island when notch geometry is unavailable.
- The app now aims for NotchNook-style user-visible parity where public APIs make it feasible, but universal exact media detection remains best-effort.
- Browser media controls, artwork, and exact playback position require a user-installed companion extension bridge that is scaffolded but not registered in this sprint.
- The app creates an original MacForge Notch Island experience inspired by compact activity surfaces; it does not copy Apple assets or claim to be an OS-level Dynamic Island.

## Distribution Notes

Developer ID or local builds are recommended for the full feature set. A Mac App Store variant should disable Experimental Dock Tweaks or redesign them around App Review-safe behavior. Review sandbox entitlements carefully before distribution; do not add broad file access entitlements as a substitute for user-selected security-scoped bookmarks.

## Roadmap

- AppEntity-backed Shortcuts for selecting real presets and pinned folders.
- More complete rollback for safe, reversible preset actions.
- Multi-display Notch Island placement controls.
- Richer file-rule editor with destination validation and better action descriptions.
- Optional signed release configuration.
- Browser bridge native messaging host registration and extension packaging.
- Additional widgets such as weather/calendar if implemented with explicit user consent.
- Localization and accessibility polish.

## Manual Testing Checklist

- Launch the app and verify the main window, menu bar extra, and settings open.
- Toggle the Notch Shelf and confirm buttons are clickable by default.
- In Notch Island mode, confirm the idle state is a small black pill rather than a wide toolbar.
- Click or hover the island and confirm it expands downward from the camera area.
- Swipe down/up over the island and confirm it expands/collapses; swipe left/right during Apple Music or Spotify playback to test next/previous.
- Start Apple Music or Spotify, grant Automation if macOS asks, and confirm title, artist, progress, and controls appear.
- Enable Browser media hints, grant Automation for the browser, and confirm media-like tabs show as possible browser media without claiming exact playback state.
- Choose a Downloads folder in Notch settings, create or observe a `.download`, `.crdownload`, or `.part` file, and confirm download activity appears.
- Start 5/10/25-minute timers from the expanded island and confirm countdown/progress display.
- Drag files into the expanded island tray, reveal them, then clear the tray.
- Run a window action, preset, wallpaper apply, file rule, duplicate scan, or folder open and confirm a compact activity appears then auto-collapses.
- On an external display, confirm the island uses a top-center fallback and still supports collapsed/expanded states.
- Enable click-through mode and confirm the warning matches the behavior.
- Grant Accessibility permission, refresh windows, and tile a focused window.
- Leave Accessibility disabled and confirm window actions fail clearly.
- Pin a folder, open it, reveal it, and create a folder template.
- Preview a file rule, confirm a dry-run-only rule does not mutate files, then apply a safe rule to test copies or moves.
- Try a destination collision and confirm MacForge blocks or clearly fails without overwrite.
- Preview a bulk rename, confirm no-op and collision states disable apply, then apply a safe rename after the confirmation sheet.
- Scan a small folder with known duplicate files and verify Duplicate Finder only reveals files.
- Save and run a preset, then run Rollback Last Preset and review `CommandResult` details.
- Toggle Notch Shelf and tile the focused window from Shortcuts while MacForge is running.
