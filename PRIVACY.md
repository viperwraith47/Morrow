# Morrow Privacy Notice

Morrow is a native macOS wallpaper browser. This notice describes what the app does with information when you use it.

## Network requests

Morrow sends search and image requests directly from your Mac. You choose Wallhaven or Pixabay as the discovery provider in Settings. Wallhaven search uses its public API for SFW results in the General category only (excluding Anime and People) and does not require a key. Pixabay search requires a saved Pixabay API key; Pixabay receives your search terms and key in the HTTPS request, plus standard network information needed to serve it, including your IP address and request headers. Morrow does not silently switch providers when the selected source is unavailable. Existing Wikimedia Commons favorites remain in your library; opening or downloading one may contact Wikimedia for its image. Morrow does not operate an account service or server and does not upload your favorites, collections, or local wallpaper files.

Pixabay API responses are cached locally for 24 hours. Some higher-resolution response URLs may be unavailable without account approval, so Morrow uses the best available returned image URL. Pixabay says its search image URLs are temporary display URLs and prohibits permanent hotlinking. Use Morrow's explicit Keep Offline, Download, or Set as Wallpaper action to save an image locally. Pixabay's API guidance recommends server-side downloads; Morrow uses direct client requests and does not claim Pixabay has approved this architecture. Wallhaven search requests use its documented 24-result pages and may be rate-limited; Wallhaven images remain the property of their respective owners, so review each linked source page for rights and usage information. See the [Pixabay privacy policy](https://pixabay.com/service/privacy/), [Wallhaven privacy policy](https://wallhaven.cc/privacy-policy), and [Wikimedia Foundation privacy policy](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy).

## API key storage

A Pixabay key entered in Morrow Settings is stored in macOS Keychain and can be updated or removed there. The key is sent to Pixabay with API requests and is not sent to a Morrow-operated server. Developers may optionally use the local Debug-only `Morrow/Config/LocalSecrets.xcconfig` override. That file is Git-ignored, is included only in Debug configuration, and should never contain a key intended for distribution. Release builds do not include or read that override.

## Information stored on your Mac

Saved wallpaper metadata and collection membership are kept in the app's local preferences. Collections organize favorites and are not synced. When you choose Keep Offline, Morrow stores the image file in its sandboxed Application Support folder so previews and applying continue to work without a connection. Removing the offline copy deletes that local file; removing a favorite does not remove an offline copy. Wallpaper files you download are saved where you choose. When you apply a wallpaper, Morrow keeps a copy in `~/Pictures/Morrow Wallpapers` so it remains available locally.

Morrow does not upload your favorites, collections, or local wallpaper files.

## Existing library and older versions

Existing Wikimedia Commons favorites, offline catalog entries and files, and collections remain in their current local storage paths. They are not deleted or silently imported into Wallhaven or Pixabay records. Older Unsplash favorites are not imported. A previous Unsplash Keychain item is neither read nor deleted by this release; remove it yourself in Keychain Access if you no longer need it.

## Content and licensing

Wallhaven results link to their source pages and do not carry a blanket reuse license; all images remain the property of their respective owners. Pixabay results are attributed to Pixabay and their contributor when available and are provided under the Pixabay Content License; review the linked Pixabay page and license terms before use. Existing Wikimedia Commons items retain their original CC0 metadata and attribution; Commons metadata is community-maintained and is not a legal guarantee about a particular file. Morrow is independent and is not endorsed by any of these providers.

This privacy notice is included with the source code. It is not currently hosted as a public webpage.
