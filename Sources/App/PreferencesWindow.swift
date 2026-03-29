import AppKit
import SmartScreenShotCore

/// Programmatic preferences window — no storyboard, no NIB.
final class PreferencesWindow: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let preferencesStore: PreferencesStore
    private let launchAgent = LaunchAtLogin()

    init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
        super.init()
    }

    func showWindow() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
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

        var y: CGFloat = 235

        // --- Naming Engine ---
        content.addSubview(makeLabel("Naming Engine:", at: y))

        let tierPopup = NSPopUpButton(frame: NSRect(x: 160, y: y - 2, width: 230, height: 26), pullsDown: false)
        tierPopup.addItems(withTitles: ["Vision OCR + Classification (Tier 1)"])

        let tier2 = NSMenuItem(title: "Foundation Models (Tier 2) \u{2014} Coming Soon", action: nil, keyEquivalent: "")
        tier2.isEnabled = false
        tierPopup.menu?.addItem(tier2)

        let tier3 = NSMenuItem(title: "FastVLM (Tier 3) \u{2014} Coming Soon", action: nil, keyEquivalent: "")
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

        // --- Global Hotkey (Step 4 stub) ---
        let hotkeyCheckbox = NSButton(
            checkboxWithTitle: "Global hotkey for rename",
            target: nil,
            action: nil
        )
        hotkeyCheckbox.frame.origin = NSPoint(x: 20, y: y)
        hotkeyCheckbox.state = .off
        hotkeyCheckbox.isEnabled = false
        content.addSubview(hotkeyCheckbox)

        let hotkeyNote = makeLabel("Coming in a future update", at: y, size: 11, color: .secondaryLabelColor)
        hotkeyNote.frame.origin.x = 230
        hotkeyNote.frame.size.width = 180
        content.addSubview(hotkeyNote)

        y -= 50

        // --- Screenshot folder (read-only) ---
        content.addSubview(makeLabel("Screenshot folder:", at: y))

        let folderPath = makeLabel(
            ScreenshotPreferences.folder.path,
            at: y, size: 11, color: .secondaryLabelColor
        )
        folderPath.frame.origin.x = 160
        folderPath.frame.size.width = 240
        folderPath.lineBreakMode = .byTruncatingMiddle
        content.addSubview(folderPath)

        w.contentView = content
        w.makeKeyAndOrderFront(nil)
        activateApp()
        self.window = w
    }

    // MARK: - Actions

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
