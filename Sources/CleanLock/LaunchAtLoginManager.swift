import CleanLockShared
import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    private static let service = SMAppService.loginItem(identifier: CleanLockBundleIdentifier.loginHelper)

    static var isEnabled: Bool {
        service.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if service.status != .enabled {
                try service.register()
            }
            print("Start at login enabled.")
        } else {
            if service.status == .enabled {
                try service.unregister()
            }
            print("Start at login disabled.")
        }
    }
}
