#!/bin/bash

# BoaMarkdown Installation Script
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."
cd "$PROJECT_ROOT"

CONFIGURATION=${1:-Release}
SKIP_BUILD=${2:-false}
INSTALL_MODE=${3:-development}

echo "════════════════════════════════════════════════════════════════"
echo "  🚀 Installing BoaMarkdown - $CONFIGURATION Configuration"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. Build the app (skip if already built by make debug)
if [ "$SKIP_BUILD" = "false" ]; then
    echo "📦 Building application in $CONFIGURATION mode..."
    make app CONFIGURATION="$CONFIGURATION"
else
    echo "📦 Skipping build (already completed)..."
fi

# 2. Copy to Applications
echo "🔍 Locating built application..."
APP_PATH=""

for path in ~/Library/Developer/Xcode/DerivedData/BoaMarkdown-*/Build/Products/"$CONFIGURATION"/"BoaMarkdown.app"; do
    if [ -d "$path" ]; then
        if [ -z "$APP_PATH" ] || [ "$path" -nt "$APP_PATH" ]; then
            APP_PATH="$path"
        fi
    fi
done

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Could not find built application in DerivedData."
    echo "   Expected path: .../Build/Products/$CONFIGURATION/BoaMarkdown.app"
    echo "   Please check if the build succeeded."
    exit 1
fi

echo "📋 Found app at: $APP_PATH"
echo "📋 Configuration: $CONFIGURATION"
echo "📋 Installing to /Applications..."
rm -rf "/Applications/BoaMarkdown.app"
cp -R "$APP_PATH" /Applications/

if [ "$INSTALL_MODE" = "development" ]; then
    INSTALLED_APP_PATH="/Applications/BoaMarkdown.app"
    APP_ENTITLEMENTS="$PROJECT_ROOT/Sources/Markdown/Markdown.entitlements"

    BASE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_APP_PATH/Contents/Info.plist")
    DISPLAY_VERSION="${BASE_VERSION}-dev-$(date '+%Y%m%d-%H%M%S')"
    echo "📋 Development display version: $DISPLAY_VERSION"
    /usr/libexec/PlistBuddy -c "Set :BoaDisplayVersion $DISPLAY_VERSION" "$INSTALLED_APP_PATH/Contents/Info.plist" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :BoaDisplayVersion string $DISPLAY_VERSION" "$INSTALLED_APP_PATH/Contents/Info.plist"

    echo "🔏 Re-signing development install..."
    /usr/bin/codesign --force --sign - --options runtime --entitlements "$APP_ENTITLEMENTS" "$INSTALLED_APP_PATH"
    /usr/bin/codesign --verify --strict --deep --verbose=2 "$INSTALLED_APP_PATH"
fi

# 3. Remove quarantine attribute
echo "🔓 Removing quarantine attribute..."
/usr/bin/xattr -cr "/Applications/BoaMarkdown.app"

# 4. Register with LaunchServices
echo "🔧 Registering with system..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/BoaMarkdown.app"

# 5. Launch app once to complete system registration
echo "🚀 Launching application to complete registration..."
open -g "/Applications/BoaMarkdown.app" --args --register-only
sleep 2

# 6. Set as default handler for .md files
echo "🔗 Setting as default handler for Markdown files..."
BUNDLE_ID="io.github.boaworm.Markdown"

# Try using duti if available (more reliable)
if command -v duti >/dev/null 2>&1; then
    echo "   Using duti to set default associations..."
    duti -s "$BUNDLE_ID" net.daringfireball.markdown all
    duti -s "$BUNDLE_ID" .md all
    duti -s "$BUNDLE_ID" .markdown all
    duti -s "$BUNDLE_ID" .mdown all
    echo "   ✓ Default associations set via duti"
else
    # Fallback to Swift LaunchServices API
    echo "   Using Swift LaunchServices API (duti not available)..."
    # Inside the checkout, not the world-writable /tmp where another user could plant the file.
    mkdir -p "$PROJECT_ROOT/tmp"
    HANDLER_SCRIPT="$PROJECT_ROOT/tmp/set_default_handler.swift"
    cat << 'EOF' > "$HANDLER_SCRIPT"
import Foundation
import CoreServices

func setDefaultHandler(bundleId: String, contentType: String) -> Bool {
    let cfBundleId = bundleId as CFString
    let cfContentType = contentType as CFString
    
    let result = LSSetDefaultRoleHandlerForContentType(cfContentType, LSRolesMask.all, cfBundleId)
    return result == noErr
}

let bundleId = "io.github.boaworm.Markdown"
let types = ["net.daringfireball.markdown", "public.markdown"]

var allSuccess = true
for type in types {
    if setDefaultHandler(bundleId: bundleId, contentType: type) {
        print("   ✓ Set handler for \(type)")
    } else {
        print("   ⚠ Failed for \(type)")
        allSuccess = false
    }
}
exit(allSuccess ? 0 : 1)
EOF
    swift "$HANDLER_SCRIPT" || {
        echo "   ⚠️  Automatic default app setting failed."
        echo "   📝 You can set it manually or install duti: brew install duti"
    }
    rm -f "$HANDLER_SCRIPT"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ Installation Complete - $CONFIGURATION Configuration"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🎉 BoaMarkdown has been automatically configured!"
echo ""
echo "📋 What was done:"
echo "   ✓ Application installed to /Applications"
echo "   ✓ Quarantine attribute removed (xattr -cr)"
echo "   ✓ Registered with system LaunchServices"
echo "   ✓ Launched once to complete registration"
echo "   ✓ Set as default handler for .md files"
echo ""
echo "📝 Sanity check:"
echo '   open -a BoaMarkdown "$PROJECT_ROOT/Tests/fixtures/acceptance-all.md"'
