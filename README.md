# Morrow for macOS

Morrow is a native SwiftUI wallpaper browser for macOS, powered by the Unsplash API. Browse photography, search by subject or mood, filter by orientation, save favorites, preview images, download full-resolution wallpapers, or apply a photo directly to every connected display.

## Build and share

From Terminal, run:

```sh
./build.sh
```

The script builds a Release app and a shareable disk image:

- `.build/Build/Products/Release/Morrow.app`
- `Morrow.dmg`

Open the DMG and drag Morrow into Applications. Override the build configuration with `CONFIGURATION=Debug ./build.sh`, or set `DEVELOPER_DIR` if Xcode is not selected as the active developer directory. You can also open `Morrow.xcodeproj` in Xcode and run the **Morrow** scheme. After launch, open **Morrow > Settings** (Command–Comma) and connect your Unsplash Access Key.

The Xcode project targets macOS 14 or later. It uses the standard SwiftUI/AppKit frameworks and has no third-party dependencies. Applying a wallpaper keeps a persistent copy in `~/Pictures/Morrow Wallpapers`. The app is ad-hoc signed, but this Mac has no Apple Developer ID signing identity and the build is not notarized. Friends may need to Control-click the app and choose **Open** on first launch. Gatekeeper-trusted distribution without that prompt requires Developer ID signing and notarization.

## Connect Unsplash

1. Create a free developer application at [unsplash.com/oauth/applications](https://unsplash.com/oauth/applications).
2. Copy its **Access Key**, not the Secret Key.
3. Paste it into Morrow’s Unsplash settings.

The app validates and stores the key in macOS Keychain. Photo requests go directly from the app to Unsplash. The app uses Unsplash’s public API and download-tracking endpoint, and includes photographer attribution. Unsplash demo applications are limited to 50 API requests per hour.
