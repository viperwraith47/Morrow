import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WallpaperStore
    @State private var selectedPhoto: UnsplashPhoto?

    private let columns = [GridItem(.adaptive(minimum: 190, maximum: 300), spacing: 18, alignment: .top)]

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selection) {
                Label("Morrow", systemImage: "photo.stack.fill")
                    .font(.headline)
                    .padding(.vertical, 6)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Section("Explore") {
                    Label("For You", systemImage: "sparkles")
                        .tag(SidebarDestination.forYou)
                    Label("Nature", systemImage: "leaf")
                        .tag(SidebarDestination.category("nature"))
                    Label("Architecture", systemImage: "building.2")
                        .tag(SidebarDestination.category("architecture"))
                    Label("Minimal", systemImage: "circle.lefthalf.filled")
                        .tag(SidebarDestination.category("minimal"))
                    Label("Ocean", systemImage: "water.waves")
                        .tag(SidebarDestination.category("ocean"))
                    Label("Abstract", systemImage: "scribble.variable")
                        .tag(SidebarDestination.category("abstract"))
                }

                Section("Library") {
                    Label("Saved", systemImage: "heart")
                        .badge(store.favorites.count)
                        .tag(SidebarDestination.saved)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Morrow")
            .navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 270)
        } detail: {
            detailView
                .navigationTitle(store.navigationTitle)
                .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search wallpapers")
                .onSubmit(of: .search) {
                    Task { await store.submitSearch() }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Picker("Orientation", selection: $store.orientation) {
                            ForEach(WallpaperOrientation.allCases) { orientation in
                                Text(orientation.title).tag(orientation)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .help("Filter by wallpaper orientation")

                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .help("Refresh wallpapers")
                        .keyboardShortcut("r", modifiers: .command)

                        Button {
                            SettingsWindowController.show(store: store)
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .help("Open Settings")
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 560)
        .task { await store.bootstrap() }
        .onChange(of: store.selection) { _, destination in
            guard let destination else { return }
            Task { await store.select(destination) }
        }
        .onChange(of: store.orientation) { _, orientation in
            Task { await store.changeOrientation(to: orientation) }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, store: store)
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

    private var detailView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.navigationTitle)
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.serif)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !store.displayedPhotos.isEmpty {
                    Text("\(store.displayedPhotos.count) wallpapers")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 23)
            .padding(.bottom, 18)

            Divider()

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.isConnected {
            connectPrompt
        } else if store.isLoading && store.displayedPhotos.isEmpty {
            ProgressView("Finding your next favorite…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.displayedPhotos.isEmpty {
            emptyState
        } else {
            let displayedPhotos = store.displayedPhotos
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 21) {
                    ForEach(Array(displayedPhotos.enumerated()), id: \.element.id) { item in
                        WallpaperTile(
                            photo: item.element,
                            isSaved: store.isSaved(item.element),
                            onSelect: { selectedPhoto = item.element },
                            onToggleSaved: { store.toggleSaved(item.element) }
                        )
                        .onAppear {
                            guard item.offset >= displayedPhotos.count - 4,
                                  store.canLoadMore,
                                  store.selection != .saved else { return }
                            Task { await store.loadMore() }
                        }
                    }
                }
                .padding(24)

                if store.isLoading && store.canLoadMore && store.selection != .saved {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
        }
    }

    private var connectPrompt: some View {
        ContentUnavailableView {
            Label("Bring the world in.", systemImage: "photo.stack")
        } description: {
            Text("Connect a free Unsplash Access Key to browse, save, and download high-resolution wallpapers. Your key is kept in macOS Keychain.")
        } actions: {
            Button("Open Settings") { SettingsWindowController.show(store: store) }
                .buttonStyle(.borderedProminent)
            Link("Create a free Unsplash developer app", destination: URL(string: "https://unsplash.com/oauth/applications")!)
        }
    }

    private var emptyState: some View {
        let isSaved = store.selection == .saved
        let isSearching = store.selection == nil || !store.searchText.isEmpty
        return ContentUnavailableView {
            Label(
                isSaved ? "No Saved Wallpapers" : (isSearching ? "No Wallpapers Found" : "No Photos Yet"),
                systemImage: isSaved ? "heart" : "photo.on.rectangle.angled"
            )
        } description: {
            Text(isSaved ? "Save a few wallpapers and they’ll be waiting here." : "Try another search or explore a different mood.")
        } actions: {
            if isSaved {
                Button("Browse Discover") { store.selection = .forYou }
                    .buttonStyle(.bordered)
            } else if isSearching {
                Button("Clear Search") { store.clearSearch() }
                    .buttonStyle(.bordered)
            } else {
                Button("Refresh") { Task { await store.refresh() } }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var subtitle: String {
        switch store.selection {
        case .saved:
            "The photographs you’ve kept close."
        case .category(let category):
            "A little inspiration, gathered around \(category)."
        case .forYou:
            "Thoughtful photographs for the spaces you look at every day."
        case nil:
            "A new point of view, found on Unsplash."
        }
    }
}
