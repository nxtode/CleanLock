import SwiftUI
import AppKit

private enum MainTab: String, CaseIterable, Identifiable {
    case general = "General"
    case permissions = "Permissions"
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
        VStack(alignment: .center, spacing: 16) {
            Picker("Section", selection: $selectedTab) {
                ForEach(MainTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 760)

            Divider()
                .frame(maxWidth: 760)

            ScrollView {
                selectedContent
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 560)
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
        case .aboutSupport:
            aboutSupportTab
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
                .frame(maxWidth: .infinity, alignment: .leading)
            statusSection
            cleaningModeSection
            unlockShortcutSection
            overlayAppearanceSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusSection: some View {
        sectionCard {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cleaningModeSection: some View {
        sectionCard("Cleaning Mode") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Auto-unlock after")
                    TextField("60", text: $durationText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 84)
                        .onSubmit(saveDuration)
                    Text("seconds")
                        .foregroundStyle(.secondary)
                    Spacer()
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var unlockShortcutSection: some View {
        sectionCard("Unlock Shortcut") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button(action: beginRecording) {
                        HStack(spacing: 8) {
                            keyCaps(for: isRecordingShortcut ? liveShortcut : shortcut)
                            Spacer()
                            if isRecordingShortcut {
                                Text("Recording")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .frame(maxWidth: .infinity)
                        .background(.quaternary.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: resetShortcutToDefault) {
                        Image(systemName: "xmark.circle.fill")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to default")
                }
                .frame(maxWidth: .infinity)

                Text("Use at least 2 keys. This shortcut only exits Cleaning Mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isRecordingShortcut {
                    Text("Hold the desired keys, then release them to apply. Escape cancels recording.")
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var overlayAppearanceSection: some View {
        sectionCard("Overlay Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Overlay style", selection: overlayStyleBinding) {
                    ForEach(OverlayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)

                if currentOverlayStyle == .transparent {
                    VStack(alignment: .leading, spacing: 6) {
                        Slider(value: opacityBinding, in: 0.10...0.70)
                        Text("Opacity: \(Int(overlayOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(maxWidth: .infinity)

                    if let customOverlayImageWarning {
                        Text(customOverlayImageWarning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text("Transparent overlay lets you keep watching the screen while input is locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var permissionsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            sectionCard("Accessibility") {
                permissionRow(
                    title: "Accessibility",
                    granted: model.permissionStatus.accessibilityGranted,
                    actionTitle: "Open Accessibility Settings",
                    action: actions.openAccessibilitySettings
                )
            }

            sectionCard("Input Monitoring") {
                permissionRow(
                    title: "Input Monitoring",
                    granted: model.permissionStatus.inputMonitoringGranted,
                    actionTitle: "Open Input Monitoring Settings",
                    action: actions.openInputMonitoringSettings
                )
            }

            sectionCard("Permission Instructions") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(permissionHelpText)
                        .foregroundStyle(.secondary)

                    Button("Refresh Permission Status", action: actions.refreshPermissions)

                    Text("After enabling permissions in System Settings, quit and reopen CleanLock if macOS asks you to.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var aboutSupportTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionCard("About") {
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("CleanLock helps you safely lock your keyboard and trackpad while cleaning your Mac.")
                        .foregroundStyle(.secondary)

                    Text(AppInfo.copyright)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            sectionCard("Updates") {
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
                        Spacer()
                    }

                    if model.latestReleaseURL != nil {
                        Button("Open Release Page", action: actions.openLatestReleasePage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            sectionCard("Repository") {
                HStack {
                    Button("GitHub Repository", action: actions.openRepository)
                        .disabled(AppInfo.repositoryURL == nil)
                    if AppInfo.websiteURL != nil {
                        Button("Website", action: actions.openWebsite)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func sectionCard<Content: View>(_ title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            content()
                .padding(.top, title == nil ? 0 : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            if let title {
                Text(title)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity)
    }

    private func keyCaps(for shortcut: EmergencyShortcut) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(shortcut.displaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .frame(minWidth: 30, minHeight: 26)
                    .background(.background.opacity(0.65))
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

    private func resetShortcutToDefault() {
        EmergencyShortcut.resetToDefault()
        shortcut = .defaultShortcut
        shortcutError = nil
        print("Shortcut reset.")
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
