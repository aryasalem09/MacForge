# Manual QA: Notch Runtime Recovery

## Restore And Reset

1. Quit MacForge.
2. Run the commands in `EMERGENCY_RESET.md`.
3. Relaunch MacForge from Xcode.
4. Open Settings -> Safety.
5. Run Restore Dock Managed Settings.
6. Run Clear Live State.
7. Confirm the Dock is visible and Notch Island is not stuck.

## Apple Music

1. Start Apple Music playback.
2. Run:

   ```sh
   osascript <<'APPLESCRIPT'
   tell application "Music"
       if it is running then
           set trackName to name of current track
           set artistName to artist of current track
           set albumName to album of current track
           set stateName to player state as string
           set pos to player position
           set dur to duration of current track
           return trackName & "||" & artistName & "||" & albumName & "||" & stateName & "||" & pos & "||" & dur
       else
           return "Music is not running"
       end if
   end tell
   APPLESCRIPT
   ```

3. Enable Notch Shelf.
4. Set Mode to Notch Island.
5. Enable Live Island Sources and Apple Music.
6. Click Test Music Provider.
7. If macOS asks for Automation access, click Allow.
8. If no prompt appears, open System Settings -> Privacy & Security -> Automation -> MacForge -> Music.
9. Confirm the compact island shows title, artist, playback state, progress, and play/pause.
10. Expand the island and confirm Now Playing is the top card with controls.
11. Test play/pause, next, previous, and Open Music.
12. Turn Privacy Mode on and confirm title/artist/artwork are redacted.
13. Pause Music and confirm the paused track remains visible while the provider reports it.
14. Quit Music and confirm the island returns to idle.

## Placement

1. With no activity, confirm idle is a small black pill.
2. With Music playing, confirm compact media width is below the toolbar-like threshold.
3. Toggle Show placement debug overlay.
4. Adjust Placement nudge.
5. Confirm the island stays below the hidden camera area and can be nudged lower when needed.
6. Click Reset Notch Layout and confirm defaults return.

## Classic Shelf

1. Switch Mode to Classic Shelf.
2. Confirm the old wide shelf still appears and widgets work.
3. Switch back to Notch Island and confirm the compact pill returns.

## Panic Reset

1. Enable Notch Island.
2. Enable Experimental Dock Tweaks.
3. Run a preset that changes Dock settings.
4. Open Settings -> Safety.
5. Click Panic Reset Everything MacForge Changed.
6. Confirm Notch Island is disabled, live state is cleared, Experimental Dock Tweaks is off, and Dock autohide is false.
