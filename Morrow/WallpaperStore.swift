import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class WallpaperStore: ObservableObject {
    @Published var selection: SidebarDestination? = .forYou
    @Published var searchText = ""
    @Published var orientation: WallpaperOrientation = .all
    @Published private(set) var photos: [WallpaperPhoto] = []
    @Published private(set) var favorites: [WallpaperPhoto] = []
    @Published private(set) var offlinePhotos: [WallpaperPhoto] = []
    @Published private(set) var collections: [WallpaperCollection] = []
    @Published private(set) var offlineDownloadsInProgress: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isApplyingWallpaper = false
    @Published private(set) var canLoadMore = false
    @Published var alertMessage: String?
    @Published private(set) var discoveryProvider: WallpaperProvider

    private let wallhavenService = WallhavenService.shared
    private let pixabayService = PixabayService.shared
    private let apiKeyStore = PixabayAPIKeyStore.shared
    private let discoveryProviderKey = "wallpaperDiscoveryProvider"
    private let favoritesKey = "savedWikimediaWallpapers"
    private let offlinePhotosKey = "offlineWikimediaWallpapers"
    private let collectionsKey = "wallpaperCollections"
    private var activeQuery = ""
    private var currentPage = 0
    private var totalPages = 1

    init() {
        let defaults = UserDefaults.standard
        if let rawValue = defaults.string(forKey: discoveryProviderKey),
           let savedProvider = WallpaperProvider(rawValue: rawValue),
           WallpaperProvider.discoveryOptions.contains(savedProvider) {
            discoveryProvider = savedProvider
        } else {
            let initialProvider: WallpaperProvider = apiKeyStore.apiKey == nil ? .wallhaven : .pixabay
            discoveryProvider = initialProvider
            defaults.set(initialProvider.rawValue, forKey: discoveryProviderKey)
        }

        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let saved = try? JSONDecoder().decode([WallpaperPhoto].self, from: data) {
            favorites = saved
        }

        if let data = UserDefaults.standard.data(forKey: collectionsKey),
           let saved = try? JSONDecoder().decode([WallpaperCollection].self, from: data) {
            let favoriteIDs = Set(favorites.map(\.id))
            collections = saved.map { collection in
                var collection = collection
                collection.photoIDs = collection.photoIDs.filter { favoriteIDs.contains($0) }
                return collection
            }
            if collections != saved {
                persistCollections()
            }
        }

        loadOfflineCatalog()
    }

    var isLocalLibrarySelection: Bool {
        switch selection {
        case .saved, .offline, .collection(_): true
        default: false
        }
    }

    var requiresPixabayAPIKey: Bool {
        discoveryProvider == .pixabay && apiKeyStore.apiKey == nil
    }

    var displayedPhotos: [WallpaperPhoto] {
        let source: [WallpaperPhoto]
        switch selection {
        case .saved:
            source = favorites
        case .offline:
            source = offlinePhotos.filter { photo in
                guard let url = offlineAssetURL(for: photo) else { return false }
                return FileManager.default.fileExists(atPath: url.path)
            }
        case .collection(let collectionID):
            guard let collection = collections.first(where: { $0.id == collectionID }) else { return [] }
            source = collection.photoIDs.compactMap { photoID in
                favorites.first(where: { $0.id == photoID })
            }
        default:
            source = photos
        }

        guard orientation != .all else { return source }
        return source.filter { photo in
            switch orientation {
            case .all: true
            case .portrait: photo.aspectRatio < 1
            case .landscape: photo.aspectRatio >= 1
            }
        }
    }

    var navigationTitle: String {
        switch selection {
        case .forYou: "Discover"
        case .saved: "Saved Wallpapers"
        case .offline: "Available Offline"
        case .category(let category): category.capitalized
        case .collection(let collectionID): collections.first(where: { $0.id == collectionID })?.name ?? "Collection"
        case nil: "Search Results"
        }
    }

    func bootstrap() async {
        activeQuery = ""
        await fetch(page: 1, appending: false)
    }

    func select(_ destination: SidebarDestination) async {
        switch destination {
        case .forYou:
            activeQuery = ""
            searchText = ""
        case .category(let query):
            activeQuery = query
            searchText = query
        case .saved, .offline, .collection(_):
            activeQuery = ""
            searchText = ""
            return
        }
        await fetch(page: 1, appending: false)
    }

    func submitSearch() async {
        activeQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        selection = nil
        await fetch(page: 1, appending: false)
    }

    func clearSearch() {
        searchText = ""
        activeQuery = ""
        selection = .forYou
    }

    func changeOrientation(to value: WallpaperOrientation) async {
        guard !isLocalLibrarySelection else { return }
        await fetch(page: 1, appending: false)
    }

    func refresh() async {
        guard !isLocalLibrarySelection else { return }
        await fetch(page: 1, appending: false)
    }

    func photoSourceDidChange() async {
        guard !isLocalLibrarySelection else { return }
        await fetch(page: 1, appending: false)
    }

    func selectDiscoveryProvider(_ provider: WallpaperProvider) async {
        guard WallpaperProvider.discoveryOptions.contains(provider),
              provider != discoveryProvider,
              !isLoading else {
            return
        }
        discoveryProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: discoveryProviderKey)
        alertMessage = nil
        guard !isLocalLibrarySelection else { return }
        await fetch(page: 1, appending: false)
    }

    func loadMore() async {
        guard canLoadMore, !isLoading, !isLocalLibrarySelection else { return }
        await fetch(page: currentPage + 1, appending: true)
    }

    func isSaved(_ photo: WallpaperPhoto) -> Bool {
        favorites.contains(where: { $0.id == photo.id })
    }

    func toggleSaved(_ photo: WallpaperPhoto) {
        if isSaved(photo) {
            favorites.removeAll { $0.id == photo.id }
            for index in collections.indices {
                collections[index].photoIDs.removeAll { $0 == photo.id }
            }
            persistCollections()
        } else {
            favorites.insert(photo, at: 0)
        }
        persistFavorites()
    }

    func createCollection(named rawName: String) -> WallpaperCollection? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            alertMessage = "Enter a name for this collection."
            return nil
        }
        guard !collections.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            alertMessage = "A collection with that name already exists."
            return nil
        }
        let collection = WallpaperCollection(name: name)
        collections.append(collection)
        persistCollections()
        return collection
    }

    func renameCollection(_ id: UUID, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            alertMessage = "Enter a name for this collection."
            return
        }
        guard !collections.contains(where: {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) else {
            alertMessage = "A collection with that name already exists."
            return
        }
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].name = name
        persistCollections()
    }

    func deleteCollection(_ id: UUID) {
        collections.removeAll { $0.id == id }
        persistCollections()
        if case .collection(let selectedID) = selection, selectedID == id {
            selection = .saved
        }
    }

    func isInCollection(_ photo: WallpaperPhoto, collectionID: UUID) -> Bool {
        collections.first(where: { $0.id == collectionID })?.photoIDs.contains(photo.id) ?? false
    }

    func toggleCollectionMembership(_ photo: WallpaperPhoto, collectionID: UUID) {
        guard isSaved(photo), let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        if collections[index].photoIDs.contains(photo.id) {
            collections[index].photoIDs.removeAll { $0 == photo.id }
        } else {
            collections[index].photoIDs.append(photo.id)
        }
        persistCollections()
    }

    func offlineURL(for photo: WallpaperPhoto) -> URL? {
        guard offlinePhotos.contains(where: { $0.id == photo.id }),
              let url = offlineAssetURL(for: photo),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    func isOffline(_ photo: WallpaperPhoto) -> Bool {
        offlineURL(for: photo) != nil
    }

    func isKeepingOffline(_ photo: WallpaperPhoto) -> Bool {
        offlineDownloadsInProgress.contains(photo.id)
    }

    func toggleOffline(_ photo: WallpaperPhoto) async {
        if isOffline(photo) {
            removeOffline(photo)
        } else {
            await keepOffline(photo)
        }
    }

    func keepOffline(_ photo: WallpaperPhoto) async {
        guard !isOffline(photo), !offlineDownloadsInProgress.contains(photo.id) else { return }
        guard let destination = offlineAssetURL(for: photo) else {
            alertMessage = "Could not locate Morrow’s Application Support folder."
            return
        }

        offlineDownloadsInProgress.insert(photo.id)
        defer { offlineDownloadsInProgress.remove(photo.id) }

        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try await WallpaperImageService.imageData(for: photo)
            guard NSImage(data: data) != nil else {
                alertMessage = "The downloaded file is not a readable image and was not kept offline."
                return
            }
            try data.write(to: destination, options: .atomic)
            offlinePhotos.removeAll { $0.id == photo.id }
            offlinePhotos.insert(photo, at: 0)
            persistOfflineCatalog()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func removeOffline(_ photo: WallpaperPhoto) {
        if let url = offlineAssetURL(for: photo), FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                alertMessage = "Could not remove the offline copy: \(error.localizedDescription)"
                return
            }
        }
        offlinePhotos.removeAll { $0.id == photo.id }
        persistOfflineCatalog()
    }

    func dismissAlert() {
        alertMessage = nil
    }

    func applyAsWallpaper(_ photo: WallpaperPhoto) async {
        guard !isApplyingWallpaper, !isDownloading else { return }

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            alertMessage = "No displays are available to set a wallpaper on."
            return
        }
        guard let picturesDirectory = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            alertMessage = "Could not locate your Pictures folder."
            return
        }

        isApplyingWallpaper = true
        defer { isApplyingWallpaper = false }
        do {
            let image = try await imageData(for: photo)
            let wallpaperDirectory = picturesDirectory.appendingPathComponent("Morrow Wallpapers", isDirectory: true)
            try FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
            let wallpaperURL = wallpaperDirectory.appendingPathComponent("Morrow-\(photo.id).\(photo.fileExtension)")
            try image.write(to: wallpaperURL, options: .atomic)

            let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                .allowClipping: true
            ]
            for screen in screens {
                try NSWorkspace.shared.setDesktopImageURL(wallpaperURL, for: screen, options: options)
            }
            alertMessage = "Wallpaper applied to all displays. A copy is saved in Pictures/Morrow Wallpapers."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func download(_ photo: WallpaperPhoto) async {
        guard !isDownloading, !isApplyingWallpaper else { return }

        let panel = NSSavePanel()
        panel.title = "Save Wallpaper"
        panel.allowedContentTypes = [UTType(filenameExtension: photo.fileExtension) ?? .image]
        panel.canCreateDirectories = true
        let safeTitle = photo.title
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        panel.nameFieldStringValue = "Morrow-\(safeTitle.isEmpty ? photo.id : safeTitle).\(photo.fileExtension)"
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        isDownloading = true
        defer { isDownloading = false }
        do {
            let image = try await imageData(for: photo)
            try image.write(to: destination, options: .atomic)
            alertMessage = "Saved \(destination.lastPathComponent)."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func imageData(for photo: WallpaperPhoto) async throws -> Data {
        if let url = offlineURL(for: photo),
           let data = try? Data(contentsOf: url),
           NSImage(data: data) != nil {
            return data
        }
        return try await WallpaperImageService.imageData(for: photo)
    }

    private func offlineAssetURL(for photo: WallpaperPhoto) -> URL? {
        let safeIdentifier = photo.id.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "",
            options: .regularExpression
        )
        guard !safeIdentifier.isEmpty,
              let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = applicationSupport
            .appendingPathComponent("Morrow", isDirectory: true)
            .appendingPathComponent("Offline", isDirectory: true)
        return directory.appendingPathComponent("\(safeIdentifier).\(photo.fileExtension)")
    }

    private func loadOfflineCatalog() {
        guard let data = UserDefaults.standard.data(forKey: offlinePhotosKey),
              let saved = try? JSONDecoder().decode([WallpaperPhoto].self, from: data) else {
            return
        }
        offlinePhotos = saved.filter { photo in
            guard let url = offlineAssetURL(for: photo) else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
        if offlinePhotos != saved {
            persistOfflineCatalog()
        }
    }

    private func persistFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: favoritesKey)
    }

    private func persistOfflineCatalog() {
        guard let data = try? JSONEncoder().encode(offlinePhotos) else { return }
        UserDefaults.standard.set(data, forKey: offlinePhotosKey)
    }

    private func persistCollections() {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        UserDefaults.standard.set(data, forKey: collectionsKey)
    }

    private func fetch(page: Int, appending: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if !appending {
            photos = []
            canLoadMore = false
            currentPage = 0
        }

        if requiresPixabayAPIKey {
            photos = []
            canLoadMore = false
            currentPage = 0
            totalPages = 1
            return
        }

        guard discoveryProvider != .wikimediaCommons else {
            alertMessage = "Wikimedia Commons is available for saved wallpapers only. Choose Wallhaven or Pixabay in Photo Source Settings."
            return
        }

        var requestedPage = page
        var emptyPageCount = 0
        do {
            while true {
                let previousPhotoCount = photos.count
                let result: WallpaperPhotoPage
                switch discoveryProvider {
                case .wallhaven:
                    result = try await wallhavenService.photos(query: activeQuery, page: requestedPage)
                case .pixabay:
                    guard let apiKey = apiKeyStore.apiKey else {
                        photos = []
                        canLoadMore = false
                        currentPage = 0
                        totalPages = 1
                        return
                    }
                    result = try await pixabayService.photos(
                        query: activeQuery,
                        page: requestedPage,
                        orientation: orientation,
                        apiKey: apiKey
                    )
                case .wikimediaCommons:
                    alertMessage = "Wikimedia Commons is available for saved wallpapers only. Choose Wallhaven or Pixabay in Photo Source Settings."
                    return
                }
                let matchingPhotos = result.photos.filter { photo in
                    switch orientation {
                    case .all: true
                    case .portrait: photo.aspectRatio < 1
                    case .landscape: photo.aspectRatio >= 1
                    }
                }

                if appending || requestedPage > page {
                    let existingIDs = Set(photos.map(\.id))
                    photos.append(contentsOf: matchingPhotos.filter { !existingIDs.contains($0.id) })
                } else {
                    photos = matchingPhotos
                }

                currentPage = requestedPage
                totalPages = result.totalPages
                canLoadMore = currentPage < totalPages
                if photos.count > previousPhotoCount || !canLoadMore || emptyPageCount >= 3 {
                    break
                }
                requestedPage += 1
                emptyPageCount += 1
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
