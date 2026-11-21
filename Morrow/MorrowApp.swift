import SwiftUI

@main
struct MorrowApp: App {
    @StateObject private var store = WallpaperStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .defaultSize(width: 1120, height: 780)

        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowController.show(store: store)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
