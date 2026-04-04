# SmartScreenShot — Distribution

## Two Distribution Paths

SmartScreenShot supports both direct distribution and Mac App Store via conditional compilation.

### Direct Distribution (Developer ID + DMG)

Build: `swift build -c release`

- Full feature set: CGEventTap keystroke detection, global hotkey, LaunchAgent
- Requires Accessibility permission
- Code signed with Developer ID, notarized, packaged as DMG
- See `scripts/build-and-sign.sh`

### Mac App Store (Sandbox)

Build: `swift build -c release --target SmartScreenShot -Xswiftc -DMAS`

- App Sandbox enabled — no CGEventTap, no global hotkey
- App context captured via NSWorkspace.frontmostApplication at FSEvents time
- Launch at Login via SMAppService (not LaunchAgent)
- Screenshot folder access via security-scoped bookmarks (user selects folder on first launch)
- Paid upfront $4.99, Apple handles all payment
- See `scripts/build-mas.sh`

## Conditional Compilation

The `MAS` Swift compiler flag controls feature availability:

| Feature | Direct (`!MAS`) | MAS |
|---|---|---|
| CGEventTap (KeystrokeTap) | Yes | No — excluded |
| Global hotkey | Yes | No — excluded |
| App context detection | Keystroke time (instant) | FSEvents time (~1-3s delay) |
| Launch at Login | LaunchAgent plist | SMAppService |
| Folder access | Direct path | Security-scoped bookmark |
| Accessibility permission | Required | Not needed |
| Hotkey preferences | Shown | Hidden |
| Payment | N/A | Apple App Store |

## Sandbox Entitlements

`Distribution/SmartScreenShot-MAS.entitlements`:
- `com.apple.security.app-sandbox` — required for MAS
- `com.apple.security.files.user-selected.read-write` — NSOpenPanel folder access

## Security-Scoped Bookmarks

In sandbox, folder access doesn't persist across launches. On first launch:
1. App presents NSOpenPanel asking user to select screenshot folder
2. Bookmark data saved in UserDefaults
3. On subsequent launches, bookmark is resolved and `startAccessingSecurityScopedResource()` called
4. If bookmark becomes stale (folder moved), it's automatically refreshed
