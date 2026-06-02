import AppKit
import CoreGraphics
import Foundation

final class InputBlocker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var emergencyUnlock: (() -> Void)?
    private var emergencyShortcut = EmergencyShortcut.defaultShortcut
    private var pressedKeyCodes = Set<Int64>()
    private var hasTriggeredEmergencyUnlock = false
    private var isStoppingAfterEmergencyUnlock = false

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start(emergencyShortcut: EmergencyShortcut, onEmergencyUnlock: @escaping () -> Void) -> Bool {
        guard !isRunning else { return true }
        stop()

        self.emergencyShortcut = emergencyShortcut
        hasTriggeredEmergencyUnlock = false
        isStoppingAfterEmergencyUnlock = false
        emergencyUnlock = onEmergencyUnlock

        let eventMask = InputBlocker.blockedEvents.reduce(CGEventMask(0)) { mask, type in
            mask | (1 << type.rawValue)
        }

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let tapAndLocation = InputBlocker.createTap(eventMask: eventMask, userInfo: userInfo)

        guard let tap = tapAndLocation.tap else {
            emergencyUnlock = nil
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            emergencyUnlock = nil
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap started.")
        print("\(tapAndLocation.usedHIDTap ? "HID event tap created." : "Session event tap fallback used.")")
        return true
    }

    func stop() {
        let wasRunning = isRunning
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        emergencyUnlock = nil
        pressedKeyCodes.removeAll()
        hasTriggeredEmergencyUnlock = false
        isStoppingAfterEmergencyUnlock = false
        if wasRunning {
            print("Event tap stopped.")
        }
    }

    private func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return nil
        }

        if isStoppingAfterEmergencyUnlock {
            return nil
        }

        updatePressedKeys(event: event, type: type)

        if isEmergencyUnlock() {
            if !hasTriggeredEmergencyUnlock {
                hasTriggeredEmergencyUnlock = true
                isStoppingAfterEmergencyUnlock = true
                print("Emergency unlock detected.")
                DispatchQueue.main.async { [weak self] in
                    self?.emergencyUnlock?()
                    print("Emergency unlock consumed.")
                }
            }
            return nil
        }

        if type == InputBlocker.systemDefinedEventType {
            logSystemDefinedEvent(event)
            return nil
        }

        return nil
    }

    private func updatePressedKeys(event: CGEvent, type: CGEventType) {
        switch type {
        case .keyDown:
            pressedKeyCodes.insert(event.getIntegerValueField(.keyboardEventKeycode))
        case .keyUp:
            pressedKeyCodes.remove(event.getIntegerValueField(.keyboardEventKeycode))
        case .flagsChanged:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if pressedKeyCodes.contains(keyCode) {
                pressedKeyCodes.remove(keyCode)
            } else {
                pressedKeyCodes.insert(keyCode)
            }
        default:
            break
        }
    }

    private func isEmergencyUnlock() -> Bool {
        emergencyShortcut.keyCodes.isSubset(of: pressedKeyCodes)
    }

    private func logSystemDefinedEvent(_ event: CGEvent) {
        if let nsEvent = NSEvent(cgEvent: event) {
            print("System/media key event blocked: subtype=\(nsEvent.subtype.rawValue), data1=\(nsEvent.data1)")
        } else {
            print("System/media key event blocked")
        }
    }

    private static func createTap(eventMask: CGEventMask, userInfo: UnsafeMutableRawPointer) -> (tap: CFMachPort?, usedHIDTap: Bool) {
        if let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: InputBlocker.eventTapCallback,
            userInfo: userInfo
        ) {
            return (tap, true)
        }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: InputBlocker.eventTapCallback,
            userInfo: userInfo
        )
        return (tap, false)
    }

    private static let blockedEvents: [CGEventType] = [
        .keyDown,
        .keyUp,
        .flagsChanged,
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .rightMouseUp,
        .otherMouseDown,
        .otherMouseUp,
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged,
        .scrollWheel,
        InputBlocker.systemDefinedEventType
    ]

    private static let systemDefinedEventType = CGEventType(rawValue: 14)!

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return nil }
        let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
        return blocker.handle(event: event, type: type)
    }
}
