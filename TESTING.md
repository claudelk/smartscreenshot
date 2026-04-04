# SmartScreenShot — Manual Testing Checklist

Instructions: After each test, mark it as PASS or FAIL.
- PASS: `- [x] PASS — ...`
- FAIL: `- [ ] FAIL — ...` (add a note describing what went wrong)

---

## 1. Basic Pipeline

- [ ] **1.1** Launch app → camera icon appears in menu bar
- [ ] **1.2** Take a screenshot (Cmd+Shift+3) → file is renamed and moved into `screenshot_YYYY-MM-DD/` folder
- [ ] **1.3** Take a screenshot (Cmd+Shift+4, select area) → same rename behavior
- [ ] **1.4** Renamed file has a meaningful content-based name (not "Screenshot 2026-...")
- [ ] **1.5** File extension is `.png`

## 2. Menu Bar Actions

- [ ] **2.1** Click menu → "Disable" shown when pipeline is running
- [ ] **2.2** Click "Disable" → menu now shows "Enable"
- [ ] **2.3** While disabled, take a screenshot → file is NOT renamed (stays as "Screenshot ...")
- [ ] **2.4** Click "Enable" → pipeline resumes, new screenshots are renamed
- [ ] **2.5** "Re-analyze Last Screenshot" is grayed out before any screenshot is taken
- [ ] **2.6** After a screenshot is renamed, "Re-analyze Last Screenshot" is clickable
- [ ] **2.7** Click "Re-analyze Last Screenshot" → file is re-renamed (may get a different name)
- [ ] **2.8** "Batch Rename Screenshots..." → opens file picker, can select multiple PNGs
- [ ] **2.9** Selected files are renamed and moved into `screenshot_YYYY-MM-DD/` folders
- [ ] **2.10** "Open Screenshot Folder" → opens the screenshot folder in Finder
- [ ] **2.11** "Quit SmartScreenShot" → app exits, camera icon disappears

## 3. Preferences — Screenshot Folder

- [ ] **3.1** Open Preferences → "Save screenshots to:" shows current folder path
- [ ] **3.2** Click "Choose..." → folder picker opens
- [ ] **3.3** Select a different folder → path updates in Preferences
- [ ] **3.4** Take a screenshot → file is renamed into the NEW folder
- [ ] **3.5** Click "Reset" → folder reverts to default (Desktop or system preference)
- [ ] **3.6** Take a screenshot → file is renamed into the DEFAULT folder

## 4. Preferences — Group by App

- [ ] **4.1** "Group screenshots by frontmost app" is unchecked by default
- [ ] **4.2** With it unchecked: take a screenshot → folder is `screenshot_YYYY-MM-DD/`
- [ ] **4.3** Check "Group screenshots by frontmost app"
- [ ] **4.4** Open Safari (or any app), take a screenshot → folder is `safari_YYYY-MM-DD/` (or the app name)
- [ ] **4.5** Uncheck it again → next screenshot goes back to `screenshot_YYYY-MM-DD/`

## 5. Preferences — Naming Mode

- [ ] **5.1** Naming Mode dropdown shows "Standard" selected
- [ ] **5.2** "Enhanced" and "Advanced" options are visible but disabled (Coming Soon)

## 6. Preferences — Launch at Login

- [ ] **6.1** "Launch at login" checkbox is present
- [ ] **6.2** Toggle it on → no crash (functionality depends on OS/permissions)
- [ ] **6.3** Toggle it off → no crash

## 7. Preferences — Global Hotkey (Direct Distribution Only)

- [ ] **7.1** "Global hotkey for rename" checkbox is present
- [ ] **7.2** Hotkey description shown (e.g., "⌃⌥S")
- [ ] **7.3** Enable hotkey → press Ctrl+Option+S → newest screenshot is renamed
- [ ] **7.4** Disable hotkey → press Ctrl+Option+S → nothing happens

## 8. Batch Rename — Edge Cases

- [ ] **8.1** Batch rename with 0 files selected → nothing happens (dialog closes)
- [ ] **8.2** Batch rename with 1 file → file is renamed
- [ ] **8.3** Batch rename with 5+ files → all files are renamed
- [ ] **8.4** Batch rename a file that's already been renamed → gets re-renamed (no crash)

## 9. Multiple Screenshots

- [ ] **9.1** Take 3 screenshots rapidly (Cmd+Shift+3 three times) → all 3 are renamed
- [ ] **9.2** Each renamed file has a unique name (no overwrites)
- [ ] **9.3** All land in the same date folder

## 10. App Lifecycle

- [ ] **10.1** Quit and relaunch → settings are preserved (folder, groupByApp, etc.)
- [ ] **10.2** Preferences window can be opened, closed, and reopened without crash
- [ ] **10.3** App runs stably for 5+ minutes without crash

---

## Test Results Summary

| Section | Pass | Fail | Not Tested |
|---------|------|------|------------|
| 1. Basic Pipeline | | | |
| 2. Menu Bar Actions | | | |
| 3. Screenshot Folder | | | |
| 4. Group by App | | | |
| 5. Naming Mode | | | |
| 6. Launch at Login | | | |
| 7. Global Hotkey | | | |
| 8. Batch Rename | | | |
| 9. Multiple Screenshots | | | |
| 10. App Lifecycle | | | |

**Tested by:** _______________
**Date:** _______________
**Build:** _______________
**Notes:**

