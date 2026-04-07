#if !MAS
import AppKit
import CaptureFlowCore

/// Monitors a global keyboard shortcut and triggers a rename on the newest screenshot.
///
/// Default hotkey: Ctrl+Option+S (keyCode 1 = "s").
/// Requires Accessibility permission (same as CGEventTap).
final class GlobalHotkeyMonitor {

    private var monitor: Any?
    private let preferencesStore: PreferencesStore
    private let engine: RenameEngine
    private let screenshotFolder: () -> URL

    init(
        preferencesStore: PreferencesStore,
        engine: RenameEngine,
        screenshotFolder: @escaping () -> URL
    ) {
        self.preferencesStore = preferencesStore
        self.engine = engine
        self.screenshotFolder = screenshotFolder
    }

    func start() {
        guard monitor == nil else { return }
        guard preferencesStore.hotkeyEnabled else { return }

        let expectedKeyCode = UInt16(preferencesStore.hotkeyKeyCode)
        let expectedModifiers: NSEvent.ModifierFlags = modifierFlags(
            from: preferencesStore.hotkeyModifiers
        )

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }

            let pressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard event.keyCode == expectedKeyCode,
                  pressed == expectedModifiers else { return }

            self.renameNewestScreenshot()
        }

        print("[GlobalHotkeyMonitor] started (keyCode=\(expectedKeyCode))")
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    // MARK: - Private

    private func renameNewestScreenshot() {
        let folder = screenshotFolder()
        guard let newest = newestScreenshot(in: folder) else {
            print("[GlobalHotkeyMonitor] no unprocessed screenshot found in \(folder.path)")
            return
        }

        print("[GlobalHotkeyMonitor] renaming \(newest.lastPathComponent)")
        Task {
            let dest = await engine.processManual(file: newest)
            if dest == nil {
                print("[GlobalHotkeyMonitor] rename failed")
            }
        }
    }

    /// Finds the newest Screenshot*.png file that is a direct child of the folder
    /// (not inside a subfolder — those are already renamed).
    private func newestScreenshot(in folder: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return nil }

        return contents
            .filter { $0.pathExtension.lowercased() == "png" &&
                      $0.lastPathComponent.hasPrefix("Screenshot ") }
            .sorted { url1, url2 in
                let d1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let d2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return d1 > d2
            }
            .first
    }

    /// Converts stored modifier string to NSEvent.ModifierFlags.
    private func modifierFlags(from stored: String) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if stored.contains("control") { flags.insert(.control) }
        if stored.contains("option") { flags.insert(.option) }
        if stored.contains("command") { flags.insert(.command) }
        if stored.contains("shift") { flags.insert(.shift) }
        return flags
    }
}
#endif
