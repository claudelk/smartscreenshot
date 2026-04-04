import AppKit

@main
struct SmartScreenShotApp {

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)  // No Dock icon

        #if !MAS
        // Check Accessibility — required for CGEventTap (not needed in sandboxed MAS build)
        if !AXIsProcessTrusted() {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
            SmartScreenShot needs Accessibility access to detect \
            screenshot keystrokes (Cmd+Shift+3/4/5).

            Grant access in System Settings \u{203A} Privacy & Security \
            \u{203A} Accessibility, then relaunch.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
            app.terminate(nil)
            return
        }
        #endif

        // Build components
        let prefsStore = PreferencesStore()

        #if MAS
        // First-launch: ask user to select screenshot folder for sandbox access
        if prefsStore.screenshotFolderBookmark == nil && prefsStore.screenshotFolderOverride == nil {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Select"
            panel.message = "SmartScreenShot needs access to your screenshot folder.\nSelect the folder where macOS saves screenshots (usually Desktop)."
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop")

            if panel.runModal() == .OK, let url = panel.url {
                prefsStore.screenshotFolderOverride = url.path
                prefsStore.saveBookmark(for: url)
            } else {
                // User cancelled — use Desktop as fallback, they can change later
                let desktop = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Desktop")
                prefsStore.screenshotFolderOverride = desktop.path
                prefsStore.saveBookmark(for: desktop)
            }
        }
        #endif

        let pipeline = PipelineController(preferencesStore: prefsStore)
        let statusBar = StatusBarController(pipeline: pipeline, preferencesStore: prefsStore)

        // Start the pipeline if enabled (default: true on first launch)
        if prefsStore.isEnabled {
            pipeline.start()
        }

        print("SmartScreenShot ready.")

        // Keep strong references alive for the app lifetime
        withExtendedLifetime((statusBar, pipeline, prefsStore)) {
            app.run()
        }
    }
}
