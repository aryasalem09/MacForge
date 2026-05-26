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
- A notch-aware floating Notch Shelf using `NSScreen` safe-area geometry and `NSPanel`.
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
- Mac App Store distribution would need Experimental Dock Tweaks disabled or carefully redesigned.

MacForge also does not permanently delete files. Destructive file workflows must move files to Trash only, with confirmation and a `CommandResult`.

## Required Permissions

- Accessibility: required for reading and moving other apps' windows.
- File and folder access: granted per user-selected folder or file through the system open panel and persisted with security-scoped bookmarks.
- Wallpaper images: granted per picked image before a wallpaper preset can apply.
- Launch at Login: optional, managed through public Service Management APIs.
- Experimental Dock Tweaks: optional in-app safety switch required before Dock commands run.

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

GitHub Actions runs build and test on `macos-latest`. The project was locally verified with Xcode 26.2; if GitHub's hosted runner image temporarily lags that toolchain, CI may need a newer macOS runner image or an explicit Xcode selection update.

## Safety Model

- Dock commands are structured `SafeCommand` values, never arbitrary shell strings.
- Dock execution is blocked unless Experimental Dock Tweaks is enabled.
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

## Distribution Notes

Developer ID or local builds are recommended for the full feature set. A Mac App Store variant should disable Experimental Dock Tweaks or redesign them around App Review-safe behavior. Review sandbox entitlements carefully before distribution; do not add broad file access entitlements as a substitute for user-selected security-scoped bookmarks.

## Roadmap

- AppEntity-backed Shortcuts for selecting real presets and pinned folders.
- More complete rollback for safe, reversible preset actions.
- Multi-display Notch Shelf placement controls.
- Richer file-rule editor with destination validation and better action descriptions.
- Optional signed release configuration.
- Localization and accessibility polish.

## Manual Testing Checklist

- Launch the app and verify the main window, menu bar extra, and settings open.
- Toggle the Notch Shelf and confirm buttons are clickable by default.
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
