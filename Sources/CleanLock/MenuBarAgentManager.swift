import AppKit
import CleanLockShared
import Foundation

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
            userInfo: CleanLockCommandTokenStore.tokenUserInfo(),
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
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard Bundle(url: url)?.bundleIdentifier == CleanLockBundleIdentifier.menuBarAgent else {
            print("Menu bar agent bundle identifier did not match \(CleanLockBundleIdentifier.menuBarAgent): \(url.path)")
            return nil
        }
        return url
    }
}
