# Manual QA: Pixel-Perfect Notch Attachment

## Setup

1. Run `EMERGENCY_RESET.md` if the Dock is hidden or MacForge layout state seems stale.
2. Quit any old MacForge build.
3. Launch MacForge from Xcode on the built-in MacBook display.
4. Open Settings -> Notch Shelf.
5. Enable Notch Shelf.
6. Set Mode to Notch Island.
7. Click Repair Notch Island Layout.

## Idle Attachment

1. Confirm the idle black shape visually touches the physical camera notch.
2. Confirm there is no obvious vertical gap between the real notch and the MacForge shell.
3. Confirm the idle state is not a wide toolbar and does not show MacForge / Inbox / Focus Mode style generic widgets.
4. Confirm it is centered on the physical notch.
5. Toggle Show placement debug overlay.
6. Click Copy Notch Geometry Debug Info and save the copied output with a screenshot if placement is still wrong.

## Calibration

1. Adjust Vertical attach offset until the black shell visually meets the notch on this display.
2. Adjust Horizontal offset only if the shell is not centered under the camera.
3. Adjust Shell height if the shell extends too far down or does not extend far enough.
4. Click Snap to Detected Notch.
5. Click Reset to Attached Defaults.
6. Confirm the shell returns to a top-attached position.

## Media / Self-Test

1. Click Force Now Playing Test Card.
2. Confirm the compact media card remains attached to the physical notch.
3. Expand and collapse the island.
4. Confirm expanded mode grows downward from the attached shell.
5. Play Apple Music.
6. Click Test Music Provider.
7. Grant Automation if prompted.
8. Confirm Music Provider Status shows Music running and a readable track when playback is active.
9. Confirm music appears as the attached compact card.

## Mode And Recovery

1. Switch to Classic Shelf and confirm the old shelf mode still appears as a separate top-center shelf.
2. Switch back to Notch Island and click Repair Notch Island Layout.
3. Open Settings -> Safety.
4. Click Restore Dock Managed Settings.
5. Click Clear Live State.
6. Click Panic Reset Everything MacForge Changed.
7. Confirm the Dock is visible, Notch Island is disabled, and Experimental Dock Tweaks are off.
