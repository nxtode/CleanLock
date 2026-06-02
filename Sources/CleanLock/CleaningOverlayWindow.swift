import AppKit
import SwiftUI

final class CleaningOverlayWindow {
    private var windows: [NSWindow] = []
    private var hostingControllers: [NSHostingController<CleaningOverlayView>] = []

    init(rootView: CleaningOverlayView) {
        let screens = NSScreen.screens
        windows = screens.map { screen in
            let controller = NSHostingController(rootView: rootView)
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.contentViewController = controller
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.minSize = screen.frame.size
            window.maxSize = screen.frame.size
            window.setFrame(screen.frame, display: true)
            window.contentView?.frame = NSRect(origin: .zero, size: screen.frame.size)
            window.contentView?.autoresizingMask = [.width, .height]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = false
            window.hidesOnDeactivate = false
            window.canHide = false
            hostingControllers.append(controller)
            print("Overlay window created for screen frame: \(screen.frame)")
            return window
        }
    }

    func show() {
        for window in windows {
            window.setFrame(window.screen?.frame ?? window.frame, display: true)
            window.orderFrontRegardless()
        }
    }

    func updateRemainingSeconds(_ seconds: Int) {
        for controller in hostingControllers {
            controller.rootView.remainingSeconds = seconds
        }
    }

    func close() {
        print("Overlay windows closing: \(windows.count)")
        for window in windows {
            window.close()
        }
        print("Overlay windows closed: \(windows.count)")
        windows.removeAll()
        hostingControllers.removeAll()
    }
}
