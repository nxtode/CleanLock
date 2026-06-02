import Foundation

final class SparkleUpdateManager {
    static let shared = SparkleUpdateManager()

    var isConfigured: Bool {
        AppInfo.appcastURL != nil
    }

    func checkForUpdatesIfConfigured() -> Bool {
        // TODO: Wire Sparkle's SPUStandardUpdaterController once the appcast, signing,
        // and release channel are ready for the packaged app.
        false
    }
}
