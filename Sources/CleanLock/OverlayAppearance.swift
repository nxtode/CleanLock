import AppKit
import Foundation

enum OverlayStyle: String, CaseIterable, Identifiable {
    case `default`
    case transparent
    case customImage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .transparent:
            return "Transparent"
        case .customImage:
            return "Custom Image"
        }
    }
}

struct OverlayAppearance {
    let style: OverlayStyle
    let opacity: Double
    let tintColorHex: String
    let customImagePath: String?

    static func load() -> OverlayAppearance {
        let styleValue = UserDefaults.standard.string(forKey: PreferencesKeys.overlayStyle) ?? OverlayStyle.default.rawValue
        let style = OverlayStyle(rawValue: styleValue) ?? .default
        let savedOpacity = UserDefaults.standard.object(forKey: PreferencesKeys.overlayOpacity) as? Double
        return OverlayAppearance(
            style: style,
            opacity: min(max(savedOpacity ?? 0.35, 0.10), 0.70),
            tintColorHex: UserDefaults.standard.string(forKey: PreferencesKeys.overlayTintColorHex) ?? "#000000",
            customImagePath: UserDefaults.standard.string(forKey: PreferencesKeys.customOverlayImagePath)
        )
    }
}

enum OverlayImageStore {
    static func copyToApplicationSupport(_ sourceURL: URL) throws -> URL {
        let directory = try applicationSupportDirectory()
        let extensionName = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destination = directory.appendingPathComponent("CustomOverlay.\(extensionName)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("CleanLock", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
