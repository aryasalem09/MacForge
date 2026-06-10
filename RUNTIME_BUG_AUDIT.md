# Runtime Bug Audit

## Branch

- Base branch: `v0.26-notchnook-parity`
- Recovery branch: `v0.26.1-notch-runtime-recovery`
- Attachment branch: `v0.26.2-pixel-perfect-notch-attachment`
- Real visual branch: `v0.26.3-real-notch-visual-fix`

## Apple Music Finding

The Apple Music provider existed, but diagnostics only surfaced `Active`, `Available`, or `Disabled`. That meant a runtime AppleScript parse failure, no-current-track condition, or Automation denial could be flattened into a generic available provider state.

Local AppleScript proof during this sprint returned:

```text
Music got an error: Can’t get name of current track. (-1728)
```

That means Music was running but did not expose a readable current track in this session. The provider now treats that as quietly unavailable, while permission errors become a visible `Music permission needed` state and detailed diagnostics.

## Live Island State Finding

The UI read `LiveIslandCoordinator.currentSnapshot`, but presentation state was still owned by `NotchIslandActivityCenter`. A media snapshot could become active without repeatedly syncing the panel into compact presentation after old MacForge command activity expired. The environment now syncs the island presentation after provider snapshot changes and after activity auto-collapse.

## Notch Placement Finding

The geometry service placed island frames below the broader safe-area band:

```text
screen.maxY - safeAreaInsets.top - 6
```

On notched screens this can sit visibly below the camera notch. v0.26.1 improved the low placement but still used the lower content frame as the whole `NSPanel` frame, so a user screenshot showed an obvious detached gap.

v0.26.2 improved the model by making the panel frame include a top-flush black shell whose top edge is `screen.frame.maxY`, but the user's next screenshot still showed a detached island. v0.26.3 therefore moves from geometry-only repair to real-window repair: the actual `NSPanel` top anchor is modeled explicitly, vertical calibration moves that anchor, force test mode removes widgets/providers from the visual check, and hover expansion uses a delayed state machine instead of immediate enter/exit toggles.

## Dock Finding

Example presets such as Focus Mode and Presentation can enable Dock autohide when Experimental Dock Tweaks are enabled. The previous reset path deleted common Dock keys but did not provide a first-class panic path in Settings. Recovery now forces `autohide` false, deletes only MacForge-managed optional keys, restarts Dock, and exposes safety controls.

## Root Causes

- Provider diagnostics were too lossy to distinguish permission, parsing, unavailable, and active states.
- Live Island presentation promotion was event-driven by snapshot changes only, so stale activity collapse could hide an active media snapshot.
- Notch placement was conservative but too low for the intended visual effect.
- The panel frame did not include a top-attached visual shell, so the black shape could not visually merge with the real notch.
- Automatic notch geometry was still treated as authoritative after it failed on the user's actual display.
- Raw hover enter/exit handling could resize the panel out from under the pointer and oscillate.
- Dock recovery existed as a reset action but not as an obvious user-facing recovery flow.
