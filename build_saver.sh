#!/bin/bash
set -e

ACTION=$1
BUNDLE_ID="com.fangyu.MyUniverseSaver"
USER_SAVER_PATH="$HOME/Library/Screen Savers/MyUniverseSaver.saver"
SYS_SAVER_PATH="/Library/Screen Savers/MyUniverseSaver.saver"

print_usage() {
    echo "======================================================"
    echo "🌌 MyUniverseSaver - macOS Screen Saver Build Script"
    echo "======================================================"
    echo "Usage:"
    echo "  ./build_saver.sh --install-dev           Build and install to user Screen Savers directory."
    echo "  ./build_saver.sh --clean-saver-cache     Clear cached screensaver files and kill background processes."
    echo "  ./build_saver.sh --reset-saver-defaults  Clear ScreenSaverDefaults to wipe broken saved config."
    echo "======================================================"
    exit 1
}

clean_cache() {
    echo "[🧹] Cleaning macOS Screen Saver caches..."
    rm -rf "$USER_SAVER_PATH"
    
    if [ -d "$SYS_SAVER_PATH" ]; then
        echo "[🧹] System-level saver found. Attempting to remove..."
        sudo rm -rf "$SYS_SAVER_PATH" || echo "[⚠️] Could not remove system saver. You may need to remove it manually."
    fi
    
    echo "[🧹] Killing caching processes..."
    killall "System Settings" 2>/dev/null || true
    killall legacyScreenSaver 2>/dev/null || true
    killall ScreenSaverEngine 2>/dev/null || true
    killall cfprefsd 2>/dev/null || true
    echo "[✅] Cache cleaned."
}

reset_defaults() {
    echo "[🗑️] Resetting ScreenSaverDefaults for $BUNDLE_ID..."
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    echo "[✅] Defaults reset."
}

if [ -z "$ACTION" ]; then
    print_usage
fi

if [ "$ACTION" == "--reset-saver-defaults" ]; then
    reset_defaults
    exit 0
fi

if [ "$ACTION" == "--clean-saver-cache" ]; then
    clean_cache
    exit 0
fi

if [ "$ACTION" == "--install-dev" ]; then
    BUILD_TIMESTAMP=$(date +%s)
    
    echo "======================================================"
    echo "🚀 Building MyUniverseSaver (Timestamp: $BUILD_TIMESTAMP)"
    echo "======================================================"
    
    echo "[1/7] Building Web Project..."
    npm run build
    
    echo "[2/7] Preparing bundle directory..."
    rm -rf MyUniverseSaver.saver
    mkdir -p MyUniverseSaver.saver/Contents/MacOS
    mkdir -p MyUniverseSaver.saver/Contents/Resources/web
    
    echo "[3/7] Generating Info.plist..."
    cat << EOF > MyUniverseSaver.saver/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MyUniverseSaver</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MyUniverseSaver</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>MyUniverseSaverView</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>My Universe uses your location to calculate real-time celestial positions directly above you.</string>
    <key>MyUniverseBuildTimestamp</key>
    <string>$BUILD_TIMESTAMP</string>
</dict>
</plist>
EOF

    echo "[4/7] Copying resources..."
    cp -R dist/* MyUniverseSaver.saver/Contents/Resources/web/
    cp macos-saver/Resources/cities.json MyUniverseSaver.saver/Contents/Resources/cities.json
    
    echo "[5/7] Compiling Swift..."
    swiftc \
      -target x86_64-apple-macos11.0 \
      -target arm64-apple-macos11.0 \
      -emit-library \
      -o MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver \
      -framework ScreenSaver -framework WebKit -framework Cocoa \
      macos-saver/MyUniverseSaver/MyUniverseSaverView.swift \
      macos-saver/MyUniverseSaver/OptionsSheet.swift
      
    echo "[6/7] Verifying structural integrity..."
    if [ ! -f "MyUniverseSaver.saver/Contents/Resources/web/index.html" ]; then
        echo "❌ ERROR: index.html not found!"
        exit 1
    fi
    
    if [ ! -f "MyUniverseSaver.saver/Contents/Resources/cities.json" ]; then
        echo "❌ ERROR: cities.json not found!"
        exit 1
    fi
    
    if grep -q 'src="/' MyUniverseSaver.saver/Contents/Resources/web/index.html || grep -q 'href="/' MyUniverseSaver.saver/Contents/Resources/web/index.html; then
        echo "❌ ERROR: Absolute paths detected in index.html! Vite base path configuration failed."
        exit 1
    fi
    
    echo "[7/7] Installing & Clearing caches..."
    clean_cache
    cp -R MyUniverseSaver.saver "$USER_SAVER_PATH"
    
    echo "======================================================"
    echo "✅ Install Complete!"
    echo "👉 Installed path: $USER_SAVER_PATH"
    echo "👉 CFBundleIdentifier: $BUNDLE_ID"
    echo "👉 Build Timestamp: $BUILD_TIMESTAMP"
    echo "👉 Web index path verified."
    echo "👉 cities.json path verified."
    echo ""
    echo "To configure, go to: System Settings -> Screen Saver -> MyUniverseSaver -> Options"
    echo "Or open settings directly with:"
    echo "  open \"x-apple.systempreferences:com.apple.Desktop-Settings.extension\""
    echo "======================================================"
    exit 0
fi

print_usage
