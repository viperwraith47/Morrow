import Foundation

struct WikimediaPhoto: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let width: Int
    let height: Int
    let thumbnailAddress: String
    let originalAddress: String
    let sourceAddress: String
    let creator: String?
    let sourceCredit: String?
    let licenseName: String
    let licenseAddress: String?

    var thumbnailURL: URL? { URL(string: thumbnailAddress) }
    var originalURL: URL? { URL(string: originalAddress) }
    var sourceURL: URL? { URL(string: sourceAddress) }
    var licenseURL: URL? { licenseAddress.flatMap(URL.init(string:)) }

    var aspectRatio: CGFloat {
        guard height > 0 else { return 1.45 }
        return CGFloat(width) / CGFloat(height)
    }

    var creditName: String {
        creator ?? "Creator not identified"
    }

    var fileExtension: String {
        let value = originalURL?.pathExtension.lowercased() ?? ""
        return value.range(of: #"^[a-z0-9]{1,8}$"#, options: .regularExpression) != nil ? value : "jpg"
    }
}

struct WikimediaPhotoPage {
    let photos: [WikimediaPhoto]
    let totalPages: Int
}

struct WallpaperCollection: Codable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var photoIDs: [String]

    init(id: UUID = UUID(), name: String, photoIDs: [String] = []) {
        self.id = id
        self.name = name
        self.photoIDs = photoIDs
    }
}

enum SidebarDestination: Hashable {
    case forYou
    case category(String)
    case saved
    case offline
    case collection(UUID)
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
