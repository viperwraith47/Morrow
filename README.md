# 🖼️ Morrow — Native macOS Wallpaper Browser

<p align="center">
  <img src="Morrow/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" alt="Morrow app icon" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue" alt="macOS 14 or later" />
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift 5.0" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-blue" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Images-Wikimedia%20Commons-green" alt="Wikimedia Commons" />
</p>

**Morrow** is a native macOS app for finding, organizing, and setting desktop wallpapers. Explore images from Wikimedia Commons, preview their source and license details, save favorites, group them into collections, keep full-resolution originals offline, and apply a wallpaper to all connected displays.

Morrow is built with **Swift** and **SwiftUI**. It has no account or API-key setup, and keeps your library on your Mac. Discovery and wallpaper changes are manual—Morrow does not rotate wallpapers on a schedule.

<p align="center">
  <a href="https://github.com/viperwraith47/Morrow/releases/latest/download/Morrow.dmg">⬇️ Download latest Morrow.dmg</a>
  · <a href="https://github.com/viperwraith47/Morrow/releases">View all releases</a>
</p>

<p align="center"><sub>Attach the build output as a GitHub release asset named <code>Morrow.dmg</code>. Release downloads follow repository visibility.</sub></p>

---

## ✨ Features

- **🔎 Discover and search:** Browse For You or explore Nature, Architecture, Minimal, Ocean, and Abstract. Search with your own terms and scroll to load more results.
- **↕️ Orientation filters:** Narrow results to all images, portrait, or landscape.
- **🖼️ Large previews:** Open a wallpaper to inspect its title and available creator, source, and license details, with a link to its Commons file page.
- **❤️ Favorites:** Save and remove wallpapers from the grid or preview; saved wallpapers are available in your local library.
- **📚 Collections:** Create, rename, and delete named collections to organize favorites. A favorite can appear in multiple collections.
- **📥 Offline library:** Keep the full-resolution original on your Mac, then browse, preview, or apply it without an internet connection.
- **⬇️ Downloads:** Save the original image to a location you choose.
- **🖥️ Set as Wallpaper:** Apply an image to all connected displays. Morrow also keeps a copy in `~/Pictures/Morrow Wallpapers`.
- **🔒 Local-first privacy:** Favorites, collections, and offline copies stay on this Mac; Morrow has no accounts, advertising, analytics, or cloud sync.
- **⚙️ Native Mac interface:** A SwiftUI app with a sidebar, searchable wallpaper grid, orientation controls, preview window, and Settings and Credits panes.

### Keep, collect, and apply

Collections organize favorites; they do not duplicate image files. Save an image before adding it to a collection. Removing a favorite removes its collection memberships, but leaves any offline copy in place. Deleting a collection leaves favorites and offline copies untouched. Offline copies are removed only when you choose **Remove Offline Copy**.

---

## 🛠️ How Morrow Works

Morrow uses the Wikimedia Commons Action API to find wallpaper files. It asks for bitmap files matching wallpaper or background terms in the CC0 category, then checks each result’s license metadata before displaying it. When available, title, creator, source, and license information accompany the image.

```text
 Search or browse
        │
        ▼
 Wikimedia Commons Action API
        │  bitmap files · wallpaper/background · CC0 category
        ▼
 Check per-file license metadata
        │
        ├── Wallpaper details and thumbnail ──► Browse and preview
        │
        ├── Save favorite or collection ──────► Local app preferences
        │
        ├── Keep Offline ─────────────────────► Full original in Application Support
        │
        ├── Download ─────────────────────────► Folder you choose
        │
        └── Set as Wallpaper ─────────────────► All displays + Pictures copy
```

### Under the hood

1. **Commons search:** Requests file results in small pages and includes the user’s search terms alongside bitmap, wallpaper/background, and CC0 search constraints.
2. **License check:** Reads each file’s Commons metadata and only displays a result when the license name or license URL identifies CC0.
3. **Image loading:** Uses Commons-provided thumbnail and original URLs. URLSession caching and an in-memory image cache help avoid repeated network transfers.
4. **Local library:** Stores favorite metadata, collection membership, and offline-catalog metadata in local app preferences. Full offline image files live separately in Morrow’s Application Support folder.
5. **Applying a wallpaper:** Uses macOS to set the selected image on each connected display and saves a persistent copy under `~/Pictures/Morrow Wallpapers`.

---

## 🚀 Build and Run

Morrow requires **macOS 14 or later** and a full Xcode installation. The project uses Swift 5.0 and has no third-party package dependencies.

From the repository root, build the app and create a disk image:

```bash
./build.sh
```

The script produces:

- **App:** `.build/Build/Products/Release/Morrow.app`
- **Installer disk image:** `Morrow.dmg` at the repository root, with an Applications shortcut

Open `Morrow.dmg` and drag Morrow into Applications. To build the Debug configuration instead:

```bash
CONFIGURATION=Debug ./build.sh
```

You can also open `Morrow.xcodeproj` in Xcode and run the **Morrow** scheme. If Xcode is not selected as the active developer directory, set `DEVELOPER_DIR` to the installation’s `Contents/Developer` directory.

### Sharing the app

The current build is **ad-hoc signed and not notarized**. macOS may require confirmation the first time you open it. For a local build, Control-click Morrow in Applications and choose **Open**, or use **Open Anyway** in System Settings → Privacy & Security if macOS presents that option. For broad distribution, sign with a Developer ID certificate and notarize the app rather than asking users to bypass Gatekeeper.

---

## 🔐 Privacy and Licensing

Morrow sends search and image requests directly from your Mac to Wikimedia Commons and its media servers. Wikimedia receives standard connection information needed to serve those requests, including your IP address and request headers. Morrow does not operate an account service or server, and it does not upload your favorites, collections, or local wallpaper files.

- Favorites and collections are stored locally in the app’s preferences.
- Full-resolution offline copies are stored in Morrow’s sandboxed Application Support folder.
- Applied wallpapers are copied to `~/Pictures/Morrow Wallpapers`.
- Downloads are saved wherever you choose.

Morrow searches for CC0 files and checks the returned license metadata, but Commons information is community-maintained and is not a legal guarantee about an individual file. Review the linked Commons file page and verify its details before relying on a license. Morrow is an independent app and is not endorsed by the Wikimedia Foundation.

See [PRIVACY.md](PRIVACY.md) for the full notice. It is included in this source repository but is not currently hosted at a public URL; a public release should provide a publicly accessible privacy-policy link.

### Upgrading from an older version

Morrow leaves files from previous versions untouched. Unsplash favorites saved by an older version are not imported into the Commons library. An old Unsplash Keychain item is neither read nor deleted; remove it yourself in Keychain Access if you no longer need it.

---

## 🤝 Credits

Designed and developed by [**Viperwraith47**](https://github.com/viperwraith47). Wallpaper files are provided by Wikimedia Commons contributors; Morrow shows creator and source information when Commons supplies it.
