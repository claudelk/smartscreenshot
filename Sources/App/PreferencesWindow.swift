import AppKit
import SmartScreenShotCore

/// Programmatic preferences window — no storyboard, no NIB.
final class PreferencesWindow: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let preferencesStore: PreferencesStore
    private let licenseManager: LicenseManager
    private let launchAgent = LaunchAtLogin()
    private var folderLabel: NSTextField?
    private var licenseKeyField: NSTextField?
    private var licenseStatusLabel: NSTextField?
    /// Called when the screenshot folder changes so the pipeline can restart.
    var onFolderChanged: (() -> Void)?
    /// Called when the hotkey enabled state changes so the pipeline can restart the monitor.
    var onHotkeyChanged: (() -> Void)?
    /// Called when the license state changes so the window can be reconstructed.
    var onLicenseChanged: (() -> Void)?

    init(preferencesStore: PreferencesStore, licenseManager: LicenseManager) {
        self.preferencesStore = preferencesStore
        self.licenseManager = licenseManager
        super.init()
    }

    func showWindow() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "SmartScreenShot Preferences"
        w.center()
        w.delegate = self
        w.isReleasedWhenClosed = false

        let content = NSView(frame: w.contentView!.bounds)
        content.autoresizingMask = [.width, .height]

        var y: CGFloat = 375

        // --- License ---
        content.addSubview(makeLabel("License:", at: y))

        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 160, y: y, width: 280, height: 20)
        statusLabel.font = .systemFont(ofSize: 12)
        self.licenseStatusLabel = statusLabel
        updateLicenseStatusLabel()
        content.addSubview(statusLabel)

        y -= 30

        if !licenseManager.isLicensed {
            let keyField = NSTextField(frame: NSRect(x: 20, y: y, width: 310, height: 24))
            keyField.placeholderString = "Paste license key (UUID)"
            keyField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            self.licenseKeyField = keyField
            content.addSubview(keyField)

            let activateButton = NSButton(title: "Activate", target: self, action: #selector(activateLicense(_:)))
            activateButton.bezelStyle = .rounded
            activateButton.frame = NSRect(x: 340, y: y - 2, width: 100, height: 28)
            content.addSubview(activateButton)

            y -= 30

            let buyButton = NSButton(title: "Buy License ($4.99)", target: self, action: #selector(openPurchase(_:)))
            buyButton.bezelStyle = .rounded
            buyButton.frame = NSRect(x: 20, y: y, width: 160, height: 28)
            content.addSubview(buyButton)

            y -= 15
        }

        y -= 20

        // --- Screenshot Folder ---
        content.addSubview(makeLabel("Save screenshots to:", at: y))

        let folderPath = NSTextField(labelWithString: preferencesStore.screenshotFolder.path)
        folderPath.frame = NSRect(x: 160, y: y, width: 200, height: 20)
        folderPath.font = .systemFont(ofSize: 11)
        folderPath.textColor = .secondaryLabelColor
        folderPath.lineBreakMode = .byTruncatingMiddle
        self.folderLabel = folderPath
        content.addSubview(folderPath)

        let chooseButton = NSButton(title: "Choose\u{2026}", target: self, action: #selector(chooseFolder(_:)))
        chooseButton.bezelStyle = .rounded
        chooseButton.frame = NSRect(x: 365, y: y - 4, width: 75, height: 28)
        content.addSubview(chooseButton)

        // Reset button — only shown when a custom folder is set
        let resetButton = NSButton(title: "Reset", target: self, action: #selector(resetFolder(_:)))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 365, y: y - 30, width: 75, height: 24)
        resetButton.font = .systemFont(ofSize: 11)
        resetButton.isHidden = preferencesStore.screenshotFolderOverride == nil
        resetButton.tag = 200
        content.addSubview(resetButton)

        y -= 65

        // --- Naming Mode ---
        content.addSubview(makeLabel("Naming Mode:", at: y))

        let tierPopup = NSPopUpButton(frame: NSRect(x: 160, y: y - 2, width: 230, height: 26), pullsDown: false)
        tierPopup.addItems(withTitles: ["Standard"])

        let tier2 = NSMenuItem(title: "Enhanced (Apple Intelligence) \u{2014} Coming Soon", action: nil, keyEquivalent: "")
        tier2.isEnabled = false
        tierPopup.menu?.addItem(tier2)

        let tier3 = NSMenuItem(title: "Advanced (On-device AI) \u{2014} Coming Soon", action: nil, keyEquivalent: "")
        tier3.isEnabled = false
        tierPopup.menu?.addItem(tier3)

        tierPopup.selectItem(at: 0)
        content.addSubview(tierPopup)

        y -= 50

        // --- Launch at Login ---
        let launchCheckbox = NSButton(
            checkboxWithTitle: "Launch at login",
            target: self,
            action: #selector(launchAtLoginToggled(_:))
        )
        launchCheckbox.frame.origin = NSPoint(x: 20, y: y)
        launchCheckbox.state = preferencesStore.launchAtLogin ? .on : .off
        content.addSubview(launchCheckbox)

        y -= 40

        // --- Browser URL Capture (stubbed) ---
        let browserCheckbox = NSButton(
            checkboxWithTitle: "Capture browser URL in filename (experimental)",
            target: self,
            action: #selector(browserCaptureToggled(_:))
        )
        browserCheckbox.frame.origin = NSPoint(x: 20, y: y)
        browserCheckbox.state = preferencesStore.browserCaptureEnabled ? .on : .off
        browserCheckbox.isEnabled = false
        content.addSubview(browserCheckbox)

        y -= 40

        // --- Global Hotkey ---
        let hotkeyCheckbox = NSButton(
            checkboxWithTitle: "Global hotkey for rename",
            target: self,
            action: #selector(hotkeyToggled(_:))
        )
        hotkeyCheckbox.frame.origin = NSPoint(x: 20, y: y)
        hotkeyCheckbox.state = preferencesStore.hotkeyEnabled ? .on : .off
        content.addSubview(hotkeyCheckbox)

        let hotkeyLabel = makeLabel(
            preferencesStore.hotkeyDescription,
            at: y,
            size: 12,
            color: .secondaryLabelColor
        )
        hotkeyLabel.frame.origin.x = 230
        hotkeyLabel.frame.size.width = 120
        content.addSubview(hotkeyLabel)

        w.contentView = content
        w.makeKeyAndOrderFront(nil)
        activateApp()
        self.window = w
    }

    // MARK: - Actions

    @objc private func chooseFolder(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose where screenshots will be saved and organized"
        panel.directoryURL = preferencesStore.screenshotFolder

        guard panel.runModal() == .OK, let url = panel.url else { return }

        preferencesStore.screenshotFolderOverride = url.path
        folderLabel?.stringValue = url.path

        // Show the Reset button
        if let resetButton = window?.contentView?.viewWithTag(200) as? NSButton {
            resetButton.isHidden = false
        }

        onFolderChanged?()
    }

    @objc private func resetFolder(_ sender: NSButton) {
        preferencesStore.screenshotFolderOverride = nil
        folderLabel?.stringValue = preferencesStore.screenshotFolder.path
        sender.isHidden = true
        onFolderChanged?()
    }

    @objc private func launchAtLoginToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        preferencesStore.launchAtLogin = enabled
        if enabled {
            launchAgent.install()
        } else {
            launchAgent.uninstall()
        }
    }

    @objc private func browserCaptureToggled(_ sender: NSButton) {
        preferencesStore.browserCaptureEnabled = sender.state == .on
    }

    @objc private func hotkeyToggled(_ sender: NSButton) {
        preferencesStore.hotkeyEnabled = sender.state == .on
        onHotkeyChanged?()
    }

    @objc private func activateLicense(_ sender: NSButton) {
        guard let key = licenseKeyField?.stringValue, !key.isEmpty else { return }
        sender.isEnabled = false
        Task {
            do {
                let success = try await licenseManager.activate(key: key)
                await MainActor.run {
                    sender.isEnabled = true
                    if success {
                        updateLicenseStatusLabel()
                        let alert = NSAlert()
                        alert.messageText = "License Activated"
                        alert.informativeText = "Thank you! SmartScreenShot is now fully licensed."
                        alert.alertStyle = .informational
                        alert.runModal()
                        // Force window reconstruction to remove key field
                        window?.close()
                        window = nil
                        onLicenseChanged?()
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Invalid License Key"
                        alert.informativeText = "The key could not be activated. Please check it and try again."
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            } catch {
                await MainActor.run {
                    sender.isEnabled = true
                    let alert = NSAlert()
                    alert.messageText = "Activation Failed"
                    alert.informativeText = "Could not connect to the license server. Please check your internet connection and try again."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }

    @objc private func openPurchase(_ sender: NSButton) {
        NSWorkspace.shared.open(LicenseManager.purchaseURL)
    }

    private func updateLicenseStatusLabel() {
        switch licenseManager.status {
        case .trial(let remaining):
            licenseStatusLabel?.stringValue = "Trial: \(remaining)/\(LicenseManager.dailyLimit) remaining today"
            licenseStatusLabel?.textColor = remaining > 0 ? .secondaryLabelColor : .systemOrange
        case .licensed:
            licenseStatusLabel?.stringValue = "Licensed \u{2713}"
            licenseStatusLabel?.textColor = .systemGreen
        }
    }

    // MARK: - Helpers

    private func makeLabel(
        _ text: String,
        at y: CGFloat,
        size: CGFloat = 13,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 20, y: y, width: 140, height: 20)
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        return label
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Window is reused on next open
    }
}
