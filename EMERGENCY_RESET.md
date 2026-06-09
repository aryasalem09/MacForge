# MacForge Emergency Reset

Use this when MacForge testing leaves the Dock hidden, the Notch Island misplaced, or Live Island state stuck.

This backs up the current Dock preferences and MacForge app support folder first. It does not delete user files, pinned folder contents, wallpaper images, or your whole Dock domain.

```sh
killall MacForge 2>/dev/null || true

BACKUP="$HOME/Desktop/MacForge-Recovery-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"

cp "$HOME/Library/Preferences/com.apple.dock.plist" "$BACKUP/com.apple.dock.plist.backup" 2>/dev/null || true
cp -R "$HOME/Library/Application Support/MacForge" "$BACKUP/MacForge-AppSupport.backup" 2>/dev/null || true

defaults write com.apple.dock autohide -bool false
defaults delete com.apple.dock autohide-delay 2>/dev/null || true
defaults delete com.apple.dock autohide-time-modifier 2>/dev/null || true
defaults delete com.apple.dock tilesize 2>/dev/null || true
defaults delete com.apple.dock magnification 2>/dev/null || true
defaults delete com.apple.dock largesize 2>/dev/null || true
defaults delete com.apple.dock orientation 2>/dev/null || true
defaults delete com.apple.dock show-recents 2>/dev/null || true

killall Dock

rm -rf "$HOME/Library/Application Support/MacForge"

tccutil reset AppleEvents com.aryasalem.MacForge 2>/dev/null || true

echo "Recovery backup saved at: $BACKUP"
```

Inside MacForge, Settings -> Safety now also has:

- Restore Dock Managed Settings
- Disable Notch Island
- Reset Notch Layout
- Clear Live State
- Panic Reset Everything MacForge Changed

Dock restore uses the same whitelisted `/usr/bin/defaults` and `/usr/bin/killall Dock` command builder used by the Dock feature.
