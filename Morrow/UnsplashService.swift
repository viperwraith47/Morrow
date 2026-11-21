import Foundation

struct UnsplashService {
    private let session = URLSession.shared
    private let baseURL = "https://api.unsplash.com"
    private let pageSize = 24

    func validate(accessKey: String) async throws {
        let url = try makeURL(path: "/photos", queryItems: [
            URLQueryItem(name: "per_page", value: "1")
        ])
        let _: ([UnsplashPhoto], HTTPURLResponse) = try await request(
            [UnsplashPhoto].self,
            url: url,
            accessKey: accessKey
        )
    }

    func photos(
        query: String,
        orientation: WallpaperOrientation,
        page: Int,
        accessKey: String
    ) async throws -> UnsplashPhotoPage {
        if query.isEmpty && orientation == .all {
            let url = try makeURL(path: "/photos", queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: String(pageSize))
            ])
            let (photos, response): ([UnsplashPhoto], HTTPURLResponse) = try await request(
                [UnsplashPhoto].self,
                url: url,
                accessKey: accessKey
            )
            let lastPage = pageNumber(from: response.value(forHTTPHeaderField: "Link"))
                ?? (photos.count == pageSize ? page + 1 : page)
            return UnsplashPhotoPage(photos: photos, totalPages: max(page, lastPage))
        }

        let searchTerm = query.isEmpty ? "wallpaper" : query
        var queryItems = [
            URLQueryItem(name: "query", value: searchTerm),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(pageSize)),
            URLQueryItem(name: "content_filter", value: "high")
        ]
        if orientation != .all {
            queryItems.append(URLQueryItem(name: "orientation", value: orientation.rawValue))
        }
        let url = try makeURL(path: "/search/photos", queryItems: queryItems)
        let (result, _): (SearchResponse, HTTPURLResponse) = try await request(
            SearchResponse.self,
            url: url,
            accessKey: accessKey
        )
        return UnsplashPhotoPage(photos: result.results, totalPages: max(1, result.totalPages))
    }

    func trackDownload(for photo: UnsplashPhoto, accessKey: String) async throws {
        let endpoint = photo.links?.downloadLocation
            ?? "\(baseURL)/photos/\(photo.id)/download"
        guard let url = URL(string: endpoint) else {
            throw UnsplashServiceError.invalidResponse
        }
        let _: (DownloadResponse, HTTPURLResponse) = try await request(
            DownloadResponse.self,
            url: url,
            accessKey: accessKey
        )
    }

    func imageData(for photo: UnsplashPhoto) async throws -> Data {
        guard let url = photo.urls.fullURL ?? photo.urls.regularURL else {
            throw UnsplashServiceError.imageUnavailable
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw UnsplashServiceError.imageUnavailable
        }
        return data
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw UnsplashServiceError.invalidResponse
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw UnsplashServiceError.invalidResponse
        }
        return url
    }

    private func request<Response: Decodable>(
        _ type: Response.Type,
        url: URL,
        accessKey: String
    ) async throws -> (Response, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        request.setValue("v1", forHTTPHeaderField: "Accept-Version")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnsplashServiceError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let detail = payload?.errors?.joined(separator: " ")
            switch httpResponse.statusCode {
            case 401: throw UnsplashServiceError.invalidKey
            case 403: throw UnsplashServiceError.forbidden
            case 429: throw UnsplashServiceError.rateLimited
            default: throw UnsplashServiceError.requestFailed(detail)
            }
        }
        do {
            return (try JSONDecoder().decode(type, from: data), httpResponse)
        } catch {
            throw UnsplashServiceError.invalidResponse
        }
    }

    private func pageNumber(from header: String?) -> Int? {
        guard let header else { return nil }
        for relation in header.split(separator: ",") where relation.localizedCaseInsensitiveContains("rel=\"last\"") {
            guard let opening = relation.firstIndex(of: "<"),
                  let closing = relation[opening...].firstIndex(of: ">") else { continue }
            let address = String(relation[relation.index(after: opening)..<closing])
            guard let components = URLComponents(string: address),
                  let pageValue = components.queryItems?.first(where: { $0.name == "page" })?.value,
                  let page = Int(pageValue) else { continue }
            return page
        }
        return nil
    }
}

private struct SearchResponse: Decodable {
    let results: [UnsplashPhoto]
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalPages = "total_pages"
    }
}

private struct DownloadResponse: Decodable {
    let url: String?
}

private struct APIErrorResponse: Decodable {
    let errors: [String]?
}

enum UnsplashServiceError: LocalizedError {
    case invalidKey
    case forbidden
    case rateLimited
    case requestFailed(String?)
    case invalidResponse
    case imageUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            "That Unsplash access key was not accepted. Check that you copied the Access Key, not the Secret Key."
        case .forbidden:
            "Unsplash denied this request. Check that your developer application is enabled."
        case .rateLimited:
            "The Unsplash hourly request limit has been reached. Try again later."
        case .requestFailed(let detail):
            detail ?? "The request to Unsplash failed. Please try again."
        case .invalidResponse:
            "Unsplash returned an unexpected response. Please try again."
        case .imageUnavailable:
            "The full-resolution image could not be downloaded. Please try again."
        }
    }
}
