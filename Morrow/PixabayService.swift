import AppKit
import Combine
import CryptoKit
import Foundation
import Security

@MainActor
final class PixabayAPIKeyStore: ObservableObject {
    static let shared = PixabayAPIKeyStore()

    @Published private(set) var hasKeychainKey = false

    private let service = Bundle.main.bundleIdentifier ?? "com.stillroom.wallpapers"
    private let account = "PixabayAPIKey"

    private init() {
        refreshState()
    }

    var apiKey: String? {
        if let keychainKey = keychainAPIKey() {
            return keychainKey
        }
        return debugAPIKey
    }

    var isUsingDebugKey: Bool {
        !hasKeychainKey && debugAPIKey != nil
    }

    func saveAPIKey(_ rawValue: String) throws {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw PixabayAPIKeyStoreError.emptyKey }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw PixabayAPIKeyStoreError.keychainFailure(addStatus)
            }
        } else if status != errSecSuccess {
            throw PixabayAPIKeyStoreError.keychainFailure(status)
        }
        refreshState()
    }

    func removeAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PixabayAPIKeyStoreError.keychainFailure(status)
        }
        refreshState()
    }

    private func refreshState() {
        hasKeychainKey = keychainAPIKey() != nil
    }

    private func keychainAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private var debugAPIKey: String? {
        #if DEBUG
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PIXABAY_DEBUG_API_KEY") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "YOUR_PIXABAY_API_KEY_GOES_HERE" ? nil : trimmed
        #else
        return nil
        #endif
    }
}

enum PixabayAPIKeyStoreError: LocalizedError {
    case emptyKey
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            "Enter a Pixabay API key before saving it."
        case .keychainFailure(let status):
            "Morrow could not update the Pixabay key in Keychain (error \(status))."
        }
    }
}

struct PixabayService {
    static let shared = PixabayService()

    private static let baseURL = "https://pixabay.com/api/"
    private static let userAgent = "Morrow/2.1 (https://github.com/viperwraith47)"
    private static let pageSize = 24
    private static let responseCacheLifetime: TimeInterval = 24 * 60 * 60

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    func photos(
        query: String,
        page: Int,
        orientation: WallpaperOrientation,
        apiKey: String
    ) async throws -> WallpaperPhotoPage {
        guard var components = URLComponents(string: Self.baseURL) else {
            throw PixabayServiceError.invalidResponse
        }
        let searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = searchText.isEmpty ? "wallpaper" : String(searchText.prefix(100))
        let requestedPage = max(1, page)
        let apiOrientation: String
        switch orientation {
        case .all: apiOrientation = "all"
        case .portrait: apiOrientation = "vertical"
        case .landscape: apiOrientation = "horizontal"
        }
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: normalizedQuery),
            URLQueryItem(name: "image_type", value: "photo"),
            URLQueryItem(name: "orientation", value: apiOrientation),
            URLQueryItem(name: "safesearch", value: "true"),
            URLQueryItem(name: "page", value: String(requestedPage)),
            URLQueryItem(name: "per_page", value: String(Self.pageSize))
        ]
        guard let url = components.url else {
            throw PixabayServiceError.invalidResponse
        }

        let cached = cachedResponse(for: url)
        let data: Data
        if let cached {
            data = cached
        } else {
            data = try await requestData(from: url, apiKey: apiKey)
        }

        let response: PixabayAPIResponse
        do {
            response = try JSONDecoder().decode(PixabayAPIResponse.self, from: data)
        } catch {
            throw PixabayServiceError.invalidResponse
        }
        if cached == nil {
            cacheResponse(data, for: url)
        }
        let photos = response.hits.compactMap(\.wallpaperPhoto)
        let totalPages = (response.totalHits + Self.pageSize - 1) / Self.pageSize
        return WallpaperPhotoPage(photos: photos, totalPages: totalPages)
    }

    private func requestData(from url: URL, apiKey: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PixabayServiceError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    let reset = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Int.init)
                    throw PixabayServiceError.rateLimited(waitSeconds: reset)
                }
                let responseText = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let safeMessage = responseText
                    .replacingOccurrences(of: apiKey, with: "[redacted]")
                    .prefix(240)
                throw PixabayServiceError.requestFailed(
                    statusCode: httpResponse.statusCode,
                    message: String(safeMessage)
                )
            }
            return data
        } catch let error as PixabayServiceError {
            throw error
        } catch is URLError {
            throw PixabayServiceError.networkUnavailable
        } catch {
            throw PixabayServiceError.networkUnavailable
        }
    }

    private func cachedResponse(for url: URL) -> Data? {
        guard let cacheURL = responseCacheURL(for: url),
              let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(PixabayCachedResponse.self, from: data) else {
            return nil
        }
        guard Date().timeIntervalSince(cached.storedAt) < Self.responseCacheLifetime else {
            try? FileManager.default.removeItem(at: cacheURL)
            return nil
        }
        return cached.data
    }

    private func cacheResponse(_ data: Data, for url: URL) {
        guard let cacheURL = responseCacheURL(for: url) else { return }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let cached = PixabayCachedResponse(storedAt: Date(), data: data)
            try JSONEncoder().encode(cached).write(to: cacheURL, options: .atomic)
        } catch {
            // A cache write failure should not prevent a successful search result from being shown.
        }
    }

    private func responseCacheURL(for url: URL) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cachesDirectory
            .appendingPathComponent("Morrow", isDirectory: true)
            .appendingPathComponent("PixabayAPI", isDirectory: true)
            .appendingPathComponent("\(digest).json")
    }
}

private struct PixabayCachedResponse: Codable {
    let storedAt: Date
    let data: Data
}

private struct PixabayAPIResponse: Decodable {
    let totalHits: Int
    let hits: [PixabayPhoto]
}

private struct PixabayPhoto: Decodable {
    let id: Int
    let pageURL: String?
    let tags: String?
    let previewURL: String?
    let previewWidth: Int?
    let previewHeight: Int?
    let webformatURL: String?
    let webformatWidth: Int?
    let webformatHeight: Int?
    let largeImageURL: String?
    let fullHDURL: String?
    let imageURL: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let imageSize: Int64?
    let user: String?

    enum CodingKeys: String, CodingKey {
        case id, tags, user
        case pageURL = "pageURL"
        case previewURL = "previewURL"
        case previewWidth = "previewWidth"
        case previewHeight = "previewHeight"
        case webformatURL = "webformatURL"
        case webformatWidth = "webformatWidth"
        case webformatHeight = "webformatHeight"
        case largeImageURL = "largeImageURL"
        case fullHDURL = "fullHDURL"
        case imageURL = "imageURL"
        case imageWidth = "imageWidth"
        case imageHeight = "imageHeight"
        case imageSize = "imageSize"
    }

    var wallpaperPhoto: WallpaperPhoto? {
        guard let pageURL = secureURL(pageURL),
              let webformatURL = secureURL(webformatURL) else {
            return nil
        }

        let sourceDimensions: (width: Int, height: Int)?
        if let imageWidth, let imageHeight, imageWidth > 0, imageHeight > 0 {
            sourceDimensions = (imageWidth, imageHeight)
        } else {
            sourceDimensions = nil
        }
        let webformatDimensions = (
            width: webformatWidth ?? previewWidth ?? 0,
            height: webformatHeight ?? previewHeight ?? 0
        )

        let webformatDimensionsAreExact = (webformatWidth ?? 0) > 0 && (webformatHeight ?? 0) > 0
        let availableImage: (url: URL, width: Int, height: Int, dimensionsAreExact: Bool)
        if let imageURL = secureURL(imageURL) {
            let dimensions = sourceDimensions ?? webformatDimensions
            availableImage = (imageURL, dimensions.width, dimensions.height, sourceDimensions != nil)
        } else if let fullHDURL = secureURL(fullHDURL) {
            let dimensions = sourceDimensions.map { scaledDimensions(for: $0, maximumDimension: 1920) }
                ?? webformatDimensions
            availableImage = (fullHDURL, dimensions.width, dimensions.height, sourceDimensions != nil)
        } else if let largeImageURL = secureURL(largeImageURL) {
            let dimensions = sourceDimensions.map { scaledDimensions(for: $0, maximumDimension: 1280) }
                ?? webformatDimensions
            availableImage = (largeImageURL, dimensions.width, dimensions.height, sourceDimensions != nil)
        } else {
            availableImage = (
                webformatURL,
                webformatDimensions.width,
                webformatDimensions.height,
                webformatDimensionsAreExact
            )
        }

        let title = tags?
            .components(separatedBy: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        let displayTitle = title.flatMap { $0.isEmpty ? nil : $0 } ?? "Pixabay wallpaper \(id)"
        return WallpaperPhoto(
            id: "pixabay-\(id)",
            title: displayTitle,
            width: availableImage.width,
            height: availableImage.height,
            thumbnailAddress: webformatURL.absoluteString,
            originalAddress: availableImage.url.absoluteString,
            sourceAddress: pageURL.absoluteString,
            creator: user?.isEmpty == false ? user : nil,
            sourceCredit: nil,
            licenseName: "Pixabay Content License",
            licenseAddress: "https://pixabay.com/service/license-summary/",
            provider: .pixabay,
            sourceWidth: sourceDimensions?.width,
            sourceHeight: sourceDimensions?.height,
            sourceFileSizeBytes: imageSize,
            availableDimensionsAreExact: availableImage.dimensionsAreExact
        )
    }

    private func scaledDimensions(
        for source: (width: Int, height: Int),
        maximumDimension: Int
    ) -> (width: Int, height: Int) {
        let scale = min(1, Double(maximumDimension) / Double(max(source.width, source.height)))
        return (
            max(1, Int((Double(source.width) * scale).rounded())),
            max(1, Int((Double(source.height) * scale).rounded()))
        )
    }

    private func secureURL(_ value: String?) -> URL? {
        guard let url = value.flatMap(URL.init(string:)),
              url.scheme == "https",
              url.host != nil else {
            return nil
        }
        return url
    }
}

enum WallpaperImageService {
    private static let userAgent = "Morrow/2.1 (https://github.com/viperwraith47)"

    private static let imageCache: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 150 * 1024 * 1024
        return cache
    }()

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            diskPath: "MorrowWallpaperImages"
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: configuration)
    }()

    static func imageData(for photo: WallpaperPhoto) async throws -> Data {
        guard let url = photo.originalURL, url.scheme == "https" else {
            throw WallpaperImageServiceError.imageUnavailable
        }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw WallpaperImageServiceError.imageUnavailable
        }
        return data
    }

    static func image(at url: URL) async -> NSImage? {
        guard url.scheme == "https" else { return nil }
        let cacheKey = url as NSURL
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = NSImage(data: data) else {
            return nil
        }
        imageCache.setObject(image, forKey: cacheKey, cost: data.count)
        return image
    }
}

enum WallpaperImageServiceError: LocalizedError {
    case imageUnavailable

    var errorDescription: String? {
        "The image could not be downloaded. Refresh the search results or try again later."
    }
}

enum PixabayServiceError: LocalizedError {
    case rateLimited(waitSeconds: Int?)
    case requestFailed(statusCode: Int, message: String)
    case invalidResponse
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .rateLimited(let waitSeconds):
            if let waitSeconds, waitSeconds > 0 {
                return "Pixabay is rate-limiting requests. Wait about \(waitSeconds) seconds before trying again. Its default limit is 100 requests per 60 seconds."
            }
            return "Pixabay is rate-limiting requests. Wait for the limit to reset before trying again. Its default limit is 100 requests per 60 seconds."
        case .requestFailed(let statusCode, let message):
            let detail = message.isEmpty ? "Check that the API key is valid and try again." : message
            return "Pixabay returned HTTP \(statusCode): \(detail)"
        case .invalidResponse:
            return "Pixabay returned an unexpected response. Please try again."
        case .networkUnavailable:
            return "Morrow could not reach Pixabay. Check your internet connection and try again."
        }
    }
}
