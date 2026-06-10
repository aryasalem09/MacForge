# MacForge Development Report

## v0.26.2 Pixel-Perfect Notch Attachment

Date: June 9, 2026

### Summary

This sprint treats the user's screenshot as a failed visual acceptance test. The black Notch Island shell was floating below the physical camera notch, so the work focused on panel geometry, visual attachment, stale layout repair, and manual diagnostics rather than adding new providers or widgets.

### Root Cause

`NotchShelfWindowController` used the collapsed/compact content frame as the full `NSPanel` frame. Those frames were calculated below the inferred camera gap, so the panel's top edge landed near the bottom of the notch/menu-bar band instead of `screen.frame.maxY`. The black capsule could be correctly sized and centered, but it could never visually fuse with the physical notch because no MacForge pixels touched the display top.

### What Changed

- Added `NotchAttachmentGeometry` with a top-flush `attachedShellFrame` plus separate collapsed, compact, and expanded content frames.
- Reworked Notch Island panel framing so built-in notched displays use the union of the attached shell and active content frame.
- Kept external and non-notched displays on an honest top-center fallback.
- Updated collapsed, compact, and expanded views to draw a dark attached shell with square top edge and rounded lower edge.
- Added overlay-menu-bar setting, horizontal offset, vertical attach offset, shell-height calibration, snap, repair, reset, and geometry-copy controls.
- Added automatic stale toolbar-layout repair for old v0.26/v0.26.1 values.
- Kept Dock recovery controls visible in Settings -> Safety.
- Added `NOTCH_ATTACHMENT_AUDIT.md` and `MANUAL_QA_PIXEL_NOTCH.md`.

### Verification Notes

Build and test results are recorded in the final response for this branch. Apple Music remains implemented through public Automation and still needs on-device manual consent verification before docs should claim it is manually verified.

## v0.26.1 Notch Runtime Recovery

Date: June 9, 2026

### Summary

This recovery sprint fixes the runtime paths that made v0.26 overstate the Live Island experience in manual testing. The fix focuses on Apple Music provider visibility, compact media presentation, notch placement, and Dock recovery.

### Reproduced / Observed

- Local AppleScript proof found Music running without a readable current track, returning `Can’t get name of current track. (-1728)`.
- The Apple Music provider had no rich diagnostics, so permission, parsing, unavailable, and active states were flattened.
- Live Island snapshots were selected by the coordinator, but panel presentation state could collapse after old MacForge activity expired and not re-promote active media.
- Notch geometry anchored below the whole safe-area band, which could make the island sit too low below the physical notch.
- Example presets can enable Dock autohide when Experimental Dock Tweaks are enabled, but Settings did not have an obvious Dock recovery path.

### Root Cause

The main bug was runtime wiring, not a missing feature. Provider polling and UI rendering existed, but the app did not keep the activity-center presentation state synchronized with the live coordinator after transient activity changed. Diagnostics also hid AppleScript errors and parse failures, making provider failure look like generic idle behavior.

### What Changed

- Added richer provider diagnostics, robust Apple Music no-track handling, and Live Island self-test clearing.
- Added live snapshot presentation sync after provider changes and after activity auto-collapse.
- Added Apple Music provider test, Open Music, and Open Automation Settings actions.
- Anchored Notch Island frames to the inferred camera gap, added placement nudge, and added a debug overlay flag.
- Added managed Dock restore commands and `MacForgeRecoveryService`.
- Added Settings -> Safety recovery buttons for Dock restore, Notch disable, layout reset, live-state clear, and panic reset.
- Added `EMERGENCY_RESET.md`, `RUNTIME_BUG_AUDIT.md`, and `MANUAL_QA_NOTCH_RUNTIME.md`.

### Verification Notes

Apple Music runtime display still requires manual Automation verification on the user machine with active playback. Build and test results for this branch are recorded in the final response after the final `xcodebuild` run.

## v0.26 NotchNook-Style Live Island Parity

Date: June 9, 2026

### Summary

MacForge now targets practical NotchNook-style user-visible parity for the Notch Island while preserving the public-API safety model. The island has provider-based live media, downloads, timers, MacForge task activity, privacy controls, diagnostics, swipe gestures, and a temporary drop tray.

### What Changed

- Added `Core/LiveIsland` with `LiveIslandProvider`, `LiveIslandCoordinator`, `LiveIslandSnapshot`, `LiveIslandSettings`, and `LiveIslandPriority`.
- Added Apple Music and Spotify providers using public Automation/AppleScript for metadata and play/pause/next/previous.
- Added QuickTime best-effort video detection and play/pause through public Automation.
- Added opt-in browser media hints for Safari, Chrome, Brave, and Edge using active tab title/URL only.
- Added generic media app presence detection for known media apps when metadata is not available.
- Added `DownloadsProvider` for user-selected folder bookmarks watching `.download`, `.crdownload`, and `.part`.
- Added local 5/10/25-minute timers with countdown snapshots.
- Added MacForge task snapshots for duplicate scan, file rule, bulk rename, preset, wallpaper, Dock, window, folder, tray, and error activity.
- Added `MacForgeBrowserBridge` scaffold with extension notes, schema, and a minimal user-triggered background script for future Media Session metadata.
- Updated Notch Island UI with provider-aware compact/expanded cards, playback controls, timer controls, diagnostics, test providers, swipe gestures, privacy mode, and a temporary drop tray.
- Added `NOTCH_APP_PARITY.md` comparing MacForge against NotchNook/MediaMate/Alcove-style behavior and marking what is implemented, best-effort, extension-dependent, or blocked safely.

### Safety Notes

- No private frameworks such as MediaRemote.
- No root, SIP bypass, code injection, screen recording, or hidden persistence.
- Browser hints are opt-in and use only active tab title/URL after Automation consent.
- Downloads watching is limited to a user-selected security-scoped bookmark.
- The browser bridge is scaffolded only; it is not registered as a hidden native messaging host.

### Tests Added

- `LiveIslandTests`
  - media beats idle
  - active task beats media
  - error beats media temporarily
  - media returns after task expiration
  - privacy mode redacts media metadata
  - disabled provider ignored
  - download temp files detected
  - Apple Music parser with mock script output
  - Spotify parser with mock script output
  - browser bridge message parser
  - settings encode/decode
  - Classic Shelf still available

### Known Limitations

- Universal exact media metadata for every app is not available through public macOS APIs.
- Browser media is best-effort unless a user-installed companion extension provides Media Session API messages.
- QuickTime/video metadata depends on what the app exposes through public Automation.
- Download progress is indeterminate unless a future source supplies expected byte counts.
- Weather/calendar widgets are not included in this sprint.

### Manual Testing Checklist

- Enable Notch Island and confirm the idle state is a tiny black pill.
- Hover, click, swipe down, and swipe up over the island to confirm expansion/collapse.
- Play Apple Music and Spotify, grant Automation if prompted, and confirm title/artist/progress plus play/pause/next/previous.
- Open a QuickTime movie and confirm best-effort video title/playback state.
- Enable browser hints, grant Automation for a browser, and confirm YouTube/Netflix-like tabs show as possible browser media.
- Select a Downloads folder and confirm `.download`, `.crdownload`, or `.part` files appear as download activity.
- Start 5, 10, and 25 minute timers from the expanded island.
- Drag files into the expanded island tray, reveal one, and clear the tray.
- Run window, Dock, wallpaper, preset, file-rule, bulk-rename, duplicate-scan, folder, and error paths and confirm they temporarily override media.
- Toggle Privacy Mode and confirm titles/artists/artwork are hidden.
- Toggle Classic Shelf and confirm the older shelf mode still works.

### Verification

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' clean build
```

Result: `** CLEAN SUCCEEDED **` and `** BUILD SUCCEEDED **`

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' test
```

Result: `** TEST SUCCEEDED **`

The final test run executed 62 unit tests. Live Island tests use fake providers and mock parser output and do not require real Apple Music, Spotify, browsers, downloads permissions, Accessibility permission, Dock mutation, wallpaper mutation, or Shortcuts execution.

## v0.25 Notch Island Sprint

Date: June 9, 2026

### Summary

MacForge now has a focused Notch Island implementation that keeps the original safety model intact while making the notch feature feel less like a wide toolbar and more like a camera-anchored Mac activity surface. The feature uses public `NSScreen` safe-area and auxiliary top-area geometry, keeps controls below the physical camera cutout, and falls back to a top-center island on non-notched displays.

### What Changed

- Added `NotchGeometryService` with Codable screen metrics, camera-gap inference, safe fallback geometry, and frame targets for collapsed, compact, and expanded island states.
- Added `NotchIslandPresentationState`, `NotchIslandActivity`, and `NotchIslandActivityCenter` for runtime state transitions and command-result activity mapping.
- Updated `NotchShelfConfig` with island/classic mode, collapsed/compact/expanded sizing, behavior controls, auto-collapse delay, material style, and backwards-compatible decoding.
- Reworked `NotchShelfWindowController` to animate between island frames while preserving Classic Shelf mode.
- Added collapsed, compact, expanded, activity, and controls views for the new Notch Island UI.
- Wired command results, window actions, presets, and duplicate scans into compact activity feedback.
- Linked `AppIntents.framework` so App Intents metadata is emitted during build.
- Updated Notch settings with mode, behavior, size, widgets, reset, and public-API limitation controls.

### Geometry Approach

- Prefer `NSScreen.auxiliaryTopLeftArea` and `auxiliaryTopRightArea` when both are available.
- Infer the camera gap as the space between those auxiliary top areas.
- Use `safeAreaInsets.top` as a secondary notch signal when auxiliary areas are unavailable.
- Use a centered top fallback on non-notched and external displays.
- Clamp all frames to screen bounds and place interactive frames below the safe camera/menu-bar area.
- Keep tests synthetic so they do not require real notched hardware.

### Tests Added

- `NotchGeometryServiceTests`
  - camera gap inferred from auxiliary top areas
  - centered fallback from safe-area-only metrics
  - non-notched display fallback
  - small display clamping
  - expanded frame below safe top area
- `NotchIslandStateTests`
  - activity moves island to compact state
  - activity auto-expiration collapses compact island
  - command-result failure maps to error activity
  - manual expand/collapse/hide transitions
  - default island config stays small and island-first

### Known Limitations

- Main display only is the MVP for placement.
- External displays use a top-center fallback if no notch geometry is available.
- macOS does not expose a public exact physical camera cutout rectangle.
- MacForge cannot draw into hidden camera pixels and cannot become a true OS-level iPhone island.
- The expanded panel is intentionally original MacForge UI and does not copy Apple assets or proprietary visual design.

### Manual Testing Checklist

- Launch MacForge and enable Notch Shelf.
- Confirm default mode is Notch Island and the idle state is a small black pill.
- Hover or click the pill and confirm it expands downward smoothly.
- Run window actions and confirm compact activity appears and auto-collapses.
- Run a preset and confirm current activity and recent results update.
- Run duplicate scan and confirm the island reports the scan result.
- Turn off Accessibility permission and confirm window buttons are disabled with a permission hint.
- Toggle Classic Shelf mode and confirm the older wide HUD still appears.
- Enable click-through mode and confirm the warning matches button behavior.
- Test with an external display and confirm top-center fallback behavior.

### Verification

Regular build passed during implementation, then the requested clean build and final test pass both succeeded.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' build
```

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' clean build
```

Result: `** CLEAN SUCCEEDED **` and `** BUILD SUCCEEDED **`

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' test
```

Result: `** TEST SUCCEEDED **`

The final test run executed 50 unit tests, including the new geometry and state-machine tests. Tests still avoid real Accessibility permission, real Dock changes, real wallpaper changes, protected folders, Shortcuts execution, and real notched hardware.

## v0.2 Hardening Report

## Summary

MacForge already had a good safety direction: public API usage, whitelisted Dock commands, dry-run-oriented file tools, and system-permission checks. The main hardening gaps were around security-scoped bookmark lifetime, final confirmations for file changes, rollback being metadata-only, App Intents not being observed by the running app, whole-file duplicate hashing, and some Accessibility force casts.

## What Changed

- Made `AGENTS.md` trackable and expanded future-agent safety guidance.
- Rebuilt `README.md` around capabilities, limitations, permissions, safety model, CI, distribution notes, roadmap, and manual testing.
- Added GitHub Actions CI at `.github/workflows/macos-build-test.yml`, pinned to `macos-26` for the Xcode 26 toolchain.
- Added closure-scoped security bookmark helpers and updated folder/file call sites to avoid leaking started security-scoped access.
- Added core file-rule dry-run and collision enforcement in `FileOrganizerService`.
- Added per-rule Preview, Apply, Remove, and Enabled controls plus an apply confirmation sheet.
- Added bulk rename confirmation, no-op blocking, collision blocking, and engine-level guarded apply.
- Added rollback snapshots for Notch Shelf state, Dock settings, and wallpaper paths, plus a Rollback Last Preset button.
- Wired App Intents through a small command bus that the running app drains and performs.
- Hardened Accessibility AX value handling with CFTypeID checks before bridging.
- Changed Duplicate Finder hashing to chunked reads after size grouping.
- Clarified Notch Shelf click-through mode and warned that buttons may not be clickable.
- Expanded the quick preset builder to support shelf, window, pinned folder, wallpaper, Dock settings, and dry-run file-rule actions.

## Files Changed

- Docs/config: `.gitignore`, `AGENTS.md`, `README.md`, `DEVELOPMENT_REPORT.md`, `.github/workflows/macos-build-test.yml`
- App wiring: `MacForge/App/AppEnvironment.swift`
- Dock/wallpaper/presets: `WallpaperManaging.swift`, `WallpaperService.swift`, `PresetRunner.swift`, `PresetTransaction.swift`, `RollbackManager.swift`
- Files/bookmarks: `SecurityScopedBookmarkStore.swift`, `FolderAccessStore.swift`, `FileOrganizerService.swift`, `BulkRenameEngine.swift`, `DuplicateFinder.swift`, `FileRule.swift`
- Shortcuts: `ApplyPresetIntent.swift`, `OpenPinnedFolderIntent.swift`, `TileFocusedWindowIntent.swift`, `ToggleNotchShelfIntent.swift`
- Windowing/notch UI: `AccessibilityWindowService.swift`, `NotchShelfSettingsView.swift`
- File/preset UI: `FileRuleEditorView.swift`, `BulkRenameView.swift`, `DuplicateFinderView.swift`, `PresetEditorView.swift`, `PresetsView.swift`
- Tests: `BulkRenameEngineTests.swift`, `FileRuleEngineTests.swift`, `PresetTransactionTests.swift`, `SecurityScopedBookmarkStoreTests.swift`

## Tests Added Or Updated

- File rule dry-run-only apply blocking.
- File rule move collision blocking without overwrite.
- Bulk rename no-op detection.
- Bulk rename collision apply blocking.
- Duplicate Finder identical-file grouping.
- Duplicate Finder different-size and same-size-different-content non-grouping.
- Folder shortcut helper path behavior without a bookmark.
- Rollback snapshot availability.
- Metadata-only rollback unavailability.
- File-rule rollback limitation reporting.

## Build Result

Passed on May 26, 2026:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' clean build
```

Result: `** BUILD SUCCEEDED **`

## Test Result

Passed on May 26, 2026:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' test
```

Result: `** TEST SUCCEEDED **`

The final run executed 24 unit tests. Tests do not require Accessibility permission, real Dock changes, real wallpaper changes, Shortcuts execution, protected folders, or external drives.

## Remote CI Status

The first remote CI run used `macos-latest`, which resolved to macOS 15 and Xcode 16.4 and failed during build with exit code 65. The workflow was updated to `macos-26`, and the replacement GitHub Actions run `26461705942` passed build and test on PR #1.

## Verification Corrections

- During the release audit, `FolderAccessStore.resolve` still exposed a `startAccessing` option while returning a bare `URL`. That API was corrected so started security-scoped access stays inside `withResolvedURL` helper scopes and is stopped with `defer`.

## Manual Testing Checklist

- Launch MacForge and confirm the main window, settings, and menu bar extra open.
- Toggle the Notch Shelf and verify shelf buttons are clickable by default.
- Enable Click-through mode and confirm the warning matches the behavior.
- Grant Accessibility permission, refresh windows, and tile a focused window.
- Remove Accessibility permission or run without it and confirm window actions fail clearly.
- Pin a folder, open it, reveal it, and create a folder template.
- Create a dry-run file rule, preview it, and confirm Apply does not mutate files.
- Create a safe non-dry-run file rule, review the confirmation sheet, and apply it to disposable files.
- Test a file-rule destination collision and confirm no overwrite occurs.
- Preview a bulk rename, confirm no-op and collision states disable Apply, then apply a safe rename after confirmation.
- Scan a folder with known duplicates and confirm Duplicate Finder only reveals files.
- Build a preset with multiple action types, run it, then use Rollback Last Preset.
- With MacForge running, trigger Toggle Notch Shelf and Tile Focused Window from Shortcuts.

## Known Limitations

- GitHub Actions must use a macOS 26 runner or another runner with an Xcode 26 toolchain.
- Dock rollback only runs when Experimental Dock Tweaks are enabled.
- Wallpaper rollback only restores paths that still exist and are accessible to the app.
- File-rule rollback is intentionally unavailable in v0.2 because automatically reversing moves, copies, tags, or Trash operations can be unsafe.
- App Intents are request-based and require the MacForge app to be running to perform actions.
- Shortcuts entity selection is still basic string/raw-value scaffolding rather than AppEntity-backed selection.
- Finder tag writes remain OS/SDK-dependent and may be refused by protected or cloud-backed locations.

## Recommended v0.3 Codex Prompt

```text
Implement v0.3 for MacForge.

Goal:
Make MacForge feel production-usable by improving Shortcuts, file-operation history, UI polish, and reliability.

Priorities:
1. Implement AppEntity-backed Shortcuts for presets, pinned folders, and window layouts.
2. Add File Operation History:
   - record past renames/moves/copies/trash actions
   - show timestamp, source, destination, action type, result
   - reveal/open affected files
   - do not add risky auto-undo unless fully safe
3. Add first-run onboarding:
   - explain what MacForge can/cannot do
   - guide Accessibility permission
   - guide pinned folder setup
   - explain Experimental Dock Tweaks
4. Improve command result center:
   - filter success/failure
   - show details
   - clear history
   - export logs
5. Add UI tests where feasible for confirmation sheets.
6. Add preset import/export templates.
7. Improve multi-display notch shelf positioning.
8. Add signed-release preparation notes without enabling unsafe distribution steps.

Preserve v0.2 safety model:
- no private APIs
- no root/sudo
- no arbitrary shell execution
- no code injection
- no SIP bypasses
- no permanent deletion
- file actions preview/confirm first
- Dock commands only through DockCommandBuilder

Run build and tests before finishing.
Update DEVELOPMENT_REPORT.md with what changed and what should be tested manually.
```
