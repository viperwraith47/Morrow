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
                    PhotoSourceSettingsPane()
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
    var body: some View {
        Form {
            Section("Photo source") {
                Label("Wikimedia Commons", systemImage: "globe")
                    .font(.headline)
                Text("Morrow searches Commons for bitmap files matching wallpaper or background terms, tagged CC0, and checks each result’s license metadata before displaying it. License and creator details are available with every wallpaper.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Visit Wikimedia Commons", destination: URL(string: "https://commons.wikimedia.org")!)
                Link("About the CC0 1.0 license", destination: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")!)
            }

            Section("Privacy") {
                Label("Searches and image requests go directly from this Mac to Wikimedia. The service receives standard connection information, such as your IP address and request headers.", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Morrow does not use accounts, analytics, or advertising. Favorites and collections are stored on this Mac. Wallpapers you choose to keep offline, download, or apply are saved locally and are not synced.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Older Morrow versions may have stored an Unsplash key or favorites. This version does not read or delete the old keychain item, and keeps the new Commons favorites in separate local storage.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Wikimedia Foundation privacy policy", destination: URL(string: "https://foundation.wikimedia.org/wiki/Policy:Privacy_policy")!)
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
                Text("Morrow uses Wikimedia Commons and displays CC0 license, source, and creator information with each image when available. Morrow is an independent app and is not endorsed by the Wikimedia Foundation.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
