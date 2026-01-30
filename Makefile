# ============================================================================
# MAKEFILE FOR JAI MEATBOY
# ============================================================================
# Alternative to using build.jai directly
# ============================================================================

.PHONY: all desktop android clean apk install run

# Default target
all: desktop

# Desktop build (for testing)
desktop:
	@echo "Building for desktop..."
	jai build.jai
	@echo "Done! Run with: ./build/desktop/meatboy"

desktop-release:
	@echo "Building for desktop (release)..."
	jai build.jai - release
	@echo "Done!"

# Android ARM64 build
android:
	@echo "Building for Android ARM64..."
	jai build.jai - android
	@echo "Done! Native library at: build/android/lib/arm64-v8a/libjaimeatboy.so"

android-release:
	@echo "Building for Android ARM64 (release)..."
	jai build.jai - android release
	@echo "Done!"

# Package APK
apk: android
	@echo "Packaging APK..."
	chmod +x package_apk.sh
	./package_apk.sh
	@echo "APK created: build/output/JaiMeatboy.apk"

# Install APK to connected device
install: apk
	@echo "Installing to device..."
	adb install -r build/output/JaiMeatboy.apk
	@echo "Installed!"

# Run on device
run:
	@echo "Launching on device..."
	adb shell am start -n com.example.jaimeatboy/android.app.NativeActivity

# Clean build artifacts
clean:
	rm -rf build/
	rm -rf .build/
	@echo "Cleaned!"

# Watch for changes and rebuild (requires entr)
watch:
	@echo "Watching for changes..."
	find src/ -name "*.jai" | entr -c make desktop

# Show project structure
tree:
	@find . -type f -name "*.jai" -o -name "*.json" -o -name "*.xml" -o -name "*.sh" | grep -v build | sort

# Help
help:
	@echo "Jai Meatboy Build System"
	@echo ""
	@echo "Targets:"
	@echo "  desktop         - Build for desktop (debug)"
	@echo "  desktop-release - Build for desktop (optimized)"
	@echo "  android         - Build native library for Android ARM64"
	@echo "  android-release - Build native library (optimized)"
	@echo "  apk             - Build Android + package APK"
	@echo "  install         - Build APK and install to device"
	@echo "  run             - Launch app on connected device"
	@echo "  clean           - Remove build artifacts"
	@echo "  watch           - Auto-rebuild on changes (needs entr)"
	@echo "  help            - Show this message"
