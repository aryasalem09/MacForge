# MacForge v0.2 Hardening Report

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

The first remote CI run used `macos-latest`, which resolved to macOS 15 and Xcode 16.4 and failed during build with exit code 65. The workflow was updated to `macos-26`; the replacement run must be verified after this update is pushed.

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
