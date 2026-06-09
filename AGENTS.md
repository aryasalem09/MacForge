# AGENTS.md

## Project Overview

MacForge is a native macOS customization and organization command center. It is a SwiftUI app with AppKit bridges where macOS requires them, aimed at safe local workflows for menu bar quick actions, a notch-aware floating shelf, window layouts, Dock preferences, wallpapers, pinned folders, file organization, duplicate scanning, presets, and Shortcuts/App Intents.

MacForge must always favor public Apple APIs, explicit user consent, previews before file changes, and honest limitations when macOS does not expose a safe customization surface.

## Architecture Overview

- `App/` wires the SwiftUI app, app delegate, `AppEnvironment`, persisted configuration, and app-wide command results.
- `Models/` contains Codable state, preset actions, file rules, window layouts, Dock settings, and command result types.
- `Core/Permissions/` owns Accessibility, file access, automation notes, and launch-at-login status.
- `Core/Windowing/` owns Accessibility window enumeration and pure layout math.
- `Core/Notch/` owns safe-area screen detection and the floating `NSPanel`.
- `Core/LiveIsland/` owns provider-based live media, browser hints, downloads, timers, task snapshots, privacy redaction, and priority arbitration.
- `Core/Dock/` owns Dock command construction and process execution.
- `Core/Desktop/` owns wallpaper presets through `NSWorkspace`.
- `Core/Files/` owns bookmarks, folder access, file rules, duplicate scanning, bulk rename, and Trash moves.
- `Core/Presets/` owns preset previews, execution transactions, and rollback metadata.
- `Core/Shortcuts/AppIntents/` owns Shortcuts-facing App Intent scaffolding and app command requests.
- `UI/` contains SwiftUI screens grouped by feature.
- `MacForgeTests/` contains unit tests that must avoid real Accessibility, Dock, wallpaper, protected-folder, or Shortcuts side effects.

## Safety Rules

Never use private APIs, root escalation, code injection, SIP bypasses, kernel extensions, hidden login items, hidden persistence, or stealth behavior.

Use public Apple APIs wherever possible. When macOS blocks a behavior or does not expose it through public APIs, add a clear explanation in the UI or docs instead of implementing a risky workaround.

Keep the app buildable after every Codex run. If you touch source or project wiring, run the build/tests requested by the task or document exactly why the local environment prevented it.

## Dock Commands

- Dock changes must go through `DockCommandBuilder` only.
- Do not add shell interpolation or arbitrary command strings.
- Allowed executables must remain fixed, whitelisted paths.
- Arguments must remain structured and validated before execution.
- Experimental Dock Tweaks must be enabled before Dock commands run.
- Mac App Store builds should disable Experimental Dock Tweaks or redesign them around an approved distribution model.

## File Operations

- File operations must support preview/dry-run behavior.
- Do not permanently delete files.
- Risky removals must move to Trash only and surface a `CommandResult`.
- Bulk rename and file rules must block or clearly fail destination collisions; never overwrite user files.
- Security-scoped bookmarks are the only persistence mechanism for user-selected folders and images.
- Do not assume access to Desktop, Documents, Downloads, external drives, or protected folders.
- If security-scoped access is started, stop it with `defer` in the same helper scope.

## Accessibility Usage

- Accessibility actions must check permission first.
- Missing permission must return a clear `CommandResult`, not crash or silently fail.
- Treat third-party apps and unusual AX values as hostile input: avoid force casts around AX values.
- Window list and focused-window actions must fail gracefully when an app refuses AX reads, moves, or resizes.
- Tests must not require real Accessibility permission.

## Notch Island

- Notch Island work must use public AppKit/SwiftUI APIs only.
- Use `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea`, and `auxiliaryTopRightArea` when available.
- Do not use private notch, camera, menu bar, or display-server APIs.
- Do not inject into SystemUIServer or attempt to replace the menu bar.
- Do not draw interactive controls into pixels hidden by the physical camera cutout.
- Keep external and non-notched display fallbacks explicit and safe.
- Keep geometry and state tests hardware-independent by using synthetic screen metrics.
- Do not call the feature "Dynamic Island" in app UI; use "Notch Island" or "Notch Shelf."
- Do not copy Apple assets or exact proprietary visual design.
- Live Island providers must remain honest about source quality. Apple Music, Spotify, and QuickTime may use public Automation/AppleScript with macOS consent. Browser media must stay best-effort unless a user-installed companion extension supplies Media Session API metadata.
- Do not use private media frameworks such as MediaRemote, screen recording, app injection, or hidden event taps for now-playing data.
- Downloads activity must be limited to the user-selected folder bookmark and temporary download file detection.
- Privacy Mode must redact track/video titles, artist names, and artwork.

## App Intents

- App Intents must be honestly wired or honestly labeled as scaffolding.
- If an intent writes a request for the running app, the app must observe and execute supported requests.
- Unsupported Shortcuts actions should return a truthful limitation and should not pretend to mutate state.
- Do not make App Intent tests depend on real Shortcuts execution.

## Build And Test Commands

Build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' build
```

Clean build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' clean build
```

Test:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' test
```

## Adding Features

- Add pure logic to `Core/` and unit test it before wiring UI.
- Add user-facing controls under the matching `UI/` feature folder.
- Add new state to `AppEnvironment` only when it is genuinely shared across screens.
- Use `CommandResult` for operations that can fail.
- Keep macOS-version-specific APIs behind availability checks while maintaining the macOS 14 deployment target.
- Avoid adding new dependencies unless they remove real risk or match an established project pattern.

## Current Machine Context

This repo was created and verified on macOS 26.5 (25F71), MacBook Pro `Mac17,2`, Apple M5, with Xcode 26.2 installed at `/Applications/Xcode.app`.
