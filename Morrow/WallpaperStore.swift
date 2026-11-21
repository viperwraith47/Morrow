import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class WallpaperStore: ObservableObject {
    @Published var selection: SidebarDestination? = .forYou
    @Published var searchText = ""
    @Published var orientation: WallpaperOrientation = .all
    @Published private(set) var photos: [UnsplashPhoto] = []
    @Published private(set) var favorites: [UnsplashPhoto] = []
    @Published private(set) var isConnected = false
    @Published private(set) var isLoading = false
    @Published private(set) var isValidatingKey = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isApplyingWallpaper = false
    @Published private(set) var canLoadMore = false
    @Published var connectionMessage: String?
    @Published var alertMessage: String?

    private let service = UnsplashService()
    private let favoritesKey = "savedUnsplashWallpapers"
    private var accessKey: String?
    private var activeQuery = ""
    private var currentPage = 0
    private var totalPages = 1

    init() {
        accessKey = KeychainStore.read()
        isConnected = accessKey != nil
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let saved = try? JSONDecoder().decode([UnsplashPhoto].self, from: data) {
            favorites = saved
        }
    }

    var displayedPhotos: [UnsplashPhoto] {
        guard selection == .saved, orientation != .all else {
            return selection == .saved ? favorites : photos
        }
        return favorites.filter { photo in
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
        case .category(let category): category.capitalized
        case nil: "Search Results"
        }
    }

    func bootstrap() async {
        guard isConnected else { return }
        activeQuery = ""
        await fetch(page: 1, appending: false)
    }

    func select(_ destination: SidebarDestination) async {
        connectionMessage = nil
        switch destination {
        case .forYou:
            activeQuery = ""
            searchText = ""
        case .category(let query):
            activeQuery = query
            searchText = query
        case .saved:
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
        guard selection != .saved else { return }
        await fetch(page: 1, appending: false)
    }

    func refresh() async {
        guard selection != .saved else { return }
        await fetch(page: 1, appending: false)
    }

    func loadMore() async {
        guard canLoadMore, !isLoading else { return }
        await fetch(page: currentPage + 1, appending: true)
    }

    func isSaved(_ photo: UnsplashPhoto) -> Bool {
        favorites.contains(where: { $0.id == photo.id })
    }

    func toggleSaved(_ photo: UnsplashPhoto) {
        if isSaved(photo) {
            favorites.removeAll { $0.id == photo.id }
        } else {
            favorites.insert(photo, at: 0)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    func connect(accessKey input: String) async {
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            connectionMessage = "Enter your Unsplash Access Key to continue."
            return
        }
        isValidatingKey = true
        connectionMessage = nil
        defer { isValidatingKey = false }

        do {
            try await service.validate(accessKey: key)
            try KeychainStore.save(key)
            accessKey = key
            isConnected = true
            connectionMessage = "Connected to Unsplash. Your key is stored in macOS Keychain."
            activeQuery = ""
            searchText = ""
            await fetch(page: 1, appending: false)
        } catch {
            connectionMessage = error.localizedDescription
        }
    }

    func removeAccessKey() {
        do {
            try KeychainStore.delete()
            accessKey = nil
            isConnected = false
            photos = []
            canLoadMore = false
            connectionMessage = "Unsplash access key removed from Keychain."
        } catch {
            connectionMessage = error.localizedDescription
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }

    func applyAsWallpaper(_ photo: UnsplashPhoto) async {
        guard let accessKey else {
            alertMessage = "Connect an Unsplash Access Key in Settings before applying wallpapers."
            return
        }
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
            try await service.trackDownload(for: photo, accessKey: accessKey)
            let image = try await service.imageData(for: photo)
            let wallpaperDirectory = picturesDirectory.appendingPathComponent("Morrow Wallpapers", isDirectory: true)
            try FileManager.default.createDirectory(at: wallpaperDirectory, withIntermediateDirectories: true)
            let wallpaperURL = wallpaperDirectory.appendingPathComponent("Morrow-\(photo.id).jpg")
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

    func download(_ photo: UnsplashPhoto) async {
        guard let accessKey else {
            alertMessage = "Connect an Unsplash Access Key in Settings before downloading wallpapers."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Wallpaper"
        panel.allowedContentTypes = [.jpeg]
        panel.canCreateDirectories = true
        let safeTitle = photo.title
            .replacingOccurrences(of: "[^A-Za-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        panel.nameFieldStringValue = "Morrow-\(safeTitle.isEmpty ? "Wallpaper" : safeTitle).jpg"
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        isDownloading = true
        defer { isDownloading = false }
        do {
            try await service.trackDownload(for: photo, accessKey: accessKey)
            let image = try await service.imageData(for: photo)
            try image.write(to: destination, options: .atomic)
            alertMessage = "Saved \(destination.lastPathComponent)."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func fetch(page: Int, appending: Bool) async {
        guard let accessKey else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if !appending {
            photos = []
            canLoadMore = false
            currentPage = 0
        }

        do {
            let result = try await service.photos(
                query: activeQuery,
                orientation: orientation,
                page: page,
                accessKey: accessKey
            )
            if appending {
                let existingIDs = Set(photos.map(\.id))
                photos.append(contentsOf: result.photos.filter { !existingIDs.contains($0.id) })
            } else {
                photos = result.photos
            }
            currentPage = page
            totalPages = result.totalPages
            canLoadMore = currentPage < totalPages
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
