# Offline Wallpapers and Collections Design

## Intent

Let Morrow users deliberately keep selected wallpaper files on their Mac for reliable offline previews and applying, and organize saved favorites into named groups for manual browsing and applying.

## Goals

- Add an explicit, reversible Keep Offline action for a wallpaper. Save the full original image so previewing and applying can work without a network connection.
- Use the app’s Application Support directory for offline assets rather than the user’s Pictures folder. The existing Pictures copy made when applying remains unchanged.
- Load local offline images before attempting network thumbnails, and use the local original for wallpaper application when present.
- Make offline items independently discoverable and removable. Turning off Keep Offline deletes the local copy; removing a favorite alone does not silently delete an explicitly kept offline file.
- Add user-created named collections of favorites. An image may appear in multiple collections. Removing a favorite removes it from collections but does not remove an independent offline copy. Deleting a collection leaves favorites and offline assets intact.
- Allow manual browsing and applying from a collection. Scheduled rotation is explicitly out of scope.
- Persist collection membership and offline metadata locally, preserving existing favorite data and avoiding cloud sync.

## Non-goals

- Automatic rotation, schedules, launch-at-login behavior, or a system-wide wallpaper service.
- Cloud synchronization, importing legacy Unsplash favorites, or replacing the existing user-selected download flow.
- A fixed storage quota. Users choose which originals to keep and can remove them from the Offline section.

## Approaches considered

1. **Keep full original files locally (selected).** Store originals in Morrow’s Application Support directory and keep searchable metadata locally. This uses more disk but enables complete offline previews and applying at full quality.
2. **Keep preview-sized images only.** Smaller footprint, but applying the wallpaper still requires downloading the original. This does not fully meet the offline workflow requested.
3. **Rely on URLSession’s cache.** Little implementation work, but the cache is best-effort and can be evicted, so it cannot guarantee availability.

## Design

- Add a Keep Offline control to the photo detail view and tile context menu, with clear downloading, available-offline, and removing states. Store each original atomically in an `Offline` subdirectory of `FileManager`’s Application Support directory (inside the app sandbox container). Persist a local catalog of the corresponding `WikimediaPhoto` metadata and IDs separately from favorites. Verify catalog entries against files at launch and recover from missing or incomplete files without losing favorite metadata.
- Add an Offline sidebar destination that shows locally retained wallpapers, counts them, and permits explicit removal. Local images take precedence in tiles and detail previews; if no local original exists, continue using the Commons thumbnail. Applying an offline photo reads its local original, then writes the same persistent copy to Pictures as today.
- Add a Collections sidebar section with create, rename, browse, and delete operations. Store collection IDs, names, and ordered favorite photo IDs locally. Add an action to place or remove a saved photo in a collection. Collection browsing reuses the existing grid and detail actions; applying remains a manual action.
- Keep source license, creator, and Commons links in the saved metadata so offline detail views retain provenance. Keep all existing favorite and wallpaper files compatible and untouched unless the user explicitly removes an offline asset.
- Update the README to explain local offline storage, collections, removal behavior, and that neither feature syncs to the cloud.

## Constraints and assumptions

- This is a native SwiftUI macOS app targeting macOS 14+, with no test target currently present and no third-party dependencies.
- Offline copies are full original files and may use substantial disk space; the user controls each copy explicitly and can remove it at any time.
- Collections contain favorites only and are stored in creation order; photos within a collection retain the order in which they were added.
- The implementation must distinguish removing a favorite from removing an offline asset to avoid unexpected data loss.
- Verify with a Release build and a manual workflow check for saving/removing offline images, browsing/applying without network, collection CRUD/membership, persistence across relaunch, and offline retention after unfavoriting.
