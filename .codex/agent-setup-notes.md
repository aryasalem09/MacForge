# Codex Agent Setup - MacForge

## Classification

Native macOS SwiftUI/AppKit app

## Chosen Settings

- `max_threads = 10`
- `max_depth = 1`
- `job_max_runtime_seconds = 2400`

The thread count matches the independent workstreams this repo can usually support without random over-spawning. `max_depth` is intentionally `1`: direct first-level fanout is enough for the current repo shape, and recursive delegation would increase token and local resource use without a proven coordination benefit.

No repo in this bootstrap uses `max_depth = 2`.

## Custom Agents Created

- `.codex/agents/macos_swiftui_architect.toml`: macOS SwiftUI/AppKit architecture mapper for MacForge.
- `.codex/agents/notch_live_island_validator.toml`: Notch Island and Live Island public-API validator.
- `.codex/agents/system_safety_reviewer.toml`: System safety reviewer for Dock, Accessibility, files, permissions, and App Intents.
- `.codex/agents/macos_build_verifier.toml`: macOS build/test verification agent for Xcode commands and evidence.

## Recommended Prompt Pattern

Start with: "Use a read-only repo scout first, then split work into independent implementation, testing, security/review, docs, and release/git workstreams. Keep agents from editing the same file concurrently. Report exact commands and evidence."

For this repo, add project agents by name when the task touches their ownership area.

## Use CSV Fanout For

- Core module safety reviews
- UI screen audits
- App Intent action reviews
- Notch/Live Island provider checks

## Do Not Use Many Agents For

- One Swift view tweak
- Signing/notarization or system mutation tasks without explicit approval

## Known Risks

- System-facing features need explicit permission handling and honest limitations.
- Notch/Live Island work must remain public-API and hardware-independent in tests.
- Distribution requires careful entitlements/signing review.

## Commands Discovered

Setup:
- Open MacForge.xcodeproj in Xcode 26+.
- Use public Apple APIs and explicit user consent for system-facing features.

Build:
- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' build
- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' clean build

Test:
- DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacForge.xcodeproj -scheme MacForge -destination 'platform=macOS' test
- Scripts/capture_notch_visual_evidence.sh for visual evidence when specifically needed.

Lint/typecheck:
- No standalone lint command discovered.

Run/dev:
- Open in Xcode and run the MacForge scheme on My Mac.

Deploy:
- Developer ID/local builds only unless a distribution task is explicitly requested; App Store variants need entitlement and feature review.

## Validation Performed

Bootstrap validation for these Codex setup files is performed from `/Users/aryasalem/Downloads` after file generation: TOML parsing, AGENTS readback, changed-file secret scan, changed-file large-file check, and path-scoped `git diff --check` where the repo Git state allows it. See `/Users/aryasalem/Downloads/codex-multi-agent-bootstrap-report.md` for the consolidated validation result.
