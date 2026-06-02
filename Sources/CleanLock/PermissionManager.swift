import AppKit
import ApplicationServices
import CoreGraphics

struct PermissionStatus: Equatable {
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool

    var allGranted: Bool {
        accessibilityGranted && inputMonitoringGranted
    }
}

final class PermissionManager {
    var status: PermissionStatus {
        PermissionStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess()
        )
    }

    var hasRequiredPermissions: Bool {
        status.allGranted
    }

    func openAccessibilitySettings() {
        print("User opened Accessibility settings.")
        requestAccessibilityPrompt()
        openSettingsPane("Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        print("User opened Input Monitoring settings.")
        CGRequestListenEventAccess()
        openSettingsPane("Privacy_ListenEvent")
    }

    func logPermissionStatus() {
        let currentStatus = status
        print("Permission status refreshed.")
        print("Accessibility \(currentStatus.accessibilityGranted ? "granted" : "missing").")
        print("Input Monitoring \(currentStatus.inputMonitoringGranted ? "granted" : "missing").")
    }

    private func requestAccessibilityPrompt() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func openSettingsPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
