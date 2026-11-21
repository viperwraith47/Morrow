import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WallpaperStore
    @State private var selectedPhoto: WikimediaPhoto?
    @State private var isPresentingNewCollection = false
    @State private var editingCollection: WallpaperCollection?

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
                    Label("Available Offline", systemImage: "arrow.down.circle")
                        .badge(store.offlinePhotos.count)
                        .tag(SidebarDestination.offline)
                }

                Section {
                    ForEach(store.collections) { collection in
                        Label(collection.name, systemImage: "rectangle.stack")
                            .badge(collection.photoIDs.count)
                            .tag(SidebarDestination.collection(collection.id))
                            .contextMenu {
                                Button("Rename Collection…", systemImage: "pencil") {
                                    editingCollection = collection
                                }
                                Button("Delete Collection", systemImage: "trash", role: .destructive) {
                                    store.deleteCollection(collection.id)
                                }
                            }
                    }
                    Button {
                        isPresentingNewCollection = true
                    } label: {
                        Label("New Collection", systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Collections")
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
                        .disabled(store.isLocalLibrarySelection || store.isLoading)

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
        .sheet(isPresented: $isPresentingNewCollection) {
            CollectionNameSheet(title: "New Collection", initialName: "") { name in
                _ = store.createCollection(named: name)
            }
        }
        .sheet(item: $editingCollection) { collection in
            CollectionNameSheet(title: "Rename Collection", initialName: collection.name) { name in
                store.renameCollection(collection.id, to: name)
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
        if store.isLoading && store.displayedPhotos.isEmpty && !store.isLocalLibrarySelection {
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
                            store: store,
                            onSelect: { selectedPhoto = item.element }
                        )
                        .onAppear {
                            guard item.offset >= displayedPhotos.count - 4,
                                  store.canLoadMore,
                                  !store.isLocalLibrarySelection else { return }
                            Task { await store.loadMore() }
                        }
                    }
                }
                .padding(24)

                if store.isLoading && store.canLoadMore && !store.isLocalLibrarySelection {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
            }
        }
    }

    private var emptyState: some View {
        let isSaved = store.selection == .saved
        let isOffline = store.selection == .offline
        let isCollection: Bool = {
            guard let selection = store.selection else { return false }
            if case .collection(_) = selection { return true }
            return false
        }()
        let isSearching = store.selection == nil || !store.searchText.isEmpty
        let title = isSaved ? "No Saved Wallpapers" :
            isOffline ? "No Offline Wallpapers" :
            isCollection ? "This Collection Is Empty" :
            isSearching ? "No Wallpapers Found" : "No Photos Yet"
        let description = isSaved ? "Save a few wallpapers and they’ll be waiting here." :
            isOffline ? "Keep a wallpaper offline from its preview or tile menu to find it here." :
            isCollection ? "Add saved wallpapers to this collection from a wallpaper’s preview or tile menu." :
            "Try another search or explore a different mood."

        return ContentUnavailableView {
            Label(title, systemImage: isSaved ? "heart" : isOffline ? "arrow.down.circle" : isCollection ? "rectangle.stack" : "photo.on.rectangle.angled")
        } description: {
            Text(description)
        } actions: {
            if isSaved || isOffline || isCollection {
                Button("Browse Discover") { store.selection = .forYou }
                    .buttonStyle(.bordered)
            } else if store.canLoadMore {
                Button("Keep Looking") { Task { await store.loadMore() } }
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
        case .offline:
            "Your wallpapers, ready without a connection."
        case .collection(_):
            "A collection for browsing and applying wallpapers by hand."
        case .category(let category):
            "A little inspiration, gathered around \(category)."
        case .forYou:
            "Thoughtful photographs for the spaces you look at every day."
        case nil:
            "A new point of view, found on Wikimedia Commons."
        }
    }
}

struct CollectionNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let title: String
    let onSave: (String) -> Void

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
            TextField("Collection name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        onSave(trimmedName)
        dismiss()
    }
}
