# Morrow for macOS

Morrow is a native SwiftUI wallpaper browser for macOS. Discover, search, filter, save, preview, download, and apply images from Wikimedia Commons. The app searches for bitmap files matching wallpaper or background terms, restricts its catalog to files tagged CC0, and checks returned license metadata; creator, license, and source details are shown with each image when available.

## Build and share

From Terminal, run:

```sh
./build.sh
```

The script builds a Release app and a shareable disk image:

- `.build/Build/Products/Release/Morrow.app`
- `Morrow.dmg` at the repository root

Open the DMG and drag Morrow into Applications. Override the build configuration with `CONFIGURATION=Debug ./build.sh`, or set `DEVELOPER_DIR` if Xcode is not selected as the active developer directory. You can also open `Morrow.xcodeproj` in Xcode and run the **Morrow** scheme. The app targets macOS 14 or later and has no third-party dependencies.

Applying a wallpaper keeps a persistent copy in `~/Pictures/Morrow Wallpapers`. The app is ad-hoc signed; distribution without Gatekeeper warnings requires Developer ID signing and notarization.

## Photo source and privacy

Morrow uses the Wikimedia Commons Action API with an identifying User-Agent. It requests small batches serially, caches network responses, and limits simultaneous media connections. Search terms and image requests go directly from the app to Wikimedia. Commons receives normal network information, such as the client IP address and request headers. Morrow does not use accounts, analytics, or advertising.

The CC0 category and per-file license metadata are provided by Commons contributors and are not a legal guarantee about every file. Open each Commons file page for its source information. Morrow shows creator and source details as a courtesy, including for CC0 works.

See [PRIVACY.md](PRIVACY.md) for Morrow’s privacy notice. This repository is private, so that file is not a publicly hosted policy page. A public release should link to a publicly accessible privacy notice.

Favorites and collections are kept locally in the app’s preferences; collections organize favorites for manual browsing and applying, and are not synced. Use Keep Offline to store a selected full-resolution original in Morrow’s sandboxed Application Support folder, where it remains available for previews and applying without a connection. Offline copies are independent of favorites and are removed only when you remove the offline copy; applied wallpapers are also copied to `~/Pictures/Morrow Wallpapers`. Downloads are saved wherever you choose. Morrow leaves wallpaper files from previous versions untouched. If an earlier Morrow version saved Unsplash favorites, those records remain in the old local storage key and are not imported into the Commons catalog. Any Unsplash key saved by an earlier version is neither read nor deleted by this version; remove it yourself in Keychain Access if you no longer need it.
