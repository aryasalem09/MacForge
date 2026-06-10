# Real Notch Visual Audit

## Branch

- Base branch: `v0.26.2-pixel-perfect-notch-attachment`
- Fix branch: `v0.26.3-real-notch-visual-fix`
- Build label shown in app: `v0.26.3-real-notch-visual-fix`

## Phase 0 Reset

- Reset run before coding: yes
- Backup path: `/Users/aryasalem/Desktop/MacForge-Recovery-20260609-192426`
- Stale MacForge config existed before reset: yes
- App Support folder deleted after backup: yes
- Dock managed keys restored: `autohide` forced false; MacForge-managed optional keys deleted; Dock restarted
- AppleEvents prompt reset: yes, for `com.aryasalem.MacForge`

## User-Reported Failure

The v0.26.2 branch passed synthetic geometry tests but still failed the user's real screen. The black Notch Island shape remained visibly detached below the physical MacBook camera notch, and hover expansion glitched.

## Why Prior Unit Tests Were Insufficient

The tests verified a top-flush shell rectangle in synthetic coordinates, but they did not prove:

- the running app was the freshly built bundle
- stale persisted config was gone
- the actual `NSPanel` top anchor stayed fixed during hover expansion
- the chosen public window level visually overlaid the menu-bar/notch area
- the user could manually move the actual panel when automatic geometry was wrong
- hover exit/enter events were debounced when the panel changed size under the cursor

## Root Cause Of Continued Detachment

The v0.26.2 vertical offset adjusted shell extension, not the actual `NSPanel` top anchor. If public screen geometry or window placement was off on the real machine, the user could not drag the real panel into alignment. The hover code also expanded/collapsed immediately on raw SwiftUI hover events, so a frame change could move the hit area and cause oscillation.

## v0.26.3 Fix Strategy

- Add a top-anchored `NotchPanelLayout` with panel-local shell/content frames.
- Keep the panel top anchor stable across collapsed, compact, and expanded states.
- Make vertical calibration move the actual panel top.
- Make horizontal calibration move the actual panel center.
- Use public `.popUpMenu` level by default when "Allow Notch Island above menu bar" is enabled, with `.statusBar` available by turning it off.
- Add Force Attached Notch Test Mode to isolate visual placement from providers and widgets.
- Add Calibration Mode so the island can be dragged into exact visual alignment.
- Add a debounced hover state machine with delayed expand and delayed collapse.
- Add build/bundle/config diagnostics so the user can confirm the running app is the new build.

## Screenshot Evidence

Use `Scripts/capture_notch_visual_evidence.sh` after building. Expected outputs:

- `VisualEvidence/before.png`
- `VisualEvidence/after_idle.png`
- `VisualEvidence/after_expanded.png`
- `VisualEvidence/diagnostics.txt`

Captured locally on June 9, 2026:

- `/Users/aryasalem/Downloads/MacForge/VisualEvidence/before.png`
- `/Users/aryasalem/Downloads/MacForge/VisualEvidence/after_idle.png`
- `/Users/aryasalem/Downloads/MacForge/VisualEvidence/after_expanded.png`
- `/Users/aryasalem/Downloads/MacForge/VisualEvidence/diagnostics.txt`

Current status: screenshot evidence was generated, but the captures are obstructed by a macOS Screen Recording permission dialog for Codex. The visible shell is top-anchored instead of floating over the browser toolbar, but Codex cannot honestly mark the screenshot as a pass until the permission dialog is cleared and the user reviews a clean real-display capture.

## Manual Verification Fields

- Visual gap remains: not determinable from obstructed screenshots
- Hover still glitches: unknown until clean screenshot/user QA
- Manual calibration needed: unknown
- Final offsets: start at x `0`, y `0`
- Window level default: public `.popUpMenu` for Notch Island above-menu overlay

## Build And Test

- Clean build: `** CLEAN SUCCEEDED **`, `** BUILD SUCCEEDED **`
- Test: `** TEST SUCCEEDED **`
- Test count: 87 passed, 0 failed, 0 skipped
- Test note: XCTest app-host launches now suppress live provider polling so Apple Music/Spotify/QuickTime Automation prompts cannot wedge unit tests.
