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
    @AppStorage(PreferencesKeys.overlayTintColorHex) private var overlayTintColorHex = "#000000"
    @AppStorage(PreferencesKeys.customOverlayImagePath) private var customOverlayImagePath = ""
    @State private var selectedTab: MainTab = .general
    @State private var durationText = ""
    @State private var shortcut = EmergencyShortcut.load()
    @State private var isRecordingShortcut = false
    @State private var heldKeyCodes: Set<Int64> = []
    @State private var recordedKeyCodes: Set<Int64> = []
    @State private var shortcutError: String?
    @State private var shortcutEventMonitor: Any?

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Picker("Section", selection: $selectedTab) {
                ForEach(MainTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 500)
            .frame(maxWidth: .infinity)

            Divider()
                .frame(maxWidth: 500)

            ScrollView {
                selectedContent
                    .frame(maxWidth: 500, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(minWidth: 460, maxWidth: 540, minHeight: 560)
        .onAppear {
            durationText = "\(UserDefaults.standard.sanitizedCleaningDuration())"
            shortcut = EmergencyShortcut.load()
            actions.refreshPermissions()
        }
        .onDisappear {
            saveDuration()
            cancelRecording()
            stopShortcutMonitoring()
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
                    Text("Status")
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
                    Text(model.isCleaning ? "Cleaning Mode Active" : "Lock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(model.isCleaning || model.isStoppingCleaningMode || !model.permissionStatus.allGranted)

                if let inlineMessage = model.inlineMessage {
                    Text(inlineMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !model.permissionStatus.allGranted {
                    Text("Enable permissions to start Cleaning")
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
                        guard !model.startAtLoginEnabled || newValue else {
                            showMenuBarIcon = true
                            actions.menuBarPreferenceChanged(true)
                            return
                        }
                        showMenuBarIcon = newValue
                        actions.menuBarPreferenceChanged(newValue)
                    }
                ))
                .disabled(model.startAtLoginEnabled)

                Toggle("Start CleanLock at login", isOn: Binding(
                    get: { model.startAtLoginEnabled },
                    set: { newValue in
                        if newValue {
                            showMenuBarIcon = true
                            actions.menuBarPreferenceChanged(true)
                        }
                        model.startAtLoginEnabled = newValue
                        actions.updateStartAtLoginPreference(newValue)
                    }
                ))

                Text("Start at Login keeps CleanLock available from the menu bar without opening the main window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                ZStack(alignment: .topTrailing) {
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
                        .padding(.leading, 10)
                        .padding(.trailing, shouldShowShortcutReset ? 34 : 10)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(.quaternary.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    if shouldShowShortcutReset {
                        Button(action: resetShortcutToDefault) {
                            Text("x")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("Reset to default")
                        .padding(.top, 7)
                        .padding(.trailing, 8)
                    }
                }
                .frame(maxWidth: .infinity)

                Text("Use at least 2 keys")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isRecordingShortcut {
                    Text("Hold the desired keys, then release them to apply. Escape cancels recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                if currentOverlayStyle == .transparent {
                    VStack(alignment: .leading, spacing: 10) {
                        Slider(value: opacityBinding, in: 0.10...0.70)
                        Text("Opacity: \(Int(overlayOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ColorPicker("Tint", selection: overlayTintColorBinding, supportsOpacity: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    granted: model.permissionStatus.inputMonitoringGranted && model.permissionStatus.inputEventTapAvailable,
                    actionTitle: "Open Input Monitoring Settings",
                    action: actions.openInputMonitoringSettings
                )
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(permissionHelpText)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("Refresh Permission Status", action: actions.refreshPermissions)
                        Button("Restart App", action: actions.restartApp)
                        Spacer()
                    }

                    Text("After enabling permissions in System Settings, refresh status. Restart CleanLock if macOS asks you to.")
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
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
                .padding(20)
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
        if model.permissionStatus.allGranted {
            return "Everything is ready. You can start Cleaning."
        }

        if model.permissionStatus.inputMonitoringGranted && !model.permissionStatus.inputEventTapAvailable {
            return "Input Monitoring is enabled, but macOS is not allowing CleanLock to create the input monitor yet. Restart CleanLock, or remove and re-add it in System Settings."
        }

        return "Enable permissions to start Cleaning"
    }

    private var liveShortcut: EmergencyShortcut {
        EmergencyShortcut(keyCodes: recordedKeyCodes.isEmpty ? heldKeyCodes : recordedKeyCodes)
    }

    private var currentOverlayStyle: OverlayStyle {
        OverlayStyle(rawValue: overlayStyleRaw) ?? .default
    }

    private var shouldShowShortcutReset: Bool {
        !isRecordingShortcut && shortcut != .defaultShortcut
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

    private var overlayTintColorBinding: Binding<Color> {
        Binding(
            get: { Color.cleanLockHex(overlayTintColorHex) },
            set: { newValue in
                overlayTintColorHex = newValue.cleanLockHexString
                print("Transparent overlay tint changed: \(overlayTintColorHex)")
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
        stopShortcutMonitoring()
        heldKeyCodes = []
        recordedKeyCodes = []
        shortcutError = nil
        isRecordingShortcut = true
        startShortcutMonitoring()
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
            stopShortcutMonitoring()
            heldKeyCodes = []
            recordedKeyCodes = []
            isRecordingShortcut = false
            print("Shortcut rejected.")
            return
        }

        newShortcut.save()
        shortcut = newShortcut
        stopShortcutMonitoring()
        heldKeyCodes = []
        recordedKeyCodes = []
        isRecordingShortcut = false
        shortcutError = nil
        print("Shortcut saved: \(newShortcut.displayName)")
    }

    private func cancelRecording() {
        guard isRecordingShortcut else { return }
        stopShortcutMonitoring()
        heldKeyCodes = []
        recordedKeyCodes = []
        isRecordingShortcut = false
        print("Shortcut recording cancelled.")
    }

    private func startShortcutMonitoring() {
        guard shortcutEventMonitor == nil else { return }
        shortcutEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { event in
            if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type) {
                cancelRecording()
                return event
            }

            recordEvent(event)
            return nil
        }
    }

    private func stopShortcutMonitoring() {
        if let shortcutEventMonitor {
            NSEvent.removeMonitor(shortcutEventMonitor)
            self.shortcutEventMonitor = nil
            print("Shortcut recording monitor removed.")
        }
    }
}

private extension Color {
    static func cleanLockHex(_ value: String) -> Color {
        var hex = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }

        guard hex.count == 6, let rgb = Int(hex, radix: 16) else {
            return .black
        }

        let red = Double((rgb >> 16) & 0xff) / 255.0
        let green = Double((rgb >> 8) & 0xff) / 255.0
        let blue = Double(rgb & 0xff) / 255.0
        return Color(red: red, green: green, blue: blue)
    }

    var cleanLockHexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let red = Int(round(nsColor.redComponent * 255))
        let green = Int(round(nsColor.greenComponent * 255))
        let blue = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
