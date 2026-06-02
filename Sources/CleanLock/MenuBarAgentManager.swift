import AppKit
import Foundation

enum CleanLockAppCommand {
    static let openMainWindowArgument = "--open-main-window"
    static let startCleaningArgument = "--start-cleaning"
    static let quitMainArgument = "--quit-main"
    static let launchedAtLoginArgument = "--launched-at-login"

    static let openMainWindowNotification = Notification.Name("dev.nxtode.cleanlock.openMainWindow")
    static let startCleaningNotification = Notification.Name("dev.nxtode.cleanlock.startCleaning")
    static let quitMainNotification = Notification.Name("dev.nxtode.cleanlock.quitMain")
    static let quitMenuBarAgentNotification = Notification.Name("dev.nxtode.cleanlock.quitMenuBarAgent")
}

enum CleanLockBundleIdentifier {
    static let main = "dev.nxtode.cleanlock"
    static let menuBarAgent = "dev.nxtode.cleanlock.menubar"
    static let loginHelper = "dev.nxtode.cleanlock.loginhelper"
}

enum MenuBarAgentManager {
    static func start() {
        guard let agentURL else {
            print("Menu bar agent app was not found in the CleanLock bundle.")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: agentURL, configuration: configuration) { _, error in
            if let error {
                print("Menu bar agent launch failed: \(error.localizedDescription)")
            } else {
                print("Menu bar agent launch requested.")
            }
        }
    }

    static func stop() {
        DistributedNotificationCenter.default().postNotificationName(
            CleanLockAppCommand.quitMenuBarAgentNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: CleanLockBundleIdentifier.menuBarAgent) {
            app.terminate()
        }
        print("Menu bar agent stop requested.")
    }

    private static var agentURL: URL? {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LoginItems")
            .appendingPathComponent("CleanLockMenuBarAgent.app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
