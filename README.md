# 🖼️ Morrow — Native macOS Wallpaper Browser

<p align="center">
  <img src="Morrow/Assets.xcassets/AppIcon.appiconset/icon_128x128.png" width="128" height="128" alt="Morrow app icon" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue" alt="macOS 14 or later" />
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift 5.0" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-blue" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Images-Wallhaven%20%7C%20Pixabay-green" alt="Wallhaven and Pixabay sources" />
</p>

**Morrow** is a native macOS app for finding, organizing, and setting desktop wallpapers. Choose Wallhaven for public SFW results in its General category only (excluding Anime and People), or choose Pixabay and search with your own API key. Preview source and available rights information, save favorites, group them into collections, keep images offline, and apply a wallpaper to all connected displays.

Morrow is built with **Swift** and **SwiftUI**. Select Wallhaven or Pixabay in Settings; Wallhaven needs no key, while Pixabay requires a personal API key stored in macOS Keychain. If Pixabay is selected without a key, Morrow asks you to add one and does not switch providers. Your library stays on your Mac. Discovery and wallpaper changes are manual—Morrow does not rotate wallpapers on a schedule.

<p align="center">
  <a href="https://github.com/viperwraith47/Morrow/releases/latest/download/Morrow.dmg">⬇️ Download latest Morrow.dmg</a>
  · <a href="https://github.com/viperwraith47/Morrow/releases">View all releases</a>
</p>

<p align="center"><sub>Attach the build output as a GitHub release asset named <code>Morrow.dmg</code>. Release downloads follow repository visibility.</sub></p>

---

## ✨ Features

- **🔎 Discover and search:** Browse For You or explore Nature, Architecture, Minimal, Ocean, and Abstract. Search with your own terms and scroll to load more results.
- **↕️ Orientation filters:** Narrow results to all images, portrait, or landscape.
- **🖼️ Large previews:** Open a wallpaper to inspect available quality, dimensions, file size, upload date, provider, source, and rights information, with a link to its Wallhaven, Pixabay, or saved Commons page.
- **❤️ Favorites:** Save and remove wallpapers from the grid or preview; saved wallpapers are available in your local library.
- **📚 Collections:** Create, rename, and delete named collections to organize favorites. A favorite can appear in multiple collections.
- **📥 Offline library:** Keep the highest-resolution image available from the selected provider on your Mac, then browse, preview, or apply it without an internet connection.
- **⬇️ Downloads:** Save the best available image rendition to a location you choose.
- **🖥️ Set as Wallpaper:** Apply an image to all connected displays. Morrow also keeps a copy in `~/Pictures/Morrow Wallpapers`.
- **🔒 Local-first privacy:** Favorites, collections, and offline copies stay on this Mac; Morrow has no accounts, advertising, analytics, or cloud sync.
- **⚙️ Native Mac interface:** A SwiftUI app with a sidebar, searchable wallpaper grid, orientation controls, preview window, and Settings and Credits panes.

### Keep, collect, and apply

Collections organize favorites; they do not duplicate image files. Save an image before adding it to a collection. Removing a favorite removes its collection memberships, but leaves any offline copy in place. Deleting a collection leaves favorites and offline copies untouched. Offline copies are removed only when you choose **Remove Offline Copy**.

---

## 🛠️ How Morrow Works

Morrow sends native HTTPS search requests directly from your Mac to the selected provider. Wallhaven searches public SFW results in the General category only (excluding Anime and People) without a key; Pixabay searches require a saved API key. The selected provider is independent of key state, and failures never silently switch sources. Existing Wikimedia Commons favorites and offline items remain available with their Commons attribution.

```text
 Search or browse
        │
        ├── Wallhaven selected ──► Wallhaven API · General category, SFW only
        │                                    · 24 results per page
        │
        └── Pixabay selected ───────────────► Pixabay API · key required
                                             │
                                             ▼
                               Browse and preview with provider attribution
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    ▼                        ▼                        ▼
             Save favorites          Keep Offline / Download     Set Wallpaper
             local preferences       local image file            displays + Pictures
```

### Under the hood

1. **Provider selection:** Choose Wallhaven or Pixabay in Settings. Morrow remembers the choice independently of the API key. A missing Pixabay key produces a clear message and never triggers a fallback. Existing Commons favorites, offline files, and collections remain available; they are not migrated.
2. **Wallhaven search:** Uses the public search API with `categories=100` (General only; excludes Anime and People) and `purity=100` (SFW only), 24 results per page, and Wallhaven's pagination metadata. Orientation filtering remains local. Wallhaven's documented rate limit is 45 requests per minute; rate-limit and network/API errors are shown clearly.
3. **Pixabay search:** Requests photographs in small pages, applies the orientation filter, and caches each API response locally for 24 hours as Pixabay requires. The default API rate limit is 100 requests per 60 seconds; rate-limit and network/API errors are shown clearly.
4. **Attribution and image use:** Search tiles and previews identify Wallhaven or Pixabay and link to the source page. Wallhaven's search response does not identify the uploader and does not grant a blanket reuse license; review the linked page. Pixabay results show available creator and license information. Pixabay search image URLs are temporary display URLs, not permanent hotlinks. Higher-resolution response URLs are optional, so Morrow falls back to the available web-format image. Use Keep Offline, Download, or Set as Wallpaper to explicitly download an image locally. Pixabay's API guidance recommends server-side downloads; Morrow uses direct client requests and does not claim Pixabay has approved that architecture. Existing Commons records continue to show their stored provider, source, and license information.
5. **Local library:** Favorite metadata, collection membership, and offline-catalog metadata remain in local app preferences. Full offline image files live separately in Morrow’s Application Support folder.
6. **Applying a wallpaper:** Uses macOS to set the selected image on each connected display and saves a persistent copy under `~/Pictures/Morrow Wallpapers`.

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

#### Optional local Debug API key

For development only, copy `Morrow/Config/LocalSecrets.xcconfig.example` to `Morrow/Config/LocalSecrets.xcconfig` and replace the placeholder with your own rotated Pixabay API key. This file is Git-ignored, and the Xcode project includes it only in the Debug configuration. It is not included in Release builds. App users should enter their key in Settings instead; never put a personal key in tracked source or share a Debug build containing your local key.

### Sharing the app

The current build is **ad-hoc signed and not notarized**. macOS may require confirmation the first time you open it. For a local build, Control-click Morrow in Applications and choose **Open**, or use **Open Anyway** in System Settings → Privacy & Security if macOS presents that option. For broad distribution, sign with a Developer ID certificate and notarize the app rather than asking users to bypass Gatekeeper.

---

## 🔐 Privacy and Licensing

Morrow sends requests directly from your Mac to the selected source. Wallhaven receives SFW search terms and a General-category-only filter, excluding Anime and People, plus standard connection information; Pixabay receives the key and search terms only when Pixabay is selected. Pixabay search responses are cached locally for 24 hours. Morrow has no account service or server and does not upload your favorites, collections, or local wallpaper files. Pixabay's API guidance recommends server-side downloads; Morrow uses direct client requests and does not claim that Pixabay has approved this architecture. Opening an existing Commons wallpaper may still request its image from Wikimedia.

- Favorites and collections are stored locally in the app’s preferences.
- Full-resolution offline copies are stored in Morrow’s sandboxed Application Support folder.
- Applied wallpapers are copied to `~/Pictures/Morrow Wallpapers`.
- Downloads are saved wherever you choose.

Wallhaven results do not carry a blanket reuse license; all images remain the property of their respective owners, so review the linked page for rights and usage information. Pixabay results are provided under the Pixabay Content License; review the source page and license terms before use. Pixabay image URLs are temporary search-display URLs, so use Morrow’s explicit local download or offline-save actions for copies. Existing Commons records retain their CC0 metadata, but Commons information is community-maintained and is not a legal guarantee; review the linked file page. Morrow is independent and is not endorsed by Wallhaven, Wikimedia, or Pixabay.

See [PRIVACY.md](PRIVACY.md) for the full notice. It is included in this source repository but is not currently hosted at a public URL; a public release should provide a publicly accessible privacy-policy link.

### Upgrading from an older version

Morrow leaves files from previous versions untouched. Existing Wikimedia Commons favorites, offline files, and collections remain available under their existing local storage paths and are not silently imported into Wallhaven or Pixabay records. Older Unsplash favorites are not imported, and an old Unsplash Keychain item is neither read nor deleted.

---

## 🤝 Credits

Designed and developed by [**Viperwraith47**](https://github.com/viperwraith47). Images are discovered through Wallhaven or Pixabay; existing Wikimedia Commons items remain supported. Morrow identifies the provider and shows available creator, source, and rights information.
