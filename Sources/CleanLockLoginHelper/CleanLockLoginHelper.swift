import AppKit
import Foundation

@main
@MainActor
enum CleanLockLoginHelperMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        guard let agentURL else {
            print("CleanLockMenuBarAgent.app was not found.")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: agentURL, configuration: configuration) { _, error in
            if let error {
                print("CleanLock menu bar agent launch failed: \(error.localizedDescription)")
            }
            app.terminate(nil)
        }

        app.run()
    }

    private static var agentURL: URL? {
        let url = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("CleanLockMenuBarAgent.app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
