#!/bin/bash
# ============================================================================
# PACKAGE APK SCRIPT
# ============================================================================
# Creates an APK from the built native library
# Prerequisites:
#   - Android SDK with build-tools
#   - Java JDK (for jarsigner/apksigner)
#   - Built libjaimeatboy.so in build/android/lib/arm64-v8a/
# ============================================================================

set -e  # Exit on error

# Configuration
APP_NAME="JaiMeatboy"
PACKAGE_NAME="com.example.jaimeatboy"
VERSION_CODE="1"
VERSION_NAME="1.0"

# Paths (adjust as needed)
ANDROID_SDK="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
BUILD_TOOLS="$ANDROID_SDK/build-tools/34.0.0"
PLATFORM="$ANDROID_SDK/platforms/android-34"

# Working directories
BUILD_DIR="build/android"
APK_DIR="$BUILD_DIR/apk"
OUTPUT_DIR="build/output"

echo "=== Packaging APK: $APP_NAME ==="
echo "Package: $PACKAGE_NAME"
echo "Version: $VERSION_NAME ($VERSION_CODE)"
echo ""

# Check prerequisites
if [ ! -f "$BUILD_DIR/lib/arm64-v8a/libjaimeatboy.so" ]; then
    echo "ERROR: Native library not found!"
    echo "Build first with: jai build.jai - android"
    exit 1
fi

if [ ! -d "$ANDROID_SDK" ]; then
    echo "ERROR: Android SDK not found at $ANDROID_SDK"
    echo "Set ANDROID_SDK_ROOT environment variable"
    exit 1
fi

# Clean and create directories
rm -rf "$APK_DIR"
mkdir -p "$APK_DIR"
mkdir -p "$OUTPUT_DIR"

echo "1. Copying files..."

# Copy native library
mkdir -p "$APK_DIR/lib/arm64-v8a"
cp "$BUILD_DIR/lib/arm64-v8a/libjaimeatboy.so" "$APK_DIR/lib/arm64-v8a/"

# Copy assets
mkdir -p "$APK_DIR/assets"
cp -r assets/* "$APK_DIR/assets/"

# Copy Android resources
mkdir -p "$APK_DIR/res/values"
mkdir -p "$APK_DIR/res/mipmap-hdpi"
mkdir -p "$APK_DIR/res/mipmap-mdpi"
mkdir -p "$APK_DIR/res/mipmap-xhdpi"
mkdir -p "$APK_DIR/res/mipmap-xxhdpi"

# Create strings.xml
cat > "$APK_DIR/res/values/strings.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$APP_NAME</string>
</resources>
EOF

# Create styles.xml
cat > "$APK_DIR/res/values/styles.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.Game" parent="android:Theme.NoTitleBar.Fullscreen">
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowContentOverlay">@null</item>
    </style>
</resources>
EOF

# Create placeholder icons (you should replace these with actual icons)
echo "Creating placeholder icons..."
for size in hdpi mdpi xhdpi xxhdpi; do
    # Create a simple colored square as placeholder
    convert -size 48x48 xc:'#E84A4A' "$APK_DIR/res/mipmap-$size/ic_launcher.png" 2>/dev/null || \
    echo "  (ImageMagick not found, skipping icon generation)"
    cp "$APK_DIR/res/mipmap-$size/ic_launcher.png" "$APK_DIR/res/mipmap-$size/ic_launcher_round.png" 2>/dev/null || true
done

echo "2. Compiling resources..."

# Compile resources with AAPT2
"$BUILD_TOOLS/aapt2" compile \
    --dir "$APK_DIR/res" \
    -o "$APK_DIR/compiled_res.zip"

# Link resources and create base APK
"$BUILD_TOOLS/aapt2" link \
    --proto-format \
    -o "$APK_DIR/base.apk" \
    -I "$PLATFORM/android.jar" \
    --manifest "android/AndroidManifest.xml" \
    --min-sdk-version 24 \
    --target-sdk-version 34 \
    --version-code "$VERSION_CODE" \
    --version-name "$VERSION_NAME" \
    -R "$APK_DIR/compiled_res.zip" \
    --auto-add-overlay

echo "3. Adding native libraries and assets..."

# Unzip base APK to add more files
unzip -q "$APK_DIR/base.apk" -d "$APK_DIR/unpacked"

# Add native library
cp -r "$APK_DIR/lib" "$APK_DIR/unpacked/"

# Add assets
cp -r "$APK_DIR/assets" "$APK_DIR/unpacked/"

# Repack
cd "$APK_DIR/unpacked"
zip -q -r "../unsigned.apk" .
cd - > /dev/null

echo "4. Aligning APK..."

"$BUILD_TOOLS/zipalign" -f -p 4 \
    "$APK_DIR/unsigned.apk" \
    "$APK_DIR/aligned.apk"

echo "5. Signing APK..."

# Generate debug keystore if it doesn't exist
KEYSTORE="$BUILD_DIR/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    echo "  Creating debug keystore..."
    keytool -genkey -v \
        -keystore "$KEYSTORE" \
        -alias "debug" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass "android" \
        -keypass "android" \
        -dname "CN=Debug, OU=Debug, O=Debug, L=Debug, ST=Debug, C=US"
fi

# Sign with apksigner
"$BUILD_TOOLS/apksigner" sign \
    --ks "$KEYSTORE" \
    --ks-key-alias "debug" \
    --ks-pass "pass:android" \
    --key-pass "pass:android" \
    --out "$OUTPUT_DIR/$APP_NAME.apk" \
    "$APK_DIR/aligned.apk"

echo ""
echo "=== Build Complete ==="
echo "APK: $OUTPUT_DIR/$APP_NAME.apk"
echo ""
echo "Install with:"
echo "  adb install -r $OUTPUT_DIR/$APP_NAME.apk"
echo ""
echo "Run with:"
echo "  adb shell am start -n $PACKAGE_NAME/android.app.NativeActivity"
