# Manual QA: Pixel-Perfect Notch Attachment

## Setup

1. Run `EMERGENCY_RESET.md` if the Dock is hidden or MacForge layout state seems stale.
2. Quit any old MacForge build.
3. Launch MacForge from Xcode on the built-in MacBook display.
4. Open Settings -> Notch Shelf.
5. Enable Notch Shelf.
6. Set Mode to Notch Island.

## Idle Attachment

1. Confirm the idle black shape is sized exactly to the physical camera notch and blends into it (it should be nearly invisible against the notch).
2. Confirm there is no vertical gap between the real notch and the MacForge shape, and no widening into a toolbar.
3. Confirm it is centered on the physical notch.
4. Toggle Show placement debug overlay and confirm the reported notch size matches the display (about 185x32 on a 14"/16" MacBook Pro).
5. Click Copy Notch Geometry Debug Info and save the copied output with a screenshot if placement is still wrong.

## Responsiveness (iPhone-style)

1. Move the pointer up into the notch and confirm the island springs open (expanded) within a fraction of a second.
2. Move the pointer away and confirm the island springs closed after a short delay.
3. Click the collapsed island and confirm it expands and stays open; click again (or the chevron) and confirm it collapses.
4. After collapsing via the chevron, hover the collapsed island again and confirm hover-to-expand still works (no dead hover).
5. Swipe down over the island to expand and swipe up to collapse.

## Media / Self-Test

1. Click Force Now Playing Test Card.
2. Confirm the compact media card renders as two "ears" beside the physical notch (app icon on the left, animated audio bars on the right), never behind the camera.
3. Expand and collapse the island.
4. Confirm expanded mode grows downward from the notch with the shelf content below the camera band.
5. Play Apple Music.
6. Click Test Music Provider.
7. Grant Automation if prompted.
8. Confirm Music Provider Status shows Music running and a readable track when playback is active.
9. Confirm music appears as the compact card in the ears.

## Mode And Recovery

1. Switch to Classic Shelf and confirm the old shelf mode still appears as a separate top-center shelf.
2. Switch back to Notch Island and confirm it re-attaches to the notch.
3. Open Settings -> Safety.
4. Click Restore Dock Managed Settings.
5. Click Clear Live State.
6. Click Repair Notch Island Layout and confirm the island re-derives placement from the current notch geometry.
7. Click Panic Reset Everything MacForge Changed.
8. Confirm the Dock is visible, Notch Island is disabled, and Experimental Dock Tweaks are off.
