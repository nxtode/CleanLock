import AppKit
import CleanLockShared
import Foundation

@main
@MainActor
enum CleanLockMenuBarAgentMain {
    private static let delegate = MenuBarAgentDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
private final class MenuBarAgentDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(quitAgent(_:)),
            name: CleanLockAgentCommand.quitMenuBarAgentNotification,
            object: nil
        )
        _ = CleanLockCommandTokenStore.loadOrCreateToken()
        configureStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "CleanLock")
                ?? NSImage(systemSymbolName: "lock", accessibilityDescription: "CleanLock")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
            button.toolTip = "CleanLock"
        }

        let menu = NSMenu()
        let appNameItem = NSMenuItem(title: "CleanLock", action: nil, keyEquivalent: "")
        appNameItem.isEnabled = false
        menu.addItem(appNameItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Lock", action: #selector(lock), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences", action: #selector(openCleanLock), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitCompletely), keyEquivalent: ""))

        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func lock() {
        post(.startCleaningNotification)
        launchMainApp(arguments: [CleanLockAgentCommand.startCleaningArgument] + CleanLockCommandTokenStore.tokenArguments())
    }

    @objc private func openCleanLock() {
        post(.openMainWindowNotification)
        launchMainApp(arguments: [CleanLockAgentCommand.openMainWindowArgument])
    }

    @objc private func quitCompletely() {
        post(.quitMainNotification)
        launchMainApp(arguments: [CleanLockAgentCommand.quitMainArgument] + CleanLockCommandTokenStore.tokenArguments())
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    @objc private func quitAgent(_ notification: Notification) {
        guard notification.hasValidCleanLockCommandToken else {
            print("Rejected menu bar agent quit notification with missing or invalid command token.")
            return
        }
        NSApp.terminate(nil)
    }

    private func post(_ notification: Notification.Name) {
        DistributedNotificationCenter.default().postNotificationName(
            notification,
            object: nil,
            userInfo: CleanLockCommandTokenStore.tokenUserInfo(),
            deliverImmediately: true
        )
    }

    private func launchMainApp(arguments: [String]) {
        guard let mainAppURL else {
            print("CleanLock main app could not be located from menu bar agent.")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.activates = arguments.contains(CleanLockAgentCommand.openMainWindowArgument)

        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, error in
            if let error {
                print("CleanLock launch failed: \(error.localizedDescription)")
            }
        }
    }

    private var mainAppURL: URL? {
        let url = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard Bundle(url: url)?.bundleIdentifier == CleanLockBundleIdentifier.main else {
            print("CleanLock main app bundle identifier did not match \(CleanLockBundleIdentifier.main): \(url.path)")
            return nil
        }
        return url
    }
}

private typealias CleanLockAgentCommand = CleanLockAppCommand

private extension Notification {
    var hasValidCleanLockCommandToken: Bool {
        let token = userInfo?[CleanLockAppCommand.commandTokenUserInfoKey] as? String
        return CleanLockCommandTokenStore.validateToken(token)
    }
}

private extension Notification.Name {
    static let openMainWindowNotification = CleanLockAppCommand.openMainWindowNotification
    static let startCleaningNotification = CleanLockAppCommand.startCleaningNotification
    static let quitMainNotification = CleanLockAppCommand.quitMainNotification
}
