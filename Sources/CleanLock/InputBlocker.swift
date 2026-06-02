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
    private var isCursorPositionAssociationFrozen = false
    private var originalCapsLockEnabled: Bool?

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
        originalCapsLockEnabled = Self.isCapsLockEnabled
        emergencyUnlock = onEmergencyUnlock

        let eventMask = InputBlocker.blockedEvents.reduce(CGEventMask(0)) { mask, type in
            mask | (1 << type.rawValue)
        }

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let tapAndLocation = InputBlocker.createTap(eventMask: eventMask, userInfo: userInfo)

        guard let tap = tapAndLocation.tap else {
            emergencyUnlock = nil
            restoreCursorPositionAssociation()
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            emergencyUnlock = nil
            restoreCursorPositionAssociation()
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        freezeCursorPositionAssociation()
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
        restoreCapsLockStateIfNeeded()
        originalCapsLockEnabled = nil
        restoreCursorPositionAssociation()
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

        if Self.isCapsLockEvent(event: event, type: type) {
            print("Caps Lock event blocked during Cleaning Mode.")
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

    private func freezeCursorPositionAssociation() {
        let error = CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        if error == .success {
            isCursorPositionAssociationFrozen = true
            print("Cursor movement association frozen.")
        } else {
            print("Cursor movement association freeze failed: \(error.rawValue)")
        }
    }

    private func restoreCursorPositionAssociation() {
        let error = CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        if error == .success {
            if isCursorPositionAssociationFrozen {
                print("Cursor movement association restored.")
            }
        } else {
            print("Cursor movement association restore failed: \(error.rawValue)")
        }
        isCursorPositionAssociationFrozen = false
    }

    private func restoreCapsLockStateIfNeeded() {
        guard let originalCapsLockEnabled else { return }
        let currentCapsLockEnabled = Self.isCapsLockEnabled
        guard currentCapsLockEnabled != originalCapsLockEnabled else {
            print("Caps Lock state unchanged during Cleaning Mode.")
            return
        }

        print("Attempting to restore Caps Lock state to \(originalCapsLockEnabled ? "on" : "off").")
        Self.postCapsLockToggle()
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
    private static let capsLockKeyCode: CGKeyCode = 57

    private static var isCapsLockEnabled: Bool {
        CGEventSource.keyState(.combinedSessionState, key: capsLockKeyCode)
    }

    private static func isCapsLockEvent(event: CGEvent, type: CGEventType) -> Bool {
        guard type == .keyDown || type == .keyUp || type == .flagsChanged else { return false }
        return CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)) == capsLockKeyCode
    }

    private static func postCapsLockToggle() {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: capsLockKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: capsLockKeyCode, keyDown: false)
        else {
            print("Caps Lock restore could not create keyboard events.")
            return
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        print("Caps Lock restore event posted.")
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return nil }
        let blocker = Unmanaged<InputBlocker>.fromOpaque(userInfo).takeUnretainedValue()
        return blocker.handle(event: event, type: type)
    }
}
