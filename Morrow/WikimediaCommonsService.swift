import Foundation

struct WikimediaCommonsService {
    static let shared = WikimediaCommonsService()

    private static let baseURL = "https://commons.wikimedia.org/w/api.php"
    private static let userAgent = "Morrow/1.0 (https://github.com/viperwraith47)"
    private static let pageSize = 24

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            diskPath: "MorrowWikimedia"
        )
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpAdditionalHeaders = ["User-Agent": WikimediaCommonsService.userAgent]
        return URLSession(configuration: configuration)
    }()

    func photos(query: String, page: Int) async throws -> WallpaperPhotoPage {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchTerms = [trimmedQuery, "filetype:bitmap", "incategory:\"CC-Zero\"", "(wallpaper OR background)"]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: searchTerms),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: String(Self.pageSize)),
            URLQueryItem(name: "gsroffset", value: String(max(0, page - 1) * Self.pageSize)),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "timestamp|url|size|extmetadata"),
            URLQueryItem(name: "iiurlwidth", value: "1200"),
            URLQueryItem(name: "iiextmetadatalanguage", value: "en"),
            URLQueryItem(name: "iiextmetadatafilter", value: "ImageDescription|Artist|LicenseShortName|LicenseUrl|Source")
        ]
        guard var components = URLComponents(string: Self.baseURL) else {
            throw WikimediaCommonsServiceError.invalidResponse
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw WikimediaCommonsServiceError.invalidResponse
        }

        let response: CommonsAPIResponse = try await request(url: url)
        let photos = (response.query.pages ?? []).compactMap(makePhoto)
        let hasMore = response.continuation?.searchOffset != nil || (response.query.pages?.count ?? 0) == Self.pageSize
        return WallpaperPhotoPage(photos: photos, totalPages: hasMore ? page + 1 : page)
    }

    private func request<Response: Decodable>(url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .useProtocolCachePolicy

        let (data, response) = try await Self.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WikimediaCommonsServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw WikimediaCommonsServiceError.rateLimited
            }
            throw WikimediaCommonsServiceError.requestFailed
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw WikimediaCommonsServiceError.invalidResponse
        }
    }

    private func makePhoto(from page: CommonsPage) -> WallpaperPhoto? {
        guard let image = page.imageInfo?.first,
              let originalAddress = image.url,
              let originalURL = secureURL(originalAddress),
              let sourceAddress = image.descriptionURL,
              let sourceURL = secureURL(sourceAddress),
              let licenseName = plainText(image.metadata?.licenseShortName?.value),
              let licenseAddress = image.metadata?.licenseURL?.value,
              isCC0(licenseName: licenseName, licenseAddress: licenseAddress),
              let licenseURL = secureURL(licenseAddress) else {
            return nil
        }

        let thumbnailURL = secureURL(image.thumbURL ?? originalAddress) ?? originalURL
        let fileTitle = page.title.hasPrefix("File:") ? String(page.title.dropFirst(5)) : page.title
        let fileBaseName = (fileTitle as NSString).deletingPathExtension
        let description = plainText(image.metadata?.imageDescription?.value)
        let title = description.flatMap { $0.isEmpty ? nil : $0 } ?? fileBaseName
        let creator = plainText(image.metadata?.artist?.value)
        let sourceCredit = plainText(image.metadata?.source?.value)

        return WallpaperPhoto(
            id: String(page.pageID),
            title: title,
            width: image.width ?? 0,
            height: image.height ?? 0,
            thumbnailAddress: thumbnailURL.absoluteString,
            originalAddress: originalURL.absoluteString,
            sourceAddress: sourceURL.absoluteString,
            creator: creator?.isEmpty == false ? creator : nil,
            sourceCredit: sourceCredit?.isEmpty == false ? sourceCredit : nil,
            licenseName: licenseName,
            licenseAddress: licenseURL.absoluteString,
            provider: .wikimediaCommons,
            sourceWidth: image.width,
            sourceHeight: image.height,
            sourceFileSizeBytes: image.size,
            uploadTimestamp: image.timestamp.flatMap { ISO8601DateFormatter().date(from: $0) }
        )
    }

    private func isCC0(licenseName: String, licenseAddress: String) -> Bool {
        licenseName.localizedCaseInsensitiveContains("CC0")
            || licenseAddress.localizedCaseInsensitiveContains("creativecommons.org/publicdomain/zero/1.0")
    }

    private func secureURL(_ value: String?) -> URL? {
        guard var components = value.flatMap(URLComponents.init(string:)),
              components.scheme == "https" || components.scheme == "http",
              components.host != nil else {
            return nil
        }
        if components.scheme == "http" {
            components.scheme = "https"
        }
        return components.url
    }

    private func plainText(_ value: String?) -> String? {
        guard let value else { return nil }
        let withoutMarkup = value
            .replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return withoutMarkup.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

private struct CommonsAPIResponse: Decodable {
    let query: CommonsQuery
    let continuation: CommonsContinuation?

    enum CodingKeys: String, CodingKey {
        case query
        case continuation = "continue"
    }
}

private struct CommonsQuery: Decodable {
    let pages: [CommonsPage]?
}

private struct CommonsPage: Decodable {
    let pageID: Int
    let title: String
    let imageInfo: [CommonsImageInfo]?

    enum CodingKeys: String, CodingKey {
        case pageID = "pageid"
        case title
        case imageInfo = "imageinfo"
    }
}

private struct CommonsImageInfo: Decodable {
    let timestamp: String?
    let url: String?
    let thumbURL: String?
    let descriptionURL: String?
    let width: Int?
    let height: Int?
    let size: Int64?
    let metadata: CommonsMetadata?

    enum CodingKeys: String, CodingKey {
        case timestamp
        case url
        case thumbURL = "thumburl"
        case descriptionURL = "descriptionurl"
        case width
        case height
        case size
        case metadata = "extmetadata"
    }
}

private struct CommonsMetadata: Decodable {
    let imageDescription: CommonsMetadataValue?
    let artist: CommonsMetadataValue?
    let licenseShortName: CommonsMetadataValue?
    let licenseURL: CommonsMetadataValue?
    let source: CommonsMetadataValue?

    enum CodingKeys: String, CodingKey {
        case imageDescription = "ImageDescription"
        case artist = "Artist"
        case licenseShortName = "LicenseShortName"
        case licenseURL = "LicenseUrl"
        case source = "Source"
    }
}

private struct CommonsMetadataValue: Decodable {
    let value: String?
}

private struct CommonsContinuation: Decodable {
    let searchOffset: Int?

    enum CodingKeys: String, CodingKey {
        case searchOffset = "gsroffset"
    }
}

enum WikimediaCommonsServiceError: LocalizedError {
    case rateLimited
    case requestFailed
    case invalidResponse
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .rateLimited:
            "Wikimedia Commons is temporarily limiting requests. Please wait a moment and try again."
        case .requestFailed:
            "The request to Wikimedia Commons failed. Check your connection and try again."
        case .invalidResponse:
            "Wikimedia Commons returned an unexpected response. Please try again."
        case .imageUnavailable:
            "The image could not be downloaded from Wikimedia Commons. Please try again."
        }
    }
}
