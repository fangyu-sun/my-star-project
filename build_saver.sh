#!/bin/bash
set -e

ACTION=$1
BUNDLE_ID="com.fangyu.MyUniverseSaver"
USER_SAVER_PATH="$HOME/Library/Screen Savers/MyUniverseSaver.saver"
SYS_SAVER_PATH="/Library/Screen Savers/MyUniverseSaver.saver"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
SWIFT_MODULE_CACHE="${TMPDIR:-/tmp}/MyUniverseSaverSwiftModuleCache"

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
    mkdir -p "$SWIFT_MODULE_CACHE"
    
    echo "======================================================"
    echo "🚀 Building MyUniverseSaver (Timestamp: $BUILD_TIMESTAMP)"
    echo "======================================================"
    
    echo "[1/7] Building Web Project..."
    npx vite build --config vite.screensaver.config.js
    
    echo "[1.2/7] Adapting dual entry output to index.html..."
    mv dist/screensaver.html dist/index.html
    
    echo "[1.5/7] Verifying classic script compliance..."
    
    # 1. Verify no type="module" in index.html
    if grep -q 'type="module"' dist/index.html; then
        echo "❌ COMPLIANCE ERROR: 'type=\"module\"' found in dist/index.html!"
        exit 1
    fi
    
    # 2. Verify no crossorigin in index.html
    if grep -q 'crossorigin' dist/index.html; then
        echo "❌ COMPLIANCE ERROR: 'crossorigin' found in dist/index.html!"
        exit 1
    fi
    
    # 3. Verify no modulepreload in index.html
    if grep -q 'modulepreload' dist/index.html; then
        echo "❌ COMPLIANCE ERROR: 'modulepreload' found in dist/index.html!"
        exit 1
    fi
    
    # 4. Verify no statements with 'import' or 'export' in statement contexts inside assets JS files
    JS_FILE=$(ls dist/assets/*.js | head -n 1)
    if [ -n "$JS_FILE" ]; then
        if grep -q -E '(^|[ ;])import[ (]' "$JS_FILE"; then
            echo "❌ COMPLIANCE ERROR: 'import' statement detected in $JS_FILE!"
            exit 1
        fi
        if grep -q -E '(^|[ ;])export[ {]' "$JS_FILE"; then
            echo "❌ COMPLIANCE ERROR: 'export' statement detected in $JS_FILE!"
            exit 1
        fi
        echo "✅ Classic script compliance verified successfully!"
    else
        echo "❌ ERROR: No JS asset found in dist/assets!"
        exit 1
    fi
    
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
    <string>MyUniverseView</string>
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
    
    echo "[5/7] Compiling Swift (Universal Binary)..."
    echo "  -> Compiling for x86_64 (Intel)..."
    swiftc \
      -target x86_64-apple-macos11.0 \
      -module-cache-path "$SWIFT_MODULE_CACHE" \
      -emit-library \
      -o MyUniverseSaver_x86_64 \
      -framework ScreenSaver -framework WebKit -framework Cocoa \
      macos-saver/MyUniverseSaver/MyUniverseSaverView.swift \
      macos-saver/MyUniverseSaver/OptionsSheet.swift
      
    echo "  -> Compiling for arm64 (Apple Silicon)..."
    swiftc \
      -target arm64-apple-macos11.0 \
      -module-cache-path "$SWIFT_MODULE_CACHE" \
      -emit-library \
      -o MyUniverseSaver_arm64 \
      -framework ScreenSaver -framework WebKit -framework Cocoa \
      macos-saver/MyUniverseSaver/MyUniverseSaverView.swift \
      macos-saver/MyUniverseSaver/OptionsSheet.swift
      
    echo "  -> Merging architectures via lipo..."
    lipo -create MyUniverseSaver_x86_64 MyUniverseSaver_arm64 -output MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver
    
    # Cleanup temporary compile artifacts
    rm -f MyUniverseSaver_x86_64 MyUniverseSaver_arm64
      
    # IMPORTANT: Ensure executable permission
    chmod +x MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver
      
    echo "[6/8] Verifying structural integrity..."
    
    # Bundle verification
    if [ ! -f "MyUniverseSaver.saver/Contents/Resources/web/index.html" ]; then
        echo "❌ ERROR: index.html not found!"
        exit 1
    fi
    
    if grep -q 'src="/' MyUniverseSaver.saver/Contents/Resources/web/index.html || grep -q 'href="/' MyUniverseSaver.saver/Contents/Resources/web/index.html; then
        echo "❌ ERROR: Absolute paths detected in index.html!"
        exit 1
    fi
    
    # Plist verification
    PRINCIPAL_CLASS=$(plutil -extract NSPrincipalClass raw MyUniverseSaver.saver/Contents/Info.plist)
    if [ "$PRINCIPAL_CLASS" != "MyUniverseView" ]; then
        echo "❌ ERROR: NSPrincipalClass must be MyUniverseView. Found: $PRINCIPAL_CLASS"
        exit 1
    fi
    
    EXECUTABLE_NAME=$(plutil -extract CFBundleExecutable raw MyUniverseSaver.saver/Contents/Info.plist)
    if [ "$EXECUTABLE_NAME" != "MyUniverseSaver" ]; then
        echo "❌ ERROR: CFBundleExecutable must be MyUniverseSaver. Found: $EXECUTABLE_NAME"
        exit 1
    fi
    
    # Binary verification
    if [ ! -f "MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver" ]; then
        echo "❌ ERROR: Executable MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver not found!"
        exit 1
    fi
    
    if [ ! -x "MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver" ]; then
        echo "❌ ERROR: Executable does not have execution permissions!"
        exit 1
    fi
    
    # NM Symbol verification
    NM_OUTPUT=$(nm MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver || true)
    if ! echo "$NM_OUTPUT" | grep -q 'MyUniverseView'; then
        echo "❌ ERROR: nm check failed! Objective-C class MyUniverseView is not exported."
        echo "nm output:"
        echo "$NM_OUTPUT"
        exit 1
    fi
    
    echo "✅ Info.plist NSPrincipalClass: $PRINCIPAL_CLASS"
    echo "✅ Info.plist CFBundleExecutable: $EXECUTABLE_NAME"
    echo "✅ Executable file exists and is executable."
    echo "✅ Objective-C class MyUniverseView successfully exported."

    echo "[7/8] Signing screen saver bundle..."
    codesign --force --deep --sign "$CODESIGN_IDENTITY" \
      --identifier "$BUNDLE_ID" \
      MyUniverseSaver.saver

    if ! codesign --verify --deep --strict --verbose=4 MyUniverseSaver.saver; then
        echo "❌ ERROR: codesign verification failed for MyUniverseSaver.saver."
        exit 1
    fi
    echo "✅ Code signature verified."
    
    echo "[8/8] Installing & Clearing caches..."
    clean_cache
    cp -R MyUniverseSaver.saver "$USER_SAVER_PATH"

    if ! codesign --verify --deep --strict --verbose=4 "$USER_SAVER_PATH"; then
        echo "❌ ERROR: installed saver failed codesign verification."
        exit 1
    fi
    
    echo "======================================================"
    echo "✅ Install Complete!"
    echo "👉 Installed saver path: $USER_SAVER_PATH"
    echo "👉 CFBundleIdentifier: $(plutil -extract CFBundleIdentifier raw MyUniverseSaver.saver/Contents/Info.plist)"
    echo "👉 CFBundlePackageType: $(plutil -extract CFBundlePackageType raw MyUniverseSaver.saver/Contents/Info.plist)"
    echo "👉 CFBundleExecutable: $EXECUTABLE_NAME"
    echo "👉 NSPrincipalClass: $PRINCIPAL_CLASS"
    echo "👉 Actual executable path: $USER_SAVER_PATH/Contents/MacOS/MyUniverseSaver"
    echo "👉 Executable exists: true"
    echo "👉 Executable permission: $(stat -f "%Sp" "$USER_SAVER_PATH/Contents/MacOS/MyUniverseSaver")"
    echo "👉 Whether nm contains MyUniverseView: true"
    echo "👉 Build timestamp: $BUILD_TIMESTAMP"
    echo ""
    echo "To configure, go to: System Settings -> Screen Saver -> MyUniverseSaver -> Options"
    echo "Or open settings directly with:"
    echo "  open \"x-apple.systempreferences:com.apple.Desktop-Settings.extension\""
    echo "======================================================"
    exit 0
fi

print_usage
