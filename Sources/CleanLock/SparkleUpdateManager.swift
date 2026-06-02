import Foundation
import Sparkle

@MainActor
final class SparkleUpdateManager {
    static let shared = SparkleUpdateManager()

    private var updaterController: SPUStandardUpdaterController?
    var statusChanged: ((UpdateCheckStatus, String, URL?) -> Void)?

    private init() {
        guard Self.bundleHasSparkleConfiguration else {
            print("Sparkle updater not started because appcast metadata is not configured in the app bundle.")
            return
        }

        SparkleUpdateDelegate.shared.manager = self
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: SparkleUpdateDelegate.shared,
            userDriverDelegate: nil
        )
        print("Sparkle updater started.")
    }

    var isConfigured: Bool {
        updaterController != nil
    }

    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            updaterController?.updater.automaticallyChecksForUpdates
                ?? UserDefaults.standard.bool(forKey: PreferencesKeys.automaticUpdateChecksEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: PreferencesKeys.automaticUpdateChecksEnabled)
            updaterController?.updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() -> Bool {
        guard let updaterController, updaterController.updater.canCheckForUpdates else {
            return false
        }

        report(.checking, UpdateCheckStatus.checking.rawValue)
        updaterController.checkForUpdates(nil)
        return true
    }

    func checkForUpdatesIfConfigured() -> Bool {
        checkForUpdates()
    }

    fileprivate func report(_ status: UpdateCheckStatus, _ text: String, releaseURL: URL? = nil) {
        statusChanged?(status, text, releaseURL)
    }

    private static var bundleHasSparkleConfiguration: Bool {
        guard
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String != nil,
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return true
    }
}

@MainActor
private final class SparkleUpdateDelegate: NSObject, SPUUpdaterDelegate {
    static let shared = SparkleUpdateDelegate()

    weak var manager: SparkleUpdateManager?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        manager?.report(.idle, "Update available.")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        manager?.report(.upToDate, UpdateCheckStatus.upToDate.rawValue)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        manager?.report(.failed, "Unable to check for updates.")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        manager?.report(.failed, UpdateCheckStatus.failed.rawValue)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {}
}
