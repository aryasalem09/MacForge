# MacForge Browser Bridge

This folder scaffolds a future user-installed browser companion for richer browser media support.

## Goal

The extension reads the browser Media Session API after the user installs it and grants browser extension permissions. It can send local metadata to MacForge:

- title
- artist
- album
- playback state
- duration and position
- artwork URL when exposed by the page
- source URL and tab title

## Native Messaging Direction

The preferred production route is a native messaging host registered by MacForge. The extension would call `browser.runtime.sendNativeMessage`, and MacForge would parse one JSON message at a time through `BrowserBridgeMessageParser`.

This sprint does not register a native messaging host or inject page scripts by default. MacForge's built-in `BrowserMediaProvider` remains a best-effort active-tab title/URL hint unless the companion bridge is installed and wired in a future sprint.

## Safety Boundaries

- No browser, Music, Spotify, Finder, Dock, or SystemUIServer injection.
- No screen recording.
- No private macOS media frameworks.
- No hidden persistence.
- The user installs and enables the browser extension explicitly.
