import Foundation

struct WallhavenService {
    static let shared = WallhavenService()

    private static let baseURL = "https://wallhaven.cc/api/v1/search"
    private static let userAgent = "Morrow/2.1 (https://github.com/viperwraith47)"
    private static let pageSize = 24

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpAdditionalHeaders = ["User-Agent": WallhavenService.userAgent]
        return URLSession(configuration: configuration)
    }()

    func photos(query: String, page: Int) async throws -> WallpaperPhotoPage {
        guard var components = URLComponents(string: Self.baseURL) else {
            throw WallhavenServiceError.invalidResponse
        }

        var queryItems = [
            URLQueryItem(name: "categories", value: "100"), // General only; excludes Anime and People.
            URLQueryItem(name: "purity", value: "100"),
            URLQueryItem(name: "sorting", value: "date_added"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "per_page", value: String(Self.pageSize))
        ]
        let searchText = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: String(searchText.prefix(100))))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw WallhavenServiceError.invalidResponse
        }

        let data = try await requestData(from: url)
        let response: WallhavenAPIResponse
        do {
            response = try JSONDecoder().decode(WallhavenAPIResponse.self, from: data)
        } catch {
            throw WallhavenServiceError.invalidResponse
        }

        let photos = response.data.compactMap(\.wallpaperPhoto)
        let totalPages = max(1, response.meta.lastPage ?? page)
        return WallpaperPhotoPage(photos: photos, totalPages: totalPages)
    }

    private func requestData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .useProtocolCachePolicy

        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WallhavenServiceError.invalidResponse
            }
            if httpResponse.statusCode == 429 {
                throw WallhavenServiceError.rateLimited
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw WallhavenServiceError.requestFailed(statusCode: httpResponse.statusCode)
            }
            return data
        } catch let error as WallhavenServiceError {
            throw error
        } catch is URLError {
            throw WallhavenServiceError.networkUnavailable
        } catch {
            throw WallhavenServiceError.networkUnavailable
        }
    }
}

private struct WallhavenAPIResponse: Decodable {
    let data: [WallhavenWallpaper]
    let meta: WallhavenMetadata
}

private struct WallhavenMetadata: Decodable {
    let lastPage: Int?

    enum CodingKeys: String, CodingKey {
        case lastPage = "last_page"
    }
}

private struct WallhavenWallpaper: Decodable {
    let id: String
    let url: String
    let purity: String?
    let dimensionX: Int
    let dimensionY: Int
    let fileSize: Int64?
    let createdAt: String?
    let source: String?
    let path: String
    let thumbs: WallhavenThumbnails?

    enum CodingKeys: String, CodingKey {
        case id, url, purity, path, thumbs, source
        case dimensionX = "dimension_x"
        case dimensionY = "dimension_y"
        case fileSize = "file_size"
        case createdAt = "created_at"
    }

    var wallpaperPhoto: WallpaperPhoto? {
        guard purity?.lowercased() == "sfw",
              dimensionX > 0,
              dimensionY > 0,
              let pageURL = secureURL(url),
              let originalURL = secureURL(path) else {
            return nil
        }

        let thumbnailURL = secureURL(thumbs?.small)
            ?? secureURL(thumbs?.large)
            ?? originalURL
        let cleanSource = source?.trimmingCharacters(in: .whitespacesAndNewlines)

        return WallpaperPhoto(
            id: "wallhaven-\(id)",
            title: "Wallhaven wallpaper \(id)",
            width: dimensionX,
            height: dimensionY,
            thumbnailAddress: thumbnailURL.absoluteString,
            originalAddress: originalURL.absoluteString,
            sourceAddress: pageURL.absoluteString,
            creator: nil,
            sourceCredit: cleanSource.flatMap { $0.isEmpty ? nil : $0 },
            licenseName: "Rights remain with the original owners",
            licenseAddress: nil,
            provider: .wallhaven,
            sourceWidth: dimensionX,
            sourceHeight: dimensionY,
            sourceFileSizeBytes: fileSize,
            uploadTimestamp: createdAt.flatMap(Self.parseUploadTimestamp)
        )
    }

    private func secureURL(_ value: String?) -> URL? {
        guard let url = value.flatMap(URL.init(string:)),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        return url
    }

    private static func parseUploadTimestamp(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}

private struct WallhavenThumbnails: Decodable {
    let large: String?
    let original: String?
    let small: String?
}

enum WallhavenServiceError: LocalizedError {
    case rateLimited
    case requestFailed(statusCode: Int)
    case invalidResponse
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            "Wallhaven is rate-limiting requests. Its current limit is 45 requests per minute; wait a moment before trying again."
        case .requestFailed(let statusCode):
            "Wallhaven returned HTTP \(statusCode). Please try again later."
        case .invalidResponse:
            "Wallhaven returned an unexpected response. Please try again."
        case .networkUnavailable:
            "Morrow could not reach Wallhaven. Check your internet connection and try again."
        }
    }
}
