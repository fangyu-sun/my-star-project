#!/bin/bash
set -e

echo "======================================================"
echo "🌌 MyUniverseSaver - macOS Screen Saver Build Script"
echo "======================================================"

echo "[1/6] 🚀 Building Web Project (Screensaver Mode Base)..."
npm run build

echo "[2/6] 🔨 Preparing macOS Screen Saver Bundle Directory..."
rm -rf MyUniverseSaver.saver
mkdir -p MyUniverseSaver.saver/Contents/MacOS
mkdir -p MyUniverseSaver.saver/Contents/Resources/web

echo "[3/6] 📝 Generating Info.plist..."
cat << 'EOF' > MyUniverseSaver.saver/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MyUniverseSaver</string>
    <key>CFBundleIdentifier</key>
    <string>com.sunfangyu.MyUniverseSaver</string>
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
</dict>
</plist>
EOF

echo "[4/6] 📦 Copying Web Dist to Resources..."
cp -R dist/* MyUniverseSaver.saver/Contents/Resources/web/

echo "[5/6] 🍎 Compiling Swift Source (Targeting macOS 11.0)..."
swiftc \
  -target x86_64-apple-macos11.0 \
  -target arm64-apple-macos11.0 \
  -emit-library \
  -o MyUniverseSaver.saver/Contents/MacOS/MyUniverseSaver \
  -framework ScreenSaver -framework WebKit -framework Cocoa \
  macos-saver/MyUniverseSaver/MyUniverseSaverView.swift \
  macos-saver/MyUniverseSaver/OptionsSheet.swift

echo "[6/6] 🔍 Verifying Bundle Structure and Relative Paths..."
if [ ! -f "MyUniverseSaver.saver/Contents/Resources/web/index.html" ]; then
    echo "❌ ERROR: index.html not found in Resources/web/"
    exit 1
fi

if grep -q 'src="/' MyUniverseSaver.saver/Contents/Resources/web/index.html || grep -q 'href="/' MyUniverseSaver.saver/Contents/Resources/web/index.html; then
    echo "❌ ERROR: Absolute paths detected in index.html! Vite base path configuration failed."
    exit 1
else
    echo "✅ Success: index.html uses relative paths."
fi

echo "======================================================"
echo "✅ Build Complete!"
echo "📁 Bundle Path: $(pwd)/MyUniverseSaver.saver"
echo "👉 You can install the screensaver by double-clicking it."
echo "======================================================"
