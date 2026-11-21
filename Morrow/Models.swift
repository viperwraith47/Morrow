import Foundation

struct UnsplashPhoto: Codable, Hashable, Identifiable {
    let id: String
    let width: Int?
    let height: Int?
    let color: String?
    let description: String?
    let altDescription: String?
    let urls: PhotoURLs
    let links: PhotoLinks?
    let user: Photographer?

    enum CodingKeys: String, CodingKey {
        case id, width, height, color, description, urls, links, user
        case altDescription = "alt_description"
    }

    var title: String {
        let value = altDescription ?? description ?? "Unsplash wallpaper"
        return value.isEmpty ? "Unsplash wallpaper" : value
    }

    var aspectRatio: CGFloat {
        guard let width, let height, height > 0 else { return 1.45 }
        return CGFloat(width) / CGFloat(height)
    }

    var creditName: String {
        user?.name ?? user?.username ?? "Unsplash photographer"
    }
}

struct PhotoURLs: Codable, Hashable {
    let full: String?
    let regular: String?
    let small: String?
    let thumb: String?

    var fullURL: URL? { full.flatMap(URL.init(string:)) }
    var regularURL: URL? { regular.flatMap(URL.init(string:)) }
    var smallURL: URL? { small.flatMap(URL.init(string:)) }
}

struct PhotoLinks: Codable, Hashable {
    let html: String?
    let downloadLocation: String?

    enum CodingKeys: String, CodingKey {
        case html
        case downloadLocation = "download_location"
    }
}

struct Photographer: Codable, Hashable {
    let name: String?
    let username: String?
    let links: PhotographerLinks?
}

struct PhotographerLinks: Codable, Hashable {
    let html: String?
}

struct UnsplashPhotoPage {
    let photos: [UnsplashPhoto]
    let totalPages: Int
}

enum SidebarDestination: Hashable {
    case forYou
    case category(String)
    case saved
}

enum WallpaperOrientation: String, CaseIterable, Identifiable {
    case all
    case portrait
    case landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .portrait: "Portrait"
        case .landscape: "Landscape"
        }
    }
}
