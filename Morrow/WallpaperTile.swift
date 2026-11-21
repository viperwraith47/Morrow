import SwiftUI

struct WallpaperTile: View {
    let photo: UnsplashPhoto
    let isSaved: Bool
    let onSelect: () -> Void
    let onToggleSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Button(action: onSelect) {
                    wallpaperImage
                        .aspectRatio(photo.aspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview \(photo.title)")

                Button(action: onToggleSaved) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSaved ? Color.accentColor : Color.primary)
                        .frame(width: 30, height: 30)
                        .background(.regularMaterial, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(9)
                .help(isSaved ? "Remove from Saved" : "Save Wallpaper")
                .accessibilityLabel(isSaved ? "Remove from Saved" : "Save Wallpaper")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(photo.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text("by \(photo.creditName)")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
        }
        .contextMenu {
            Button(isSaved ? "Remove from Saved" : "Save Wallpaper", systemImage: isSaved ? "heart.slash" : "heart", action: onToggleSaved)
            if let address = photo.links?.html, let url = attributedURL(address) {
                Link("View on Unsplash", destination: url)
            }
        }
    }

    @ViewBuilder
    private var wallpaperImage: some View {
        if let url = photo.urls.smallURL ?? photo.urls.regularURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                case .empty:
                    Rectangle()
                        .fill(.quaternary)
                        .overlay { ProgressView() }
                @unknown default:
                    Rectangle().fill(.quaternary)
                }
            }
        } else {
            Rectangle().fill(.quaternary)
        }
    }
}

func attributedURL(_ address: String) -> URL? {
    guard var components = URLComponents(string: address) else { return nil }
    var items = components.queryItems ?? []
    items.removeAll { $0.name == "utm_source" || $0.name == "utm_medium" }
    items.append(URLQueryItem(name: "utm_source", value: "morrow"))
    items.append(URLQueryItem(name: "utm_medium", value: "referral"))
    components.queryItems = items
    return components.url
}
