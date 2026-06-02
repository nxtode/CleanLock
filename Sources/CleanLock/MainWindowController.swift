import AppKit
import SwiftUI

struct MainWindowActions {
    let startCleaning: () -> Void
    let showMainWindow: () -> Void
    let refreshPermissions: () -> Void
    let openAccessibilitySettings: () -> Void
    let openInputMonitoringSettings: () -> Void
    let checkForUpdates: () -> Void
    let openDonationLink: () -> Void
    let openLatestReleasePage: () -> Void
    let openWebsite: () -> Void
    let openRepository: () -> Void
    let updateAutomaticUpdatePreference: (Bool) -> Void
    let updateStartAtLoginPreference: (Bool) -> Void
    let menuBarPreferenceChanged: (Bool) -> Void
}

final class MainWindowController: NSWindowController, NSWindowDelegate {
    init(model: CleanLockModel, actions: MainWindowActions) {
        let rootView = MainView(model: model, actions: actions)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "CleanLock"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        nil
    }

    func showAndFocus() {
        guard let window else { return }
        showWindow(nil)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("Main window opened/focused.")
    }
}
