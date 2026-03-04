#!/bin/bash
set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

APP_NAME="ListenType"
APP_DIR="/Applications/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-1.0"
DMG_DIR="/tmp/${DMG_NAME}-dmg"
DMG_TEMP="/tmp/${DMG_NAME}-temp.dmg"
DMG_OUTPUT="${PROJECT_ROOT}/${DMG_NAME}.dmg"
VOLUME_NAME="$APP_NAME"
BG_IMG="/tmp/dmg_background.png"

# Check app exists
if [ ! -d "$APP_DIR" ]; then
    echo "Error: $APP_DIR not found. Run scripts/build.sh first."
    exit 1
fi

# Generate background image with arrow
echo "Generating background..."
swift - << 'SWIFT'
import AppKit
let W = 520, H = 280
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
NSColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()
// Use SF Symbol arrow between icons
let arrowY = CGFloat(H - 140)
let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .ultraLight)
if let arrow = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let arrowSize = arrow.size
    let x = CGFloat(260) - arrowSize.width / 2
    let y = arrowY - arrowSize.height / 2
    NSColor(white: 0.5, alpha: 0.7).setFill()
    arrow.draw(in: NSRect(x: x, y: y, width: arrowSize.width, height: arrowSize.height),
               from: .zero, operation: .sourceOver, fraction: 0.5)
}
img.unlockFocus()
let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/dmg_background.png"))
SWIFT

echo "Creating DMG..."

# Clean up previous
rm -rf "$DMG_DIR"
rm -f "$DMG_TEMP" "$DMG_OUTPUT"

# Create staging directory
mkdir -p "$DMG_DIR/.background"
cp -R "$APP_DIR" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
cp "$BG_IMG" "$DMG_DIR/.background/background.png"

# Create read-write DMG
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDRW \
    "$DMG_TEMP"

# Mount it
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | grep "/Volumes/$VOLUME_NAME" | awk '{print $1}')
sleep 1

# Style with AppleScript
echo "Styling DMG window..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 720, 400}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set background picture of theViewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {130, 140}
        set position of item "Applications" of container window to {390, 140}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Unmount
sync
hdiutil detach "$DEVICE" -quiet 2>/dev/null || hdiutil detach "$DEVICE" -force -quiet

# Convert to compressed read-only DMG
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_OUTPUT"

# Clean up
rm -rf "$DMG_DIR" "$DMG_TEMP"

echo ""
echo "DMG created: $DMG_OUTPUT"
echo "Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
