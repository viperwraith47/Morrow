# Morrow Privacy Notice

Morrow is a native macOS wallpaper browser. This notice describes what the app does with information when you use it.

## Network requests

Morrow sends searches to the Wikimedia Commons Action API and loads image thumbnails and original files from Wikimedia Commons and Wikimedia's media servers. Search terms are included in search requests. Wikimedia receives standard network information needed to serve those requests, including your IP address and request headers. Morrow identifies its requests with an app-specific User-Agent.

Morrow does not require an account and does not include analytics, advertising, or a Morrow-operated server. Wikimedia's own privacy practices are described in the [Wikimedia Foundation privacy policy](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy).

## Information stored on your Mac

Saved wallpaper metadata and collection membership are kept in the app's local preferences. Collections organize favorites and are not synced. When you choose Keep Offline, Morrow stores the full original image in its sandboxed Application Support folder so previews and applying continue to work without a connection. Removing the offline copy deletes that local file; removing a favorite does not remove an offline copy. Wallpaper files you download are saved where you choose. When you apply a wallpaper, Morrow keeps a copy in `~/Pictures/Morrow Wallpapers` so it remains available locally.

Morrow does not upload your favorites, collections, or local wallpaper files.

## Older versions

This release uses separate local storage for Wikimedia Commons favorites. Favorites saved by earlier Unsplash-based versions are left untouched in their previous local storage key, but are not imported into the Commons catalog. An Unsplash key previously saved in macOS Keychain is neither read nor deleted by this release. You can remove that old item yourself in Keychain Access if you no longer need it.

## Content and licensing

Morrow searches Wikimedia Commons for files tagged CC0 and verifies that the API's per-file license metadata identifies CC0 before showing an image. Commons metadata is community-maintained and is not a legal guarantee about a particular file. The app links each image to its Commons file page and displays its license and creator details when available.

This privacy notice is included with the source code. It is not currently hosted as a public webpage.
