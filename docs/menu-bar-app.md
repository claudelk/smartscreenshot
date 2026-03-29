# SmartScreenShot Menu Bar App — Design Notes

The `SmartScreenShot` binary is a macOS menu bar app (NSStatusItem) that replaces
the headless `ssd` daemon with GUI controls.

---

## Architecture

```
AppEntry.swift
  ├── NSApplication.setActivationPolicy(.accessory)  ← no Dock icon
  ├── AXIsProcessTrusted() check via NSAlert
  ├── PreferencesStore (UserDefaults)
  ├── PipelineController
  │     ├── CaptureContextStore (NSLock)
  │     ├── KeystrokeTap (CGEventTap)
  │     ├── ScreenshotWatcher (FSEvents)
  │     └── RenameEngine (actor)
  └── StatusBarController
        ├── NSStatusItem (SF Symbol: camera.viewfinder)
        ├── NSMenu (Enable/Disable, Re-analyze, Open Folder, Preferences, Quit)
        └── PreferencesWindow (programmatic NSWindow)
```

---

## Menu structure

| Item | Key | Action |
|---|---|---|
| Enable / Disable | — | `PipelineController.start()` / `.stop()` |
| Re-analyze Last Screenshot | — | Re-run namer on most recent file |
| Open Screenshot Folder | — | `NSWorkspace.shared.open(folder)` |
| Preferences... | ⌘, | Opens preferences window |
| Quit SmartScreenShot | ⌘Q | `NSApplication.shared.terminate(nil)` |

The toggle title updates dynamically via `NSMenuDelegate.menuWillOpen`.

---

## Preferences

| Setting | Status | Storage key |
|---|---|---|
| Naming engine (Tier 1/2/3) | Tier 1 active, 2/3 disabled | `namerTier` |
| Launch at login | Functional | `launchAtLogin` |
| Browser URL capture | Stubbed (disabled) | `browserCaptureEnabled` |
| Global hotkey | Stubbed (disabled) | — |

Preferences are stored in `UserDefaults(suiteName: "com.smartscreenshot.app")`.

---

## Launch at login

`LaunchAtLogin` manages `~/Library/LaunchAgents/com.smartscreenshot.plist`:

- **Install**: writes XML plist with `RunAtLoad: true`, `KeepAlive: false`
- **Uninstall**: `launchctl bootout gui/{uid}` then deletes the plist file
- Executable path resolved from `Bundle.main.executablePath` with fallback to `ProcessInfo.processInfo.arguments.first`

---

## PipelineController lifecycle

Same components as the `ssd` daemon, but with start/stop controls:

- `start()` — creates ScreenshotWatcher + KeystrokeTap, begins listening
- `stop()` — stops watcher and tap, nils them out
- `reanalyzeLast()` — re-runs the namer on the most recently renamed file
- Tracks `lastDetectedURL` (original) and `lastDestinationURL` (after rename)

The Enable/Disable menu item calls `start()`/`stop()` and persists state in `PreferencesStore.isEnabled`.

---

## SPM-only approach

No Xcode project required:

- `.setActivationPolicy(.accessory)` replaces `LSUIElement = true` in Info.plist
- SF Symbols available macOS 13+ (no custom icon files needed)
- All UI built programmatically (no storyboard/XIB)
- `NSApplication.shared.run()` drives the same main RunLoop that CGEventTap and FSEvents use

For distribution, the binary can later be wrapped in a `.app` bundle with a build script
or migrated to an Xcode project.

---

## Running

```bash
swift build
.build/debug/SmartScreenShot
```

On first run without Accessibility permission, an NSAlert prompts the user to grant access.
