import Foundation

final class CleanLockModel: ObservableObject {
    @Published var isCleaning = false
    @Published var isStoppingCleaningMode = false
    @Published var permissionStatus = PermissionStatus(
        accessibilityGranted: false,
        inputMonitoringGranted: false,
        inputEventTapAvailable: false
    )
    @Published var inlineMessage: String?
    @Published var updateCheckStatus: UpdateCheckStatus = .idle
    @Published var updateStatusText = UpdateCheckStatus.idle.rawValue
    @Published var latestReleaseURL: URL?
    @Published var updatesAutomaticallyEnabled = true
    @Published var startAtLoginEnabled = false
    @Published var startAtLoginStatusText: String?

    var statusText: String {
        if isCleaning {
            return "Cleaning Mode Active"
        }
        return permissionStatus.allGranted ? "Ready" : "Permissions Required"
    }
}
