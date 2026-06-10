#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE_DIR="$ROOT/VisualEvidence"
mkdir -p "$EVIDENCE_DIR"

APP_PATH="$(ls -dt "$HOME"/Library/Developer/Xcode/DerivedData/MacForge-*/Build/Products/Debug/MacForge.app 2>/dev/null | head -n 1 || true)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "No Debug MacForge.app found. Run the clean build first."
  exit 1
fi

CONFIG_PATH="$HOME/Library/Application Support/MacForge/configuration.json"
DIAGNOSTICS="$EVIDENCE_DIR/diagnostics.txt"

killall MacForge 2>/dev/null || true
sleep 1

/usr/sbin/screencapture -x "$EVIDENCE_DIR/before.png"

echo "Launching: $APP_PATH"
/usr/bin/open -n "$APP_PATH" --args --macforge-force-notch-test
sleep 3
/usr/sbin/screencapture -x "$EVIDENCE_DIR/after_idle.png"

killall MacForge 2>/dev/null || true
sleep 1
/usr/bin/open -n "$APP_PATH" --args --macforge-force-notch-test --macforge-force-notch-expanded
sleep 3
/usr/sbin/screencapture -x "$EVIDENCE_DIR/after_expanded.png"

{
  echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "app_path=$APP_PATH"
  echo "bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
  echo "executable=$APP_PATH/Contents/MacOS/MacForge"
  echo "running_pids=$(pgrep -x MacForge | tr '\n' ' ')"
  echo "config_path=$CONFIG_PATH"
  if [[ -f "$CONFIG_PATH" ]]; then
    echo "--- configuration.json ---"
    /bin/cat "$CONFIG_PATH"
  else
    echo "configuration_missing=true"
  fi
  echo "--- screenshots ---"
  echo "$EVIDENCE_DIR/before.png"
  echo "$EVIDENCE_DIR/after_idle.png"
  echo "$EVIDENCE_DIR/after_expanded.png"
} > "$DIAGNOSTICS"

echo "Visual evidence saved:"
echo "  $EVIDENCE_DIR/before.png"
echo "  $EVIDENCE_DIR/after_idle.png"
echo "  $EVIDENCE_DIR/after_expanded.png"
echo "  $DIAGNOSTICS"
