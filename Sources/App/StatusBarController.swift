import AppKit
import SmartScreenShotCore
import UniformTypeIdentifiers

/// Manages the NSStatusItem and its dropdown menu.
final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let pipeline: PipelineController
    private let preferencesStore: PreferencesStore
    private let licenseManager: LicenseManager
    private var preferencesWindow: PreferencesWindow?

    init(pipeline: PipelineController, preferencesStore: PreferencesStore, licenseManager: LicenseManager) {
        self.pipeline = pipeline
        self.preferencesStore = preferencesStore
        self.licenseManager = licenseManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        setupButton()
        buildMenu()
    }

    // MARK: - Setup

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: "SmartScreenShot"
            )
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Enable / Disable
        let toggleItem = NSMenuItem(
            title: pipeline.state == .running ? "Disable" : "Enable",
            action: #selector(togglePipeline(_:)),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        // Re-analyze last
        let reanalyzeItem = NSMenuItem(
            title: "Re-analyze Last Screenshot",
            action: #selector(reanalyzeLast(_:)),
            keyEquivalent: ""
        )
        reanalyzeItem.target = self
        reanalyzeItem.tag = 100
        menu.addItem(reanalyzeItem)

        // Batch rename
        let batchItem = NSMenuItem(
            title: "Batch Rename Screenshots\u{2026}",
            action: #selector(batchRename(_:)),
            keyEquivalent: ""
        )
        batchItem.target = self
        menu.addItem(batchItem)

        // Open folder
        let openFolderItem = NSMenuItem(
            title: "Open Screenshot Folder",
            action: #selector(openFolder(_:)),
            keyEquivalent: ""
        )
        openFolderItem.target = self
        menu.addItem(openFolderItem)

        menu.addItem(.separator())

        // License status (non-clickable)
        let licenseStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        licenseStatusItem.tag = 300
        menu.addItem(licenseStatusItem)

        // Buy button (hidden when licensed)
        let buyItem = NSMenuItem(
            title: "Buy Full Version ($4.99)",
            action: #selector(openPurchaseLink(_:)),
            keyEquivalent: ""
        )
        buyItem.target = self
        buyItem.tag = 301
        menu.addItem(buyItem)

        menu.addItem(.separator())

        // Preferences
        let prefsItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit SmartScreenShot",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Update toggle title
        if let toggleItem = menu.items.first {
            toggleItem.title = pipeline.state == .running ? "Disable" : "Enable"
        }
        // Update re-analyze availability
        if let reanalyzeItem = menu.item(withTag: 100) {
            reanalyzeItem.isEnabled = pipeline.lastDestinationURL != nil
        }
        // Update license status
        if let statusMenuItem = menu.item(withTag: 300) {
            switch licenseManager.status {
            case .trial(let remaining):
                statusMenuItem.title = "Trial: \(remaining)/\(LicenseManager.dailyLimit) remaining today"
            case .licensed:
                statusMenuItem.title = "Licensed \u{2713}"
            }
        }
        // Show/hide buy button
        if let buyItem = menu.item(withTag: 301) {
            buyItem.isHidden = licenseManager.isLicensed
        }
    }

    // MARK: - Actions

    @objc private func togglePipeline(_ sender: NSMenuItem) {
        if pipeline.state == .running {
            pipeline.stop()
            preferencesStore.isEnabled = false
        } else {
            pipeline.start()
            preferencesStore.isEnabled = true
        }
    }

    @objc private func reanalyzeLast(_ sender: NSMenuItem) {
        pipeline.reanalyzeLast()
    }

    @objc private func batchRename(_ sender: NSMenuItem) {
        // Check trial before opening panel
        if !licenseManager.isLicensed && licenseManager.remainingToday == 0 {
            showTrialLimitAlert()
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png, .jpeg]
        panel.message = "Select screenshots to rename"
        panel.prompt = "Rename"
        panel.directoryURL = pipeline.screenshotFolder

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let urls = panel.urls

        // For trial users, cap at remaining count
        let allowedCount: Int
        if licenseManager.isLicensed {
            allowedCount = urls.count
        } else {
            let remaining = licenseManager.remainingToday
            allowedCount = min(urls.count, remaining)
            if allowedCount < urls.count {
                let alert = NSAlert()
                alert.messageText = "Trial Limit"
                alert.informativeText = "You have \(allowedCount) rename\(allowedCount == 1 ? "" : "s") remaining today. Only the first \(allowedCount) of \(urls.count) files will be renamed."
                alert.addButton(withTitle: "Continue")
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() != .alertFirstButtonReturn { return }
            }
        }

        let filesToRename = Array(urls.prefix(allowedCount))
        let namer = VisionOnlyNamer()
        let store = CaptureContextStore()
        let engine = RenameEngine(namer: namer, store: store)

        Task {
            var succeeded = 0
            for url in filesToRename {
                guard licenseManager.consumeRename() else { break }
                if let _ = await engine.processManual(file: url) {
                    succeeded += 1
                }
            }
            print("[BatchRename] Renamed \(succeeded)/\(urls.count) files")
        }
    }

    @objc private func openFolder(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(pipeline.screenshotFolder)
    }

    @objc private func openPurchaseLink(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(LicenseManager.purchaseURL)
    }

    private func showTrialLimitAlert() {
        let alert = NSAlert()
        alert.messageText = "Daily Limit Reached"
        alert.informativeText = "You\u{2019}ve used all \(LicenseManager.dailyLimit) free renames for today. Purchase SmartScreenShot for unlimited renames."
        alert.addButton(withTitle: "Buy ($4.99)")
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(LicenseManager.purchaseURL)
        }
    }

    @objc private func openPreferences(_ sender: NSMenuItem) {
        if preferencesWindow == nil {
            let pw = PreferencesWindow(preferencesStore: preferencesStore, licenseManager: licenseManager)
            pw.onFolderChanged = { [weak self] in
                guard let self, self.pipeline.state == .running else { return }
                self.pipeline.stop()
                self.pipeline.start()
            }
            pw.onHotkeyChanged = { [weak self] in
                self?.pipeline.restartHotkeyMonitor()
            }
            pw.onLicenseChanged = { [weak self] in
                // Force window reconstruction on next open to reflect license state
                self?.preferencesWindow = nil
            }
            preferencesWindow = pw
        }
        preferencesWindow?.showWindow()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}
