# Notch Attachment Audit

## Branch

- Base branch: `v0.26.1-notch-runtime-recovery`
- Fix branch: `v0.26.2-pixel-perfect-notch-attachment`

## User Screenshot Bug

The physical camera notch was at the top center of the built-in display, but MacForge's black Notch Island pill was rendered as a separate floating panel over browser chrome. The visible vertical gap meant the panel was being placed below the notch/menu-bar band instead of letting the black visual shell touch the display top edge.

## Geometry To Capture

Use Settings -> Notch Shelf -> Placement -> Copy Notch Geometry Debug Info. It copies:

- `NSScreen.main.frame`
- `NSScreen.main.visibleFrame`
- `NSScreen.main.safeAreaInsets`
- `NSScreen.main.auxiliaryTopLeftArea`
- `NSScreen.main.auxiliaryTopRightArea`
- `backingScaleFactor`
- `cameraGapFrame`
- `attachedShellFrame`
- `collapsedContentFrame`
- `compactContentFrame`
- `expandedContentFrame`
- collapsed, compact, and expanded panel frames
- current `NSPanel` frame
- current `NSWindow.Level`
- placement offsets and shell height
- Classic Shelf / Notch Island mode flags

## Root Cause

The old geometry calculated collapsed and compact frames below the inferred camera gap:

```text
topY = cameraGapFrame.minY
panelFrame = collapsedFrame or compactFrame
```

`NotchShelfWindowController` then used those content frames as the actual `NSPanel` frame. On a notched display, the panel's top edge could land at the camera-gap bottom rather than `screen.frame.maxY`, so the app had no black pixels connecting to the physical notch. The result looked like a detached toolbar even when the frame was horizontally centered.

The previous recovery branch improved the width and added a nudge, but it did not distinguish the visual black shell from the interactive content area. A nudge could move the lower capsule, but it could not make the panel top flush with the display top.

## Fix Strategy

v0.26.2 separates notch geometry into:

- `attachedShellFrame`: the black visual shape that touches `screen.frame.maxY`.
- `collapsedContentFrame`: the lower visible collapsed content area.
- `compactContentFrame`: the lower visible media/activity content area.
- `expandedContentFrame`: the expanded panel area that grows downward.

For built-in notched displays with overlay enabled, the `NSPanel` frame is now the union of the top-flush shell and the active content frame. This keeps the black shape visually connected to the notch while leaving interactive text and controls below the camera cutout.

For external or non-notched displays, MacForge keeps a conservative top-center fallback and does not pretend there is a physical notch.

## Window Level

The panel continues to use public `NSWindow.Level.statusBar`. This is sufficient for the intended menu-bar/notch overlay without escalating to more intrusive levels. If a future display setup renders below the menu bar, the debug copy output records the level and panel frame for diagnosis.

## Config Repair

Old toolbar-like values are repaired when Notch Island mode is active and any of these are found:

- config version before v0.26.2
- collapsed width above 280
- compact width above 420
- collapsed height above 60
- compact height above 70
- offsets outside the calibration limits
- shell height outside 20...80

Settings also includes Repair Notch Island Layout for manual recovery.
