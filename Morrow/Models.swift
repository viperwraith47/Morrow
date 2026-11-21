import Foundation

enum WallpaperProvider: String, Codable, CaseIterable, Hashable, Identifiable {
    case wikimediaCommons
    case pixabay
    case wallhaven

    static let discoveryOptions: [Self] = [.wallhaven, .pixabay]

    var id: Self { self }

    var displayName: String {
        switch self {
        case .wikimediaCommons: "Wikimedia Commons"
        case .pixabay: "Pixabay"
        case .wallhaven: "Wallhaven"
        }
    }

    var shortName: String {
        displayName
    }

    var licenseNotice: String {
        switch self {
        case .wikimediaCommons:
            "CC0 files are freely reusable; creator and source details are shown as a courtesy."
        case .pixabay:
            "Pixabay content is provided under the Pixabay Content License. Review the source page and license terms before use."
        case .wallhaven:
            "Wallhaven images remain the property of their respective owners. Review the linked source page for rights and usage information."
        }
    }
}

struct WallpaperPhoto: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let width: Int
    let height: Int
    let availableDimensionsAreExact: Bool
    let sourceWidth: Int?
    let sourceHeight: Int?
    let sourceFileSizeBytes: Int64?
    let uploadTimestamp: Date?
    let thumbnailAddress: String
    let originalAddress: String
    let sourceAddress: String
    let creator: String?
    let sourceCredit: String?
    let licenseName: String
    let licenseAddress: String?
    let provider: WallpaperProvider

    init(
        id: String,
        title: String,
        width: Int,
        height: Int,
        thumbnailAddress: String,
        originalAddress: String,
        sourceAddress: String,
        creator: String?,
        sourceCredit: String?,
        licenseName: String,
        licenseAddress: String?,
        provider: WallpaperProvider,
        sourceWidth: Int? = nil,
        sourceHeight: Int? = nil,
        sourceFileSizeBytes: Int64? = nil,
        uploadTimestamp: Date? = nil,
        availableDimensionsAreExact: Bool = true
    ) {
        self.id = id
        self.title = title
        self.width = width
        self.height = height
        self.availableDimensionsAreExact = availableDimensionsAreExact
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.sourceFileSizeBytes = sourceFileSizeBytes
        self.uploadTimestamp = uploadTimestamp
        self.thumbnailAddress = thumbnailAddress
        self.originalAddress = originalAddress
        self.sourceAddress = sourceAddress
        self.creator = creator
        self.sourceCredit = sourceCredit
        self.licenseName = licenseName
        self.licenseAddress = licenseAddress
        self.provider = provider
    }

    var thumbnailURL: URL? { URL(string: thumbnailAddress) }
    var originalURL: URL? { URL(string: originalAddress) }
    var sourceURL: URL? { URL(string: sourceAddress) }
    var licenseURL: URL? { licenseAddress.flatMap(URL.init(string:)) }

    var aspectRatio: CGFloat {
        guard height > 0 else { return 1.45 }
        return CGFloat(width) / CGFloat(height)
    }

    var availableDimensionsText: String? {
        guard availableDimensionsAreExact, width > 0, height > 0 else { return nil }
        return "\(width.formatted()) × \(height.formatted()) px"
    }

    var originalDimensionsText: String? {
        guard let sourceWidth, let sourceHeight,
              sourceWidth > 0, sourceHeight > 0,
              !availableDimensionsAreExact || sourceWidth != width || sourceHeight != height else {
            return nil
        }
        return "\(sourceWidth.formatted()) × \(sourceHeight.formatted()) px"
    }

    var qualityLabel: String {
        guard availableDimensionsAreExact, width > 0, height > 0 else { return "Resolution unavailable" }
        let longSide = max(width, height)
        let shortSide = min(width, height)
        if longSide >= 3840, shortSide >= 2160 { return "4K" }
        if longSide >= 1920, shortSide >= 1080 { return "Full HD" }
        if longSide >= 1280, shortSide >= 720 { return "HD" }
        return "Standard"
    }

    var sourceFileSizeText: String? {
        guard let sourceFileSizeBytes, sourceFileSizeBytes > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sourceFileSizeBytes)
    }

    var creditName: String {
        if provider == .wallhaven { return "Uploader not listed" }
        return creator ?? "Creator not identified"
    }

    var fileExtension: String {
        let value = originalURL?.pathExtension.lowercased() ?? ""
        return value.range(of: #"^[a-z0-9]{1,8}$"#, options: .regularExpression) != nil ? value : "jpg"
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, width, height, availableDimensionsAreExact
        case sourceWidth, sourceHeight, sourceFileSizeBytes, uploadTimestamp
        case thumbnailAddress, originalAddress, sourceAddress, creator, sourceCredit
        case licenseName, licenseAddress, provider
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        width = try values.decode(Int.self, forKey: .width)
        height = try values.decode(Int.self, forKey: .height)
        provider = try values.decodeIfPresent(WallpaperProvider.self, forKey: .provider) ?? .wikimediaCommons
        availableDimensionsAreExact = try values.decodeIfPresent(Bool.self, forKey: .availableDimensionsAreExact)
            ?? (provider == .wikimediaCommons)
        sourceWidth = try values.decodeIfPresent(Int.self, forKey: .sourceWidth)
        sourceHeight = try values.decodeIfPresent(Int.self, forKey: .sourceHeight)
        sourceFileSizeBytes = try values.decodeIfPresent(Int64.self, forKey: .sourceFileSizeBytes)
        uploadTimestamp = try values.decodeIfPresent(Date.self, forKey: .uploadTimestamp)
        thumbnailAddress = try values.decode(String.self, forKey: .thumbnailAddress)
        originalAddress = try values.decode(String.self, forKey: .originalAddress)
        sourceAddress = try values.decode(String.self, forKey: .sourceAddress)
        creator = try values.decodeIfPresent(String.self, forKey: .creator)
        sourceCredit = try values.decodeIfPresent(String.self, forKey: .sourceCredit)
        licenseName = try values.decode(String.self, forKey: .licenseName)
        licenseAddress = try values.decodeIfPresent(String.self, forKey: .licenseAddress)
    }
}

struct WallpaperPhotoPage {
    let photos: [WallpaperPhoto]
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
