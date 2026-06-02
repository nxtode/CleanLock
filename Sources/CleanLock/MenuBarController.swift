import AppKit

final class MenuBarController {
    private var statusItem: NSStatusItem?
    private weak var appDelegate: AppDelegate?
    private let startItem = NSMenuItem(title: "Start Cleaning Mode", action: #selector(startCleaningMode), keyEquivalent: "")

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        configureMenu()
        print("Menu bar icon enabled.")
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        print("Menu bar icon disabled.")
    }

    func setCleaningActive(_ active: Bool) {
        startItem.title = active ? "Cleaning Mode Active" : "Start Cleaning Mode"
        startItem.isEnabled = !active
    }

    private func configureStatusItem() {
        guard let button = statusItem?.button else { return }
        let image = Bundle.main.url(forResource: "MenuBarIconTemplate", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "keyboard", accessibilityDescription: "CleanLock")
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = true
        button.image = image
        button.toolTip = "CleanLock"
    }

    private func configureMenu() {
        let menu = NSMenu()
        startItem.target = self

        let openItem = NSMenuItem(title: "Open CleanLock", action: #selector(openCleanLock), keyEquivalent: "")
        openItem.target = self

        let quitItem = NSMenuItem(title: "Quit CleanLock", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        menu.addItem(startItem)
        menu.addItem(openItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem?.menu = menu
    }

    @objc private func startCleaningMode() {
        appDelegate?.startCleaningMode()
    }

    @objc private func openCleanLock() {
        appDelegate?.showMainWindow()
    }

    @objc private func quit() {
        appDelegate?.quit()
    }
}
