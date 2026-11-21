import SwiftUI

struct PhotoDetailView: View {
    let photo: WallpaperPhoto
    @ObservedObject var store: WallpaperStore
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingNewCollection = false

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

                            Text("Creator: \(photo.creditName)")
                                .font(.callout)
                            if let sourceURL = photo.sourceURL {
                                Link("View on \(photo.provider.displayName)", destination: sourceURL)
                                    .font(.callout)
                            }

                            HStack(spacing: 5) {
                                Text("License:")
                                if let licenseURL = photo.licenseURL {
                                    Link(photo.licenseName, destination: licenseURL)
                                } else {
                                    Text(photo.licenseName)
                                }
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)

                            if let sourceCredit = photo.sourceCredit {
                                Text("Source details: \(sourceCredit)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                    .padding(.bottom, 3)

                    photoMetadata

                    HStack(spacing: 12) {
                        Button {
                            Task { await store.toggleOffline(photo) }
                        } label: {
                            Label(
                                store.isKeepingOffline(photo) ? "Saving Offline…" : store.isOffline(photo) ? "Remove Offline Copy" : "Keep Offline",
                                systemImage: store.isOffline(photo) ? "checkmark.circle.fill" : "arrow.down.circle"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.isKeepingOffline(photo))

                        Menu {
                            if store.collections.isEmpty {
                                Button("No Collections Yet") {}
                                    .disabled(true)
                            } else {
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
                            }
                            Divider()
                            Button("New Collection…", systemImage: "plus") {
                                isPresentingNewCollection = true
                            }
                        } label: {
                            Label("Collections", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!store.isSaved(photo))
                        .help(store.isSaved(photo) ? "Add this favorite to a collection" : "Save this wallpaper before adding it to a collection")

                        if !store.isSaved(photo) {
                            Text("Save this wallpaper to add it to a collection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    if store.isOffline(photo) {
                        Label("The full image is stored on this Mac and can be applied offline.", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()
            HStack {
                Text(photo.provider.licenseNotice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let sourceURL = photo.sourceURL {
                    Link("Open source page", destination: sourceURL)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 600, idealWidth: 820, minHeight: 520, idealHeight: 680)
        .sheet(isPresented: $isPresentingNewCollection) {
            CollectionNameSheet(title: "New Collection", initialName: "") { name in
                if let collection = store.createCollection(named: name) {
                    store.toggleCollectionMembership(photo, collectionID: collection.id)
                }
            }
        }
        .alert("Morrow", isPresented: Binding(
            get: { store.alertMessage != nil },
            set: { if !$0 { store.dismissAlert() } }
        )) {
            Button("OK", role: .cancel) { store.dismissAlert() }
        } message: {
            Text(store.alertMessage ?? "")
        }
    }

    private var photoMetadata: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(photo.qualityLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())

                if let dimensions = photo.availableDimensionsText {
                    Text("Available: \(dimensions)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Available dimensions unavailable")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let originalDimensions = photo.originalDimensionsText {
                Text("Source dimensions: \(originalDimensions)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let sourceFileSize = photo.sourceFileSizeText {
                Text("Original file size: \(sourceFileSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let uploadTimestamp = photo.uploadTimestamp {
                Text("Uploaded: \(uploadTimestamp.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if photo.provider == .pixabay {
                Text("Upload date: Not provided by Pixabay")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Upload date unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        WallpaperImageView(url: photo.thumbnailURL, localImageURL: store.offlineURL(for: photo)) { image, isLoading in
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
            } else if isLoading {
                ProgressView("Loading Preview…")
            } else {
                ContentUnavailableView("Image Unavailable", systemImage: "photo")
            }
        }
    }
}
