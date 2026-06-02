import SwiftUI
import AppKit

struct CleaningOverlayView: View {
    var remainingSeconds: Int
    let autoUnlockEnabled: Bool
    let unlockShortcutText: String
    let appearance: OverlayAppearance

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 18) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                Text("Cleaning Mode Active")
                    .font(.system(size: 42, weight: .bold))

                Text("Keyboard and trackpad are temporarily locked.")
                    .font(.title2)

                Text("Unlock: \(unlockShortcutText)")
                    .font(.title3.monospaced())
                    .padding(.top, 4)

                Text(autoUnlockText)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.82))

            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(40)
        }
    }

    private var autoUnlockText: String {
        autoUnlockEnabled ? "Auto-unlocks in \(remainingSeconds) seconds." : "Auto-unlock disabled."
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch appearance.style {
        case .default:
            Color.black.opacity(0.88)
                .ignoresSafeArea()
        case .transparent:
            Color.black.opacity(appearance.opacity)
                .ignoresSafeArea()
        case .customImage:
            if let image = customImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
            } else {
                Color.black.opacity(0.88)
                    .ignoresSafeArea()
            }
        }
    }

    private var customImage: NSImage? {
        guard
            let path = appearance.customImagePath,
            FileManager.default.fileExists(atPath: path),
            let image = NSImage(contentsOfFile: path)
        else {
            return nil
        }
        return image
    }
}
