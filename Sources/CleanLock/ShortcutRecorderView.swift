import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let onEvent: (NSEvent) -> Void
    let onDisappear: () -> Void

    func makeNSView(context: Context) -> ShortcutRecordingView {
        ShortcutRecordingView()
    }

    func updateNSView(_ nsView: ShortcutRecordingView, context: Context) {
        context.coordinator.onEvent = onEvent
        context.coordinator.onDisappear = onDisappear
        context.coordinator.startMonitoringIfNeeded()
    }

    func dismantleNSView(_ nsView: ShortcutRecordingView, coordinator: Coordinator) {
        coordinator.stopMonitoring()
        coordinator.onDisappear()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onEvent: onEvent, onDisappear: onDisappear)
    }

    final class Coordinator {
        var onEvent: (NSEvent) -> Void
        var onDisappear: () -> Void
        private var monitor: Any?

        init(onEvent: @escaping (NSEvent) -> Void, onDisappear: @escaping () -> Void) {
            self.onEvent = onEvent
            self.onDisappear = onDisappear
        }

        func startMonitoringIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
                self?.onEvent(event)
                return nil
            }
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

final class ShortcutRecordingView: NSView {
    override var acceptsFirstResponder: Bool { true }
}
