import AppKit
import ApplicationServices
import CoreGraphics

struct PermissionStatus: Equatable {
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool
    let inputEventTapAvailable: Bool

    var allGranted: Bool {
        accessibilityGranted && inputMonitoringGranted && inputEventTapAvailable
    }
}

final class PermissionManager {
    var status: PermissionStatus {
        let accessibilityGranted = AXIsProcessTrusted()
        let inputMonitoringGranted = CGPreflightListenEventAccess()
        let inputEventTapAvailable = inputMonitoringGranted && Self.canCreateInputEventTap()

        return PermissionStatus(
            accessibilityGranted: accessibilityGranted,
            inputMonitoringGranted: inputMonitoringGranted,
            inputEventTapAvailable: inputEventTapAvailable
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
        print("Input event tap probe \(currentStatus.inputEventTapAvailable ? "available" : "unavailable").")
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

    private static func canCreateInputEventTap() -> Bool {
        let eventTypes: [CGEventType] = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            .mouseMoved,
            .leftMouseDown,
            .scrollWheel
        ]
        let eventMask = eventTypes.reduce(CGEventMask(0)) { mask, type in
            mask | (1 << type.rawValue)
        }

        if let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) {
            CFMachPortInvalidate(tap)
            return true
        }

        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
            userInfo: nil
        ) {
            CFMachPortInvalidate(tap)
            return true
        }

        return false
    }
}
