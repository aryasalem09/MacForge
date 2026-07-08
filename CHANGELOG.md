# Changelog

All notable changes to MacForge are documented here. Versions follow
[Semantic Versioning](https://semver.org); the app's About panel and
diagnostics derive their build label from `MARKETING_VERSION`.

## 1.0.0 — 2026-07-07

The free-core release: MacForge is now a notch-first product. The island is
the front page; windows, Dock, wallpapers, files, and presets are grouped as
helpers.

### Added
- **Calendar agenda widget** (EventKit): the next event surfaces in the island
  shortly before it starts. Calendar access is requested only when the widget
  is enabled, never at launch.
- **Volume HUD**: volume and mute changes appear in the island instantly via a
  local CoreAudio listener (no permissions, no key interception), with a level
  bar in the compact ear.
- **Persistent file tray**: dropped files survive relaunches via bookmarks
  (moved files are tracked), with a configurable retention window (1 hour to
  1 week, or keep until removed), AirDrop for one file or the whole tray,
  open/reveal/remove per item, and drag-out.
- **Drag-to-seek scrubber** on the Now Playing card for Apple Music, Spotify,
  and QuickTime.
- **Spotify album artwork** in the expanded island.
- **Downloads details**: byte count and live transfer rate, a count of
  concurrent downloads, and a "Download finished" card when a transfer
  completes.
- **Timers**: custom durations (1–180 min) next to the presets, persistence
  across relaunch, and a completion chime.
- **First-run onboarding**: enable the island, pick widgets, and see the
  permission model before anything is requested.
- **Config schema versioning** with a migration ladder; the previous file is
  backed up before any migration, and unreadable configs are preserved (not
  silently discarded) with a visible notice.
- New Live Island source toggles: calendar agenda, volume HUD, and other media
  apps (TV/VLC/IINA — now off by default).
- Coordinator `push()` path so instant events (HUD) render without waiting for
  the next poll.
- A Calendars row on the Permissions page and truthful Automation copy.

### Changed
- **Notch-first shell**: the sidebar now leads with Overview, Island & Widgets,
  and Permissions; Windows/Dock/Desktop/Files/Presets moved into a Helpers
  section. The dashboard is island-centric and the menu bar extra is slimmer.
- **No permission prompts at launch.** The Accessibility dialog is no longer
  shown on startup; window helpers ask on first use.
- Automation permission cards show once per launch instead of permanently
  occupying the island; the sticky status lives in provider diagnostics.
- Version identity derives from the bundle (`MARKETING_VERSION` 1.0.0);
  hardcoded branch/date strings are gone.
- `Show app in Dock` off is respected at launch again.
- Reset Preferences now also resets Dock visibility and clears the tray.

### Performance
- AppleScript polling moved off the main thread onto a serial queue — a slow
  media app or a pending consent dialog can no longer freeze island
  animations.
- Adaptive polling: 1 Hz only while something is live, every 3 s when idle,
  fully paused while displays sleep; an in-flight guard prevents overlapping
  refreshes.
- The coordinator publishes only when visible content actually changes
  (snapshots previously re-published identical content at 1 Hz).
- Same-priority anti-flap hysteresis now hands back fresh provider data, so
  elapsed time no longer freezes for 2 s.
- Configuration writes are debounced and atomic (calibration drags previously
  wrote the full JSON per mouse move) and flushed on quit.
- App icons in the compact ear are cached instead of rescanning the process
  list every frame.

## 0.1.0 — 2026-06

Initial development line: attached Dynamic Island engine, Live Island
providers (Music/Spotify/QuickTime/browser hints/downloads/timers), agent &
CLI activity pipeline, classic shelf mode, window/Dock/wallpaper/file/preset
helpers, safety and rollback tooling.
