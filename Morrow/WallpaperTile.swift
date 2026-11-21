import AppKit
import SwiftUI

struct WallpaperTile: View {
    let photo: WallpaperPhoto
    @ObservedObject var store: WallpaperStore
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Button(action: onSelect) {
                    GeometryReader { geometry in
                        wallpaperImage
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .aspectRatio(photo.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Preview \(photo.title)")

                Button {
                    store.toggleSaved(photo)
                } label: {
                    Image(systemName: store.isSaved(photo) ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(store.isSaved(photo) ? Color.accentColor : Color.primary)
                        .frame(width: 30, height: 30)
                        .background(.regularMaterial, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(9)
                .help(store.isSaved(photo) ? "Remove from Saved" : "Save Wallpaper")
                .accessibilityLabel(store.isSaved(photo) ? "Remove from Saved" : "Save Wallpaper")

                if store.isOffline(photo) || store.isKeepingOffline(photo) {
                    Image(systemName: store.isOffline(photo) ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(7)
                        .background(.regularMaterial, in: Circle())
                        .padding(9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .help(store.isOffline(photo) ? "Available offline" : "Saving offline…")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(photo.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    HStack(spacing: 5) {
                        Text("by \(photo.creditName)")
                            .lineLimit(1)
                        if let sourceURL = photo.sourceURL {
                            Link(photo.provider.shortName, destination: sourceURL)
                        } else {
                            Text(photo.provider.shortName)
                        }
                        if store.isOffline(photo) {
                            Image(systemName: "arrow.down.circle.fill")
                                .help("Available offline")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
        }
        .contextMenu {
            Button(
                store.isSaved(photo) ? "Remove from Saved" : "Save Wallpaper",
                systemImage: store.isSaved(photo) ? "heart.slash" : "heart"
            ) {
                store.toggleSaved(photo)
            }
            Button(
                store.isOffline(photo) ? "Remove Offline Copy" : "Keep Offline",
                systemImage: store.isOffline(photo) ? "trash" : "arrow.down.circle"
            ) {
                Task { await store.toggleOffline(photo) }
            }
            .disabled(store.isKeepingOffline(photo))

            if store.isSaved(photo) && !store.collections.isEmpty {
                Menu {
                    ForEach(store.collections) { collection in
                        Button {
                            store.toggleCollectionMembership(photo, collectionID: collection.id)
                        } label: {
                            if store.isInCollection(photo, collectionID: collection.id) {
                                Label(collection.name, systemImage: "checkmark")
                            } else {
                                Text(collection.name)
                            }
                        }
                    }
                } label: {
                    Label("Collections", systemImage: "folder.badge.plus")
                }
            }

            if let url = photo.sourceURL {
                Link("View on \(photo.provider.displayName)", destination: url)
            }
        }
    }

    @ViewBuilder
    private var wallpaperImage: some View {
        WallpaperImageView(url: photo.thumbnailURL, localImageURL: store.offlineURL(for: photo)) { image, isLoading in
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
    }
}

struct WallpaperImageView<Content: View>: View {
    let url: URL?
    let localImageURL: URL?
    let content: (NSImage?, Bool) -> Content
    @State private var image: NSImage?
    @State private var isLoading = false

    init(
        url: URL?,
        localImageURL: URL? = nil,
        @ViewBuilder content: @escaping (NSImage?, Bool) -> Content
    ) {
        self.url = url
        self.localImageURL = localImageURL
        self.content = content
    }

    var body: some View {
        content(image, isLoading)
            .task(id: localImageURL ?? url) {
                image = nil
                isLoading = true
                defer { isLoading = false }

                if let localImageURL, let localImage = NSImage(contentsOf: localImageURL) {
                    image = localImage
                    return
                }
                guard let url else { return }
                image = await WallpaperImageService.image(at: url)
            }
    }
}
