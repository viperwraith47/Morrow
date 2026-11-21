import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case unsplash
    case credits

    var id: Self { self }

    var title: String {
        switch self {
        case .unsplash: "Unsplash"
        case .credits: "Credits"
        }
    }

    var systemImage: String {
        switch self {
        case .unsplash: "key.horizontal"
        case .credits: "person.2"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: WallpaperStore
    @State private var selectedTab: SettingsTab? = .unsplash
    @State private var navigationHistory: [SettingsTab] = [.unsplash]
    @State private var historyIndex = 0
    @State private var isHistoryNavigation = false

    private var activeTab: SettingsTab {
        selectedTab ?? .unsplash
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
                case .unsplash:
                    UnsplashSettingsPane(store: store)
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

private struct UnsplashSettingsPane: View {
    @ObservedObject var store: WallpaperStore
    @State private var accessKey = ""

    var body: some View {
        Form {
            Section("Unsplash API") {
                Text("Connect your free Unsplash developer app to browse and download wallpapers.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                SecureField("Access Key", text: $accessKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(store.isValidatingKey)

                HStack {
                    Button(store.isValidatingKey ? "Checking…" : "Connect") {
                        Task {
                            await store.connect(accessKey: accessKey)
                            if store.connectionMessage?.hasPrefix("Connected to Unsplash.") == true {
                                accessKey = ""
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isValidatingKey || accessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if store.isConnected {
                        Button("Remove Key", role: .destructive) {
                            store.removeAccessKey()
                            accessKey = ""
                        }
                    }

                    Link("Get a free key", destination: URL(string: "https://unsplash.com/oauth/applications")!)
                }

                if let message = store.connectionMessage {
                    let isSuccess = message.hasPrefix("Connected to Unsplash.")
                    Label(message, systemImage: isSuccess ? "checkmark.circle" : "info.circle")
                        .font(.callout)
                        .foregroundStyle(isSuccess ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Privacy") {
                Label("Your Access Key is stored in macOS Keychain. Photo requests go directly from this app to Unsplash.", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Use your public Access Key, not the Secret Key. Unsplash demo apps are limited to 50 API requests per hour.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
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
                Text("Morrow is powered by the Unsplash API. Photographers are credited with their photos.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Visit Unsplash", destination: URL(string: "https://unsplash.com")!)
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
