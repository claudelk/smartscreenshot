# SmartScreenShot — Implementation Progress

---

## Step 1 — CLI naming brain ✅ (2026-03-29)

**Goal:** standalone `sst` binary that takes an image path and prints a filename slug.

### Implemented
- `SmartScreenShotCore` SPM library target
  - `ImageNamer` protocol + `CaptureContext` struct
  - `SlugGenerator` — kebab-case slug generation + OCR line scoring
  - `VisionOnlyNamer` — Tier 1 namer (OCR + scene classification)
- `sst` executable target
  - Accepts `<image-path>` + optional `--verbose` / `-v` flag
  - Verbose mode prints OCR lines with confidence + score, classification labels, then slug
  - Plain mode prints slug only (pipe-friendly)

### Design decisions
- `@main` struct entry point (not `main.swift`) for clean async support
- `withCheckedThrowingContinuation` wraps Vision completion-handler API
- OCR: `accurate` mode, system languages + `en-US` fallback
- Slug scoring penalises all-caps, short strings, low letter ratio
- Classification fallback filters `others_*` catch-all labels
- Ultimate fallback: `"untitled"`

### Test it
```bash
swift build
.build/debug/sst /path/to/screenshot.png
.build/debug/sst /path/to/screenshot.png --verbose
```

---

## Step 2 — Context capture + FSEvents daemon ✅ (2026-03-29)

**Goal:** background daemon that captures app context at keystroke time and auto-renames screenshots.

### Implemented
- `CaptureContextStore` — lock-based (`NSLock`) ring buffer, nearest-match lookup within 10 s window
- `ScreenshotPreferences` — reads `com.apple.screencapture location`, falls back to `~/Desktop`
- `KeystrokeTap` — passive CGEventTap for Cmd+Shift+3/4/5; captures `NSWorkspace.frontmostApplication` **synchronously** on keystroke
- `ScreenshotWatcher` — FSEvents with `kFSEventStreamCreateFlagFileEvents`; filters for `created|renamed` events, skips hidden temp files, direct-children-only filter prevents reprocessing renamed files; passes `detectedAt` timestamp from callback
- `RenameEngine` actor — 0.5 s write-settle delay, context matching via `detectedAt`, slug generation, collision-safe move
- `ssd` daemon binary — wires everything together, prompts for Accessibility on first run

### Design decisions
- `CaptureContextStore` uses `NSLock` (not an actor) so `KeystrokeTap` can `store()` synchronously from the CGEventTap C callback — eliminates the race where an async store hadn't completed before `nearest()` was called
- `KeystrokeTap` uses `.listenOnly` passive tap — no event modification, minimal permission surface
- `ScreenshotWatcher` captures `Date()` inside the FSEvents callback and passes it as `detectedAt` — much closer to the actual keystroke than `Date()` inside the async Task
- `RenameEngine.recentlyProcessed` dictionary (3 s TTL) prevents double-processing when FSEvents fires both `created` and `renamed` for the same file
- Context match window is 10 seconds — accounts for ~5 s delay between keystroke and FSEvents detection
- Date formatting uses `Calendar.dateComponents` — thread-safe, no `DateFormatter` shared state
- Browser URL capture stubbed as `nil` — planned for Step 3 (toggle in Preferences)

### Test it
```bash
swift build
.build/debug/ssd
# Take a screenshot — watch the terminal output
```

---

## Step 3 — Menu bar app (planned)

- `NSStatusItem` (no Dock icon)
- Menu: Enable/Disable, Re-analyze last, Open folder, Preferences, Quit
- Preferences: namer tier selection, hotkey config, browser URL capture toggle
- **Launch at login** — register `~/Library/LaunchAgents/com.smartscreenshot.plist` on first run; unregister on uninstall

---

## Step 4 — Finder Quick Action + hotkey (planned)

- Finder extension for right-click rename
- Global hotkey handler — both call the same naming pipeline

---

## Known gaps / future work

- `FoundationModelsNamer` (Tier 2) — awaiting macOS 26 SDK
- `FastVLMNamer` (Tier 3) — Apple FastVLM via MLX, opt-in download
- Browser URL capture (Safari / Chrome / Arc / Firefox via AppleScript)
- Unit tests for `SlugGenerator` and `VisionOnlyNamer.buildSlug`
