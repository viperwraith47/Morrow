import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?
    private let store: WallpaperStore

    static func show(store: WallpaperStore) {
        if shared == nil {
            shared = SettingsWindowController(store: store)
        }
        shared?.showWindow(nil)
    }

    private init(store: WallpaperStore) {
        self.store = store
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 700, height: 540)),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureWindow() {
        guard let window else { return }

        window.title = "Morrow"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .automatic
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("MorrowSettingsWindow")
        window.minSize = NSSize(width: 620, height: 460)
        window.center()
        window.delegate = self
        window.contentViewController = NSHostingController(rootView: SettingsView(store: store))
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }
}
