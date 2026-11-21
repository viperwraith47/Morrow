import SwiftUI

struct PhotoDetailView: View {
    let photo: UnsplashPhoto
    @ObservedObject var store: WallpaperStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Wallpaper Preview")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    previewImage
                        .frame(maxWidth: .infinity)
                        .frame(height: 470)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(photo.title)
                                .font(.title2.weight(.semibold))
                                .fontDesign(.serif)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 4) {
                                Text("Photo by")
                                if let address = photo.user?.links?.html,
                                   let url = attributedURL(address) {
                                    Link(photo.creditName, destination: url)
                                } else {
                                    Text(photo.creditName)
                                }
                                Text("on")
                                if let address = photo.links?.html,
                                   let url = attributedURL(address) {
                                    Link("Unsplash", destination: url)
                                } else {
                                    Text("Unsplash")
                                }
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 12)
                        Button {
                            store.toggleSaved(photo)
                        } label: {
                            Label(
                                store.isSaved(photo) ? "Saved" : "Save",
                                systemImage: store.isSaved(photo) ? "heart.fill" : "heart"
                            )
                        }
                        .buttonStyle(.bordered)
                        .help(store.isSaved(photo) ? "Remove from Saved" : "Save Wallpaper")

                        Button {
                            Task { await store.applyAsWallpaper(photo) }
                        } label: {
                            Label(
                                store.isApplyingWallpaper ? "Applying…" : "Set as Wallpaper",
                                systemImage: "desktopcomputer"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(store.isApplyingWallpaper || store.isDownloading)

                        Button {
                            Task { await store.download(photo) }
                        } label: {
                            Label(store.isDownloading ? "Saving…" : "Download", systemImage: "arrow.down.to.line")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.isDownloading || store.isApplyingWallpaper)
                    }
                    .padding(.bottom, 5)
                }
                .padding(20)
            }

            Divider()
            HStack {
                Text("Please credit the photographer when sharing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let address = photo.links?.html, let url = attributedURL(address) {
                    Link("View on Unsplash", destination: url)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 600, idealWidth: 820, minHeight: 520, idealHeight: 680)
        .alert("Morrow", isPresented: Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.dismissAlert() } }
        )) {
            Button("OK", role: .cancel) { store.dismissAlert() }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        if let url = photo.urls.regularURL ?? photo.urls.fullURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit()
                case .failure:
                    ContentUnavailableView("Image Unavailable", systemImage: "photo")
                case .empty:
                    ProgressView("Loading Preview…")
                @unknown default:
                    ProgressView()
                }
            }
        } else {
            ContentUnavailableView("Image Unavailable", systemImage: "photo")
        }
    }
}
