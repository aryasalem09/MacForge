# MacForge

## Tried and Tested on this, I cannot guarantee it will work well on other configs
- macOS 26.5 (25F71)
- MacBook Pro `Mac17,2`
- Apple M5, 24 GB memory
- Xcode 26.2



## What It Can Customize

- Menu bar quick actions
- A notch-aware floating Notch Shelf using `NSScreen` safe-area geometry and `NSPanel`
- Accessibility-based window layouts for the focused window
- Experimental local Dock settings through whitelisted `/usr/bin/defaults` and `/usr/bin/killall Dock` commands
- Local wallpaper presets through `NSWorkspace`
- Pinned folders using security-scoped bookmarks
- Folder templates, file rule previews, duplicate scanning, and bulk rename previews
- Presets that combine shelf, Dock, wallpaper, window, folder, and file-rule actions
- Basic App Intents scaffolding for Shortcuts


## Required Permissions

- Accessibility: required for reading and moving other apps' windows.
- File/folder access: granted per folder through the system open panel.
- Wallpaper images: granted per picked image.
- Launch at Login: optional, managed by `SMAppService`.
- Experimental Dock Tweaks: optional in-app safety switch before any Dock command is run.

## Build In Xcode

1. Open `MacForge.xcodeproj` in Xcode.
2. Select the `MacForge` scheme.
3. Choose `My Mac`.
4. Press Run.

Command-line build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' build
```


## Run Tests

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' test
```

## Test Coverage:

- Window layout frame calculations
- Dock command whitelist behavior
- File rule matching and preview destinations
- Bulk rename preview and collision detection
- Preset transaction ordering and rollback metadata
- Security-scoped bookmark record encoding/decoding

## Safety Model

- Dock commands are structured `SafeCommand` values, never arbitrary shell strings.
- Dock command execution is blocked unless Experimental Dock Tweaks is enabled.
- File rules default to dry-run preview.
- Duplicate Finder never deletes files.
- Bulk Rename shows old-to-new previews and blocks collisions.
- Accessibility actions stop cleanly when permission is missing.
- All important actions return `CommandResult` values shown in the UI.

## Distribution Notes

Developer ID or local builds are recommended for the full feature set. A Mac App Store variant should disable Experimental Dock Tweaks and review sandbox entitlements carefully. 

## Roadmap

- AppEntity-backed App Intents for real preset and folder selection in Shortcuts
- Better preset rollback snapshots for Dock and wallpaper state
- Multi-display shelf placement controls
- Richer file-rule editor with confirmation sheets
- Optional signed release configuration
- Localized strings
