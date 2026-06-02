import SwiftUI
import AppKit

private enum MainTab: String, CaseIterable, Identifiable {
    case general = "General"
    case permissions = "Permissions"
    case hotkey = "Hotkey"
    case aboutSupport = "About & Support"

    var id: String { rawValue }
}

struct MainView: View {
    @ObservedObject var model: CleanLockModel
    let actions: MainWindowActions

    @AppStorage(PreferencesKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(PreferencesKeys.overlayStyle) private var overlayStyleRaw = OverlayStyle.default.rawValue
    @AppStorage(PreferencesKeys.overlayOpacity) private var overlayOpacity = 0.35
    @AppStorage(PreferencesKeys.customOverlayImagePath) private var customOverlayImagePath = ""
    @State private var selectedTab: MainTab = .general
    @State private var durationText = ""
    @State private var shortcut = EmergencyShortcut.load()
    @State private var isRecordingShortcut = false
    @State private var heldKeyCodes: Set<Int64> = []
    @State private var recordedKeyCodes: Set<Int64> = []
    @State private var shortcutError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Section", selection: $selectedTab) {
                ForEach(MainTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Divider()

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            durationText = "\(UserDefaults.standard.sanitizedCleaningDuration())"
            shortcut = EmergencyShortcut.load()
            actions.refreshPermissions()
        }
        .onDisappear {
            saveDuration()
            cancelRecording()
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .permissions:
            permissionsTab
        case .hotkey:
            hotkeyTab
        case .aboutSupport:
            aboutSupportTab
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                statusSection

                GroupBox("Cleaning Mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Auto-unlock after")
                            TextField("60", text: $durationText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 84)
                                .onSubmit(saveDuration)
                            Text("seconds")
                                .foregroundStyle(.secondary)
                        }

                        Text("Set this to 0 to disable auto-unlock. Emergency unlock always remains available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    Toggle("Show CleanLock in menu bar", isOn: Binding(
                        get: { showMenuBarIcon },
                        set: { newValue in
                            showMenuBarIcon = newValue
                            actions.menuBarPreferenceChanged(newValue)
                        }
                    ))

                    Toggle("Start CleanLock at login", isOn: Binding(
                        get: { model.startAtLoginEnabled },
                        set: { newValue in
                            model.startAtLoginEnabled = newValue
                            actions.updateStartAtLoginPreference(newValue)
                        }
                    ))

                    if let startAtLoginStatusText = model.startAtLoginStatusText {
                        Text(startAtLoginStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

                overlayAppearanceSection

                Text("Cleaning Mode covers every connected display, blocks keyboard and trackpad input, and exits through the configured hotkey or timer.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var overlayAppearanceSection: some View {
        GroupBox("Overlay appearance") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Overlay style", selection: overlayStyleBinding) {
                    ForEach(OverlayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                if currentOverlayStyle == .transparent {
                    VStack(alignment: .leading, spacing: 6) {
                        Slider(value: opacityBinding, in: 0.10...0.70)
                        Text("Opacity: \(Int(overlayOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if currentOverlayStyle == .customImage {
                    HStack {
                        Text(selectedImageName)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Choose Image", action: chooseCustomOverlayImage)
                        Button("Clear Custom Image", action: clearCustomOverlayImage)
                            .disabled(customOverlayImagePath.isEmpty)
                    }

                    if customOverlayImageWarning != nil {
                        Text(customOverlayImageWarning!)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text("Transparent overlay lets you keep watching the screen while input is locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title.bold())

            Text(permissionHelpText)
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(spacing: 12) {
                    permissionRow(
                        title: "Accessibility",
                        granted: model.permissionStatus.accessibilityGranted,
                        actionTitle: "Open Accessibility Settings",
                        action: actions.openAccessibilitySettings
                    )

                    Divider()

                    permissionRow(
                        title: "Input Monitoring",
                        granted: model.permissionStatus.inputMonitoringGranted,
                        actionTitle: "Open Input Monitoring Settings",
                        action: actions.openInputMonitoringSettings
                    )
                }
                .padding(.top, 4)
            }

            Button("Refresh Permission Status", action: actions.refreshPermissions)

            Text("After enabling permissions in System Settings, quit and reopen CleanLock if macOS asks you to.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private var hotkeyTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hotkey")
                .font(.title.bold())

            Text("This shortcut only exits Cleaning Mode. It does not quit CleanLock.")
                .foregroundStyle(.secondary)

            GroupBox("Unlock shortcut setting") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        keyCaps(for: isRecordingShortcut ? liveShortcut : shortcut)
                        Spacer()
                        Button(isRecordingShortcut ? "Recording..." : "Record Shortcut") {
                            beginRecording()
                        }
                        Button("Reset to Default") {
                            EmergencyShortcut.resetToDefault()
                            shortcut = .defaultShortcut
                            shortcutError = nil
                            print("Shortcut reset.")
                        }
                    }

                    Text("Use at least 2 keys.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isRecordingShortcut {
                        Text("Hold the desired keys, then release them to apply.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ShortcutRecorderView(
                            onEvent: recordEvent,
                            onDisappear: cancelRecording
                        )
                        .frame(width: 1, height: 1)
                    }

                    if let shortcutError {
                        Text(shortcutError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.top, 4)
            }

            Spacer()
        }
    }

    private var aboutSupportTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("About") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            appIcon
                            VStack(alignment: .leading, spacing: 6) {
                                Text(AppInfo.name)
                                    .font(.title.bold())
                                Text("Version: \(AppInfo.version)")
                                Text("Build: \(AppInfo.build)")
                                Text("Bundle identifier: \(AppInfo.bundleIdentifier)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("CleanLock helps you safely lock your keyboard and trackpad while cleaning your Mac.")
                            .foregroundStyle(.secondary)

                        Text(AppInfo.copyright)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                GroupBox("Updates") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Automatically check for updates", isOn: Binding(
                            get: { model.updatesAutomaticallyEnabled },
                            set: { newValue in
                                model.updatesAutomaticallyEnabled = newValue
                                actions.updateAutomaticUpdatePreference(newValue)
                            }
                        ))

                        HStack {
                            Button("Check for Updates", action: actions.checkForUpdates)
                                .disabled(model.updateCheckStatus == .checking)
                            Text(model.updateStatusText)
                                .foregroundStyle(.secondary)
                        }

                        if model.latestReleaseURL != nil {
                            Button("Open Release Page", action: actions.openLatestReleasePage)
                        }

                        Text("Manual update checking uses GitHub Releases. Automatic updates via Sparkle are planned later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                GroupBox("Support / Donate") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("If CleanLock helps you, you can support development.")
                            .foregroundStyle(.secondary)

                        if AppInfo.githubSponsorsURL != nil {
                            Button("Open GitHub Sponsors", action: actions.openDonationLink)
                        } else {
                            Text("GitHub Sponsors coming soon.")
                                .font(.headline)
                            Text("Future placeholder: \(AppInfo.futureGitHubSponsorsURL?.absoluteString ?? "not configured")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }

                HStack {
                    Button("Website", action: actions.openWebsite)
                        .disabled(AppInfo.websiteURL == nil)
                    Button("GitHub Repository", action: actions.openRepository)
                        .disabled(AppInfo.repositoryURL == nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("CleanLock")
                    .font(.system(size: 34, weight: .bold))
            }

            Text("Lock your keyboard and trackpad while cleaning your Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Current status")
                        .font(.headline)
                    Spacer()
                    Text(model.statusText)
                        .font(.headline)
                        .foregroundStyle(statusColor)
                }

                Button(action: {
                    saveDuration()
                    actions.startCleaning()
                }) {
                    Text(model.isCleaning ? "Cleaning Mode Active" : "Start Cleaning Mode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isCleaning || model.isStoppingCleaningMode || !model.permissionStatus.allGranted)

                if let inlineMessage = model.inlineMessage {
                    Text(inlineMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !model.permissionStatus.allGranted {
                    Text("Enable permissions below to start Cleaning Mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    private func permissionRow(title: String, granted: Bool, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(granted ? "Granted" : "Required")
                .foregroundStyle(granted ? Color.green : Color.red)
            if granted {
                Button("Granted") {}
                    .disabled(true)
            } else {
                Button(actionTitle, action: action)
            }
        }
    }

    private func keyCaps(for shortcut: EmergencyShortcut) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(shortcut.displaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(minWidth: 32, minHeight: 30)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var appIcon: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage)
            .resizable()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusColor: Color {
        if model.isCleaning {
            return .orange
        }
        return model.permissionStatus.allGranted ? .green : .red
    }

    private var permissionHelpText: String {
        model.permissionStatus.allGranted
            ? "Everything is ready. You can start Cleaning Mode."
            : "Enable permissions below to start Cleaning Mode."
    }

    private var liveShortcut: EmergencyShortcut {
        EmergencyShortcut(keyCodes: recordedKeyCodes.isEmpty ? heldKeyCodes : recordedKeyCodes)
    }

    private var currentOverlayStyle: OverlayStyle {
        OverlayStyle(rawValue: overlayStyleRaw) ?? .default
    }

    private var selectedImageName: String {
        guard !customOverlayImagePath.isEmpty else { return "No image selected" }
        return URL(fileURLWithPath: customOverlayImagePath).lastPathComponent
    }

    private var customOverlayImageWarning: String? {
        guard currentOverlayStyle == .customImage, !customOverlayImagePath.isEmpty else { return nil }
        return FileManager.default.fileExists(atPath: customOverlayImagePath) ? nil : "Selected image is missing. CleanLock will use the default overlay."
    }

    private var overlayStyleBinding: Binding<OverlayStyle> {
        Binding(
            get: { currentOverlayStyle },
            set: { newValue in
                overlayStyleRaw = newValue.rawValue
                print("Overlay style changed: \(newValue.title)")
            }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { overlayOpacity },
            set: { newValue in
                overlayOpacity = min(max(newValue, 0.10), 0.70)
                print("Transparent overlay opacity changed: \(overlayOpacity)")
            }
        )
    }

    private func chooseCustomOverlayImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let copiedURL = try OverlayImageStore.copyToApplicationSupport(url)
            customOverlayImagePath = copiedURL.path
            overlayStyleRaw = OverlayStyle.customImage.rawValue
            print("Custom overlay image selected: \(copiedURL.path)")
        } catch {
            print("Custom overlay image fallback: failed to copy image: \(error.localizedDescription)")
        }
    }

    private func clearCustomOverlayImage() {
        customOverlayImagePath = ""
        print("Custom overlay image cleared.")
    }

    private func saveDuration() {
        let sanitized = UserDefaults.sanitizeCleaningDuration(Int(durationText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 60)
        durationText = "\(sanitized)"
        UserDefaults.standard.set(sanitized, forKey: PreferencesKeys.cleaningDuration)
    }

    private func beginRecording() {
        heldKeyCodes = []
        recordedKeyCodes = []
        shortcutError = nil
        isRecordingShortcut = true
        print("Shortcut recording started.")
    }

    private func recordEvent(_ event: NSEvent) {
        let keyCode = Int64(event.keyCode)

        if event.type == .keyDown, keyCode == 53 {
            cancelRecording()
            return
        }

        switch event.type {
        case .keyDown:
            heldKeyCodes.insert(keyCode)
            recordedKeyCodes.insert(keyCode)
        case .keyUp:
            heldKeyCodes.remove(keyCode)
        case .flagsChanged:
            if heldKeyCodes.contains(keyCode) {
                heldKeyCodes.remove(keyCode)
            } else {
                heldKeyCodes.insert(keyCode)
                recordedKeyCodes.insert(keyCode)
            }
        default:
            break
        }

        print("Shortcut live keys changed: \(EmergencyShortcut(keyCodes: recordedKeyCodes).displayName)")

        if heldKeyCodes.isEmpty, !recordedKeyCodes.isEmpty {
            finishRecording()
        }
    }

    private func finishRecording() {
        let newShortcut = EmergencyShortcut(keyCodes: recordedKeyCodes)
        print("Shortcut recorded on release: \(newShortcut.displayName)")

        guard !newShortcut.isReserved else {
            shortcutError = "That shortcut is reserved by macOS or CleanLock. Choose another shortcut."
            heldKeyCodes = []
            recordedKeyCodes = []
            isRecordingShortcut = false
            print("Shortcut rejected.")
            return
        }

        newShortcut.save()
        shortcut = newShortcut
        heldKeyCodes = []
        recordedKeyCodes = []
        isRecordingShortcut = false
        shortcutError = nil
        print("Shortcut saved: \(newShortcut.displayName)")
    }

    private func cancelRecording() {
        guard isRecordingShortcut else { return }
        heldKeyCodes = []
        recordedKeyCodes = []
        isRecordingShortcut = false
        print("Shortcut recording cancelled.")
    }
}
