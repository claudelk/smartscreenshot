# SmartScreenShot — Licensing

## Model

- **Trial:** 5 free renames per day, resets at midnight local time
- **Paid:** $4.99 lifetime unlock via LemonSqueezy
- **Activation:** one network call to LemonSqueezy API, then fully offline forever

## Flow

1. User downloads and installs SmartScreenShot
2. App works in trial mode (5/day) with no sign-up required
3. When limit reached: notification (background) or alert (foreground) with Buy button
4. User clicks Buy → opens LemonSqueezy checkout in browser → pays $4.99
5. LemonSqueezy emails a UUID license key
6. User pastes key in Preferences → Activate
7. App calls `POST /v1/licenses/activate` → validates server-side → caches in Keychain
8. App is now fully licensed — no further network calls, ever

## License Key Format

Standard UUID (LemonSqueezy-generated):
```
38b1460a-5104-4067-a91d-77b872934d51
```

## Activation API

```
POST https://api.lemonsqueezy.com/v1/licenses/activate
Content-Type: application/x-www-form-urlencoded

license_key=<UUID>&instance_name=<Mac hostname>
```

Response includes: `activated`, `license_key.status`, `instance.id`, `meta.product_id`.

## Trust Model (TOFU)

LemonSqueezy keys are plain UUIDs — not cryptographically signed. The activation API confirms validity server-side. After activation, the response is cached in macOS Keychain and trusted on subsequent launches.

**Why this is acceptable for $4.99:**
- Target audience won't reverse-engineer Keychain entries
- No DRM is uncrackable at any price point
- Simplicity > security theater for this use case

## Storage

| Data | Location | Purpose |
|---|---|---|
| Trial counter | UserDefaults (`trial_count`, `trial_date`) | Daily rename count, resets on date change |
| License activation | macOS Keychain (`com.smartscreenshot.license`) | Cached LemonSqueezy response (instance_id, product_id, activated_at) |

**Why Keychain over UserDefaults for license?**
- More tamper-resistant (requires admin or app-specific access)
- Standard macOS practice for credentials/license data
- Survives `defaults delete` commands

## Gating Points

All three rename pathways are gated before calling `RenameEngine`:

1. **Auto-rename** (FSEvents) — `PipelineController` watcher callback
2. **Global hotkey** — `GlobalHotkeyMonitor.renameNewestScreenshot()`
3. **Batch rename** — `StatusBarController.batchRename()`

**Re-analyze is NOT gated** — it's a correction, not a new rename.

## LemonSqueezy Setup (TODO)

1. Create a LemonSqueezy store at lemonsqueezy.com
2. Create a product: "SmartScreenShot", $4.99, one-time payment
3. Enable license key generation for the product
4. Copy the checkout URL → update `LicenseManager.purchaseURL`
5. Copy the product ID → update `LicenseManager.expectedProductId`
