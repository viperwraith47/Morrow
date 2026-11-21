import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case photoSource
    case credits

    var id: Self { self }

    var title: String {
        switch self {
        case .photoSource: "Photo Source"
        case .credits: "Credits"
        }
    }

    var systemImage: String {
        switch self {
        case .photoSource: "photo.on.rectangle.angled"
        case .credits: "person.2"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: WallpaperStore
    @State private var selectedTab: SettingsTab? = .photoSource
    @State private var navigationHistory: [SettingsTab] = [.photoSource]
    @State private var historyIndex = 0
    @State private var isHistoryNavigation = false

    private var activeTab: SettingsTab {
        selectedTab ?? .photoSource
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: $selectedTab) {
                Section("Morrow") {
                    ForEach(SettingsTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }

                Text("Morrow")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.sidebar)
            .scrollEdgeEffectStyleSoftIfAvailable()
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 230)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch activeTab {
                case .photoSource:
                    PhotoSourceSettingsPane(store: store)
                case .credits:
                    CreditsSettingsPane()
                }
            }
            .navigationTitle("Morrow")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Settings")
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 660, minHeight: 500)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    moveHistory(to: historyIndex - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Back")
                .disabled(historyIndex == 0)

                Button {
                    moveHistory(to: historyIndex + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Forward")
                .disabled(historyIndex >= navigationHistory.count - 1)
            }
        }
        .onChange(of: selectedTab) { _, tab in
            guard !isHistoryNavigation, let tab else { return }
            guard navigationHistory[historyIndex] != tab else { return }
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
            navigationHistory.append(tab)
            historyIndex = navigationHistory.count - 1
        }
    }

    private func moveHistory(to index: Int) {
        guard navigationHistory.indices.contains(index) else { return }
        isHistoryNavigation = true
        historyIndex = index
        selectedTab = navigationHistory[index]
        DispatchQueue.main.async {
            isHistoryNavigation = false
        }
    }
}

private struct PhotoSourceSettingsPane: View {
    @ObservedObject var store: WallpaperStore
    @ObservedObject private var keyStore = PixabayAPIKeyStore.shared
    @State private var apiKeyInput = ""
    @State private var keyError: String?

    var body: some View {
        Form {
            Section("Photo source") {
                Picker("Discovery source", selection: Binding(
                    get: { store.discoveryProvider },
                    set: { provider in
                        Task { await store.selectDiscoveryProvider(provider) }
                    }
                )) {
                    ForEach(WallpaperProvider.discoveryOptions) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(store.isLoading)

                Text("Choose where Morrow searches for wallpapers. Wallhaven provides public SFW results from the General category only, excluding Anime and People. Pixabay requires your own API key.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if keyStore.hasKeychainKey {
                    Label(
                        store.discoveryProvider == .pixabay
                            ? "Pixabay API key is stored in Keychain"
                            : "Pixabay API key is stored in Keychain but is not used by Wallhaven",
                        systemImage: "checkmark.shield"
                    )
                    .font(.callout)
                } else if keyStore.isUsingDebugKey {
                    Label(
                        store.discoveryProvider == .pixabay
                            ? "A local Debug-only Pixabay key is active"
                            : "A local Debug-only Pixabay key is available but not used by Wallhaven",
                        systemImage: "hammer"
                    )
                    .font(.callout)
                } else if store.discoveryProvider == .pixabay {
                    Label("Pixabay is selected, but it needs an API key", systemImage: "key.horizontal")
                        .font(.callout)
                    Text("Add a key below. Morrow will remain on Pixabay and will not switch sources until you choose another provider.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Wallhaven is selected and searches SFW wallpapers in the General category only. Pixabay needs a key before it can return results.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                SecureField("Pixabay API key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save API Key", action: saveAPIKey)
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if keyStore.hasKeychainKey {
                        Button("Remove Key", role: .destructive, action: removeAPIKey)
                    }
                }

                Link("Get a Pixabay API key", destination: URL(string: "https://pixabay.com/api/docs/")!)
                Link("Pixabay Content License", destination: URL(string: "https://pixabay.com/service/license-summary/")!)
                Link("Visit Wallhaven", destination: URL(string: "https://wallhaven.cc")!)
                Link("Visit Wikimedia Commons", destination: URL(string: "https://commons.wikimedia.org")!)
            }

            Section("Privacy") {
                Label("Search requests go directly from this Mac to the selected provider. Wallhaven receives SFW search terms and a General-category-only filter, excluding Anime and People. Pixabay receives the API key and search terms only when Pixabay is selected.", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Morrow stores a key entered here in macOS Keychain. It has no Morrow account service, analytics, advertising, or cloud sync. Favorites and collections stay on this Mac; wallpapers you choose to keep offline, download, or apply are saved locally.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pixabay search responses are cached for 24 hours. Pixabay image URLs are temporary display URLs; use Keep Offline or Download to save an image locally. Pixabay's API guidance recommends server-side downloads. Morrow makes direct client requests and does not claim Pixabay has approved this architecture.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A developer can optionally configure a local Debug-only test key. That setting is ignored in Release builds; see the source repository instructions. Existing Commons favorites, offline files, and collections are kept as-is; opening a Commons item may still load its image from Wikimedia.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Pixabay privacy policy", destination: URL(string: "https://pixabay.com/service/privacy/")!)
                Link("Wallhaven privacy policy", destination: URL(string: "https://wallhaven.cc/privacy-policy")!)
                Link("Wikimedia Foundation privacy policy", destination: URL(string: "https://foundation.wikimedia.org/wiki/Policy:Privacy_policy")!)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .alert("Pixabay API Key", isPresented: Binding(
            get: { keyError != nil },
            set: { if !$0 { keyError = nil } }
        )) {
            Button("OK", role: .cancel) { keyError = nil }
        } message: {
            Text(keyError ?? "")
        }
    }

    private func saveAPIKey() {
        do {
            try keyStore.saveAPIKey(apiKeyInput)
            apiKeyInput = ""
            Task { await store.photoSourceDidChange() }
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func removeAPIKey() {
        do {
            try keyStore.removeAPIKey()
            Task { await store.photoSourceDidChange() }
        } catch {
            keyError = error.localizedDescription
        }
    }
}

private struct CreditsSettingsPane: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Morrow")
                            .font(.title.bold())
                        Text("A thoughtful place to find your next wallpaper.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Built by") {
                Link(destination: URL(string: "https://github.com/viperwraith47")!) {
                    Label("Viperwraith47", systemImage: "person.crop.circle")
                }
                Text("Thank you for building Morrow.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Photo source") {
                Text("Choose Wallhaven or Pixabay for discovery in Photo Source Settings. Wallhaven provides public SFW results in the General category only, excluding Anime and People; Pixabay requires an API key. Existing Wikimedia Commons wallpapers remain in your library. Morrow is independent and is not endorsed by these providers.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Visit Wallhaven", destination: URL(string: "https://wallhaven.cc")!)
                Link("Visit Pixabay", destination: URL(string: "https://pixabay.com")!)
                Link("Visit Wikimedia Commons", destination: URL(string: "https://commons.wikimedia.org")!)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}

private extension View {
    @ViewBuilder
    func scrollEdgeEffectStyleSoftIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
