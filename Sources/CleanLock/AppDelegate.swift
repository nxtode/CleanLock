import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let model = CleanLockModel()
    private let inputBlocker = InputBlocker()
    private let permissionManager = PermissionManager()
    private var overlayWindow: CleaningOverlayWindow?
    private var mainWindowController: MainWindowController?
    private var countdownTimer: Timer?
    private var remainingSeconds = 0
    private var isCleaning = false
    private var isStoppingCleaningMode = false

    private var duration: Int {
        UserDefaults.standard.sanitizedCleaningDuration()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("App launch.")
        NSApp.setActivationPolicy(.regular)
        registerDefaultPreferences()
        refreshPermissionStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        configureMenuBarVisibility(UserDefaults.standard.bool(forKey: PreferencesKeys.showMenuBarIcon))
        model.updatesAutomaticallyEnabled = UserDefaults.standard.bool(forKey: PreferencesKeys.automaticUpdateChecksEnabled)
        refreshStartAtLoginStatus()
        showMainWindow()
        scheduleAutomaticUpdateCheckIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("Application will terminate.")
        stopCleaningMode()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("Dock reopen requested.")
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func applicationDidBecomeActive() {
        refreshPermissionStatus()
    }

    func startCleaningMode() {
        print("Start cleaning mode requested.")
        guard !isCleaning else { return }

        refreshPermissionStatus()
        guard model.permissionStatus.allGranted else {
            model.inlineMessage = "Enable permissions to start Cleaning"
            print("Start blocked because permissions are missing.")
            showMainWindow()
            return
        }

        remainingSeconds = duration
        let shortcut = EmergencyShortcut.load()

        guard inputBlocker.start(emergencyShortcut: shortcut, onEmergencyUnlock: { [weak self] in
            DispatchQueue.main.async {
                self?.stopCleaningMode(reason: .emergencyShortcut)
            }
        }) else {
            model.inlineMessage = "CleanLock could not start input blocking. Refresh permissions and try again."
            showMainWindow()
            return
        }

        isCleaning = true
        isStoppingCleaningMode = false
        model.isCleaning = true
        model.isStoppingCleaningMode = false
        model.inlineMessage = nil
        menuBarController?.setCleaningActive(true)
        showOverlay(shortcut: shortcut)
        if remainingSeconds > 0 {
            startCountdown()
        } else {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
        print("Cleaning mode started for \(remainingSeconds) seconds.")
    }

    func stopCleaningMode() {
        stopCleaningMode(reason: .manual)
    }

    private func stopCleaningMode(reason: CleaningStopReason) {
        guard isCleaning || inputBlocker.isRunning else { return }
        guard !isStoppingCleaningMode else { return }
        isStoppingCleaningMode = true
        model.isStoppingCleaningMode = true

        countdownTimer?.invalidate()
        countdownTimer = nil
        inputBlocker.stop()
        closeOverlayWindows()
        isCleaning = false
        model.isCleaning = false
        model.isStoppingCleaningMode = false
        isStoppingCleaningMode = false
        refreshPermissionStatus()
        menuBarController?.setCleaningActive(false)
        if reason == .emergencyShortcut {
            print("stopCleaningMode emergencyShortcut started.")
            print("Cleaning mode stopped by emergency shortcut.")
            print("Reopening/focusing main window after emergency unlock.")
            showMainWindow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                print("Main window focused after emergency unlock.")
                self?.showMainWindow()
            }
        }
        print("Main window still retained: \(mainWindowController != nil)")
        print("Cleaning mode stopped.")
    }

    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        refreshPermissionStatus()
        if mainWindowController == nil {
            mainWindowController = MainWindowController(
                model: model,
                actions: MainWindowActions(
                    startCleaning: { [weak self] in self?.startCleaningMode() },
                    showMainWindow: { [weak self] in self?.showMainWindow() },
                    refreshPermissions: { [weak self] in self?.refreshPermissionStatus() },
                    openAccessibilitySettings: { [weak self] in self?.openAccessibilitySettings() },
                    openInputMonitoringSettings: { [weak self] in self?.openInputMonitoringSettings() },
                    checkForUpdates: { [weak self] in self?.checkForUpdates() },
                    openLatestReleasePage: { [weak self] in self?.openLatestReleasePage() },
                    openWebsite: { [weak self] in self?.openWebsite() },
                    openRepository: { [weak self] in self?.openRepository() },
                    updateAutomaticUpdatePreference: { [weak self] isEnabled in
                        self?.updateAutomaticUpdatePreference(isEnabled)
                    },
                    updateStartAtLoginPreference: { [weak self] isEnabled in
                        self?.updateStartAtLoginPreference(isEnabled)
                    },
                    menuBarPreferenceChanged: { [weak self] isEnabled in
                        self?.configureMenuBarVisibility(isEnabled)
                    },
                    restartApp: { [weak self] in self?.restartApp() }
                )
            )
        }
        mainWindowController?.showAndFocus()
    }

    func quit() {
        print("Explicit Quit CleanLock requested.")
        stopCleaningMode()
        NSApp.terminate(nil)
    }

    func restartApp() {
        print("Restart CleanLock requested.")
        stopCleaningMode()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]

        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            model.inlineMessage = "CleanLock could not restart. Quit and reopen it manually."
            print("Restart CleanLock failed: \(error.localizedDescription)")
            showMainWindow()
        }
    }

    func refreshPermissionStatus() {
        permissionManager.logPermissionStatus()
        model.permissionStatus = permissionManager.status
        if model.permissionStatus.allGranted,
           model.inlineMessage == "Enable permissions to start Cleaning"
            || model.inlineMessage == "Enable permissions below to start Cleaning Mode." {
            model.inlineMessage = nil
        }
    }

    func openAccessibilitySettings() {
        permissionManager.openAccessibilitySettings()
        refreshPermissionStatus()
    }

    func openInputMonitoringSettings() {
        permissionManager.openInputMonitoringSettings()
        refreshPermissionStatus()
    }

    func checkForUpdates() {
        checkForUpdates(isAutomatic: false)
    }

    func checkForUpdates(isAutomatic: Bool) {
        print("Manual update check started.")
        model.updateCheckStatus = .checking
        model.updateStatusText = UpdateCheckStatus.checking.rawValue
        model.latestReleaseURL = nil

        Task { [weak self] in
            guard let self else { return }
            let result = await UpdateChecker.checkLatestRelease(currentVersion: AppInfo.version)

            await MainActor.run {
                switch result {
                case .updateAvailable(let release):
                    self.model.updateCheckStatus = .idle
                    self.model.updateStatusText = "Update available: \(release.tagName)"
                    self.model.latestReleaseURL = release.htmlURL
                    print("Manual update check finished: update available \(release.tagName).")
                case .upToDate:
                    self.model.updateCheckStatus = .upToDate
                    self.model.updateStatusText = UpdateCheckStatus.upToDate.rawValue
                    print("Manual update check finished: up to date.")
                case .noPublicRelease:
                    self.model.updateCheckStatus = .noPublicRelease
                    self.model.updateStatusText = UpdateCheckStatus.noPublicRelease.rawValue
                    print("Manual update check finished: no public release found yet.")
                case .failed:
                    self.model.updateCheckStatus = .failed
                    self.model.updateStatusText = UpdateCheckStatus.failed.rawValue
                    print("Manual update check failed.")
                }
                UserDefaults.standard.set(Date(), forKey: PreferencesKeys.lastUpdateCheckDate)
            }
        }
    }

    func openLatestReleasePage() {
        guard let url = model.latestReleaseURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openWebsite() {
        guard let url = AppInfo.websiteURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openRepository() {
        guard let url = AppInfo.repositoryURL else { return }
        NSWorkspace.shared.open(url)
    }

    func updateAutomaticUpdatePreference(_ isEnabled: Bool) {
        model.updatesAutomaticallyEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: PreferencesKeys.automaticUpdateChecksEnabled)
        print("Automatic update checks \(isEnabled ? "enabled" : "disabled").")
        if isEnabled {
            scheduleAutomaticUpdateCheckIfNeeded()
        }
    }

    func updateStartAtLoginPreference(_ isEnabled: Bool) {
        do {
            try LaunchAtLoginManager.setEnabled(isEnabled)
            model.startAtLoginEnabled = LaunchAtLoginManager.isEnabled
            model.startAtLoginStatusText = isEnabled ? "CleanLock will start at login." : nil
        } catch {
            model.startAtLoginEnabled = LaunchAtLoginManager.isEnabled
            model.startAtLoginStatusText = "Start at login registration failed. This may require running CleanLock from its app bundle."
            print("Start at login registration failed: \(error.localizedDescription)")
        }
    }

    private func registerDefaultPreferences() {
        UserDefaults.standard.register(defaults: [
            PreferencesKeys.cleaningDuration: 60,
            PreferencesKeys.showMenuBarIcon: true,
            PreferencesKeys.emergencyShortcutKeyCodes: [55, 54],
            PreferencesKeys.overlayStyle: OverlayStyle.default.rawValue,
            PreferencesKeys.overlayOpacity: 0.35,
            PreferencesKeys.overlayTintColorHex: "#000000",
            PreferencesKeys.automaticUpdateChecksEnabled: true
        ])
    }

    private func configureMenuBarVisibility(_ isEnabled: Bool) {
        UserDefaults.standard.set(isEnabled, forKey: PreferencesKeys.showMenuBarIcon)
        if isEnabled {
            if menuBarController == nil {
                menuBarController = MenuBarController(appDelegate: self)
            }
            menuBarController?.setCleaningActive(isCleaning)
        } else {
            menuBarController?.invalidate()
            menuBarController = nil
        }
    }

    private func showOverlay(shortcut: EmergencyShortcut) {
        let view = CleaningOverlayView(
            remainingSeconds: remainingSeconds,
            autoUnlockEnabled: remainingSeconds > 0,
            unlockShortcutText: shortcut.displayName,
            appearance: OverlayAppearance.load()
        )
        overlayWindow = CleaningOverlayWindow(rootView: view)
        overlayWindow?.show()
    }

    private func closeOverlayWindows() {
        overlayWindow?.close()
        overlayWindow = nil
    }

    private func refreshStartAtLoginStatus() {
        model.startAtLoginEnabled = LaunchAtLoginManager.isEnabled
    }

    private func scheduleAutomaticUpdateCheckIfNeeded() {
        guard UserDefaults.standard.bool(forKey: PreferencesKeys.automaticUpdateChecksEnabled) else { return }

        if let lastCheck = UserDefaults.standard.object(forKey: PreferencesKeys.lastUpdateCheckDate) as? Date,
           Date().timeIntervalSince(lastCheck) < 86_400 {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.model.updatesAutomaticallyEnabled else { return }
            print("Automatic update check started.")
            self.checkForUpdates(isAutomatic: true)
        }
    }

    private func startCountdown() {
        updateOverlay()
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.remainingSeconds -= 1
            if self.remainingSeconds <= 0 {
                self.stopCleaningMode(reason: .timer)
            } else {
                self.updateOverlay()
            }
        }
    }

    private func updateOverlay() {
        overlayWindow?.updateRemainingSeconds(remainingSeconds)
    }
}

enum PreferencesKeys {
    static let cleaningDuration = "cleaningDuration"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let emergencyShortcutKeyCodes = "emergencyShortcutKeyCodes"
    static let overlayStyle = "overlayStyle"
    static let overlayOpacity = "overlayOpacity"
    static let overlayTintColorHex = "overlayTintColorHex"
    static let customOverlayImagePath = "customOverlayImagePath"
    static let automaticUpdateChecksEnabled = "automaticUpdateChecksEnabled"
    static let lastUpdateCheckDate = "lastUpdateCheckDate"
}

private enum CleaningStopReason {
    case manual
    case timer
    case emergencyShortcut
}

extension UserDefaults {
    static func sanitizeCleaningDuration(_ value: Int) -> Int {
        min(max(value, 0), 3600)
    }

    func sanitizedCleaningDuration() -> Int {
        Self.sanitizeCleaningDuration(integer(forKey: PreferencesKeys.cleaningDuration))
    }
}
