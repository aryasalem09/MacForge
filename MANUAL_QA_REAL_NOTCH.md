# Manual QA: Real Notch Visual Fix

1. Run the safe reset in `EMERGENCY_RESET.md`.
2. Build Debug:
   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' clean build
   ```
3. Launch the Debug app:
   ```sh
   open ~/Library/Developer/Xcode/DerivedData/MacForge-*/Build/Products/Debug/MacForge.app
   ```
4. Open Settings -> Notch Shelf.
5. Confirm Diagnostics shows build `v0.26.3-real-notch-visual-fix` and the Debug bundle path.
6. Enable Notch Shelf and set Mode to Notch Island.
7. Enable Force Attached Notch Test Mode.
8. Confirm the black shell visually touches the physical camera notch.
9. If it does not touch, enable Calibration Mode.
10. Drag the black shell until it touches the physical notch.
11. Click Save Calibration.
12. Quit and relaunch MacForge.
13. Confirm the saved calibration persists.
14. Hover the island and confirm it expands once without flicker.
15. Move the pointer outside and confirm collapse happens only after a short delay.
16. Disable Force Attached Notch Test Mode.
17. Click Force Now Playing Test Card.
18. Confirm the compact media card remains attached.
19. Click Test Music Provider.
20. If Automation is denied, grant Music permission in System Settings -> Privacy & Security -> Automation -> MacForge -> Music.
21. If AppleScript reports no current track, do not mark Music manually verified.
22. Run Panic Reset Everything MacForge Changed and confirm the Dock remains visible and Notch Island is disabled.

Optional screenshot script:

```sh
Scripts/capture_notch_visual_evidence.sh
```

Review `VisualEvidence/after_idle.png`, `VisualEvidence/after_expanded.png`, and `VisualEvidence/diagnostics.txt`.
