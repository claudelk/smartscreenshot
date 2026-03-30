import Foundation
import Security
import UserNotifications

/// Manages trial state and license activation via LemonSqueezy.
///
/// - Trial: 5 renames/day, counter in UserDefaults, resets at midnight
/// - License: one-time activation via LemonSqueezy API, cached in Keychain (TOFU)
/// - After activation, zero network calls — Keychain is the source of truth
final class LicenseManager {

    enum LicenseStatus {
        case trial(remaining: Int)
        case licensed
    }

    static let dailyLimit = 5

    // TODO: Replace with your actual LemonSqueezy checkout URL and product ID
    static let purchaseURL = URL(string: "https://smartscreenshot.lemonsqueezy.com/buy")!
    static let expectedProductId = 0  // Set after creating LemonSqueezy product

    private let defaults: UserDefaults
    private let keychainService = "com.smartscreenshot.license"
    private let keychainAccount = "activation"

    private enum DefaultsKeys {
        static let trialDate = "trial_date"   // "YYYY-MM-DD"
        static let trialCount = "trial_count" // Int
    }

    init(suiteName: String = "com.smartscreenshot.app") {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Status

    var status: LicenseStatus {
        if isLicensed { return .licensed }
        return .trial(remaining: remainingToday)
    }

    var isLicensed: Bool {
        readKeychain() != nil
    }

    var remainingToday: Int {
        if isLicensed { return Int.max }
        resetCounterIfNewDay()
        let used = defaults.integer(forKey: DefaultsKeys.trialCount)
        return max(0, Self.dailyLimit - used)
    }

    /// Returns true if a rename is allowed. Increments counter if trial.
    func consumeRename() -> Bool {
        if isLicensed { return true }
        resetCounterIfNewDay()
        let used = defaults.integer(forKey: DefaultsKeys.trialCount)
        guard used < Self.dailyLimit else { return false }
        defaults.set(used + 1, forKey: DefaultsKeys.trialCount)
        return true
    }

    // MARK: - Activation

    /// Activate a license key via LemonSqueezy API.
    /// One network call — result is cached in Keychain forever.
    func activate(key: String) async throws -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Basic UUID format check
        guard isValidUUID(trimmed) else { return false }

        // Call LemonSqueezy activation API
        let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/activate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let instanceName = Host.current().localizedName ?? "Mac"
        let body = "license_key=\(trimmed)&instance_name=\(instanceName)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else { return false }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        // Check activation success
        guard httpResponse.statusCode == 200,
              json["activated"] as? Bool == true else {
            return false
        }

        // Validate product ID if configured (prevents cross-product key reuse)
        if Self.expectedProductId != 0,
           let meta = json["meta"] as? [String: Any],
           let productId = meta["product_id"] as? Int,
           productId != Self.expectedProductId {
            return false
        }

        // Extract data to cache
        let instance = json["instance"] as? [String: Any]
        let meta = json["meta"] as? [String: Any]
        let licenseKeyInfo = json["license_key"] as? [String: Any]

        let activation: [String: Any] = [
            "key": trimmed,
            "instance_id": instance?["id"] as? String ?? "",
            "product_id": meta?["product_id"] as? Int ?? 0,
            "product_name": meta?["product_name"] as? String ?? "",
            "customer_email": meta?["customer_email"] as? String ?? "",
            "status": licenseKeyInfo?["status"] as? String ?? "active",
            "activated_at": ISO8601DateFormatter().string(from: Date()),
        ]

        // Store in Keychain
        guard let jsonData = try? JSONSerialization.data(withJSONObject: activation) else {
            return false
        }
        saveKeychain(data: jsonData)

        print("[LicenseManager] activated successfully")
        return true
    }

    /// Remove the stored license (for testing/support).
    func deactivate() {
        deleteKeychain()
        print("[LicenseManager] deactivated")
    }

    // MARK: - Trial Counter

    private func resetCounterIfNewDay() {
        let today = todayString()
        let stored = defaults.string(forKey: DefaultsKeys.trialDate) ?? ""
        if stored != today {
            defaults.set(today, forKey: DefaultsKeys.trialDate)
            defaults.set(0, forKey: DefaultsKeys.trialCount)
        }
    }

    private func todayString() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    // MARK: - Keychain

    private func saveKeychain(data: Data) {
        // Delete any existing entry first
        deleteKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[LicenseManager] Keychain save failed: \(status)")
        }
    }

    private func readKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Validation

    private func isValidUUID(_ string: String) -> Bool {
        UUID(uuidString: string) != nil
    }

    // MARK: - Notifications

    /// Post a notification when the trial limit is reached.
    /// Used by PipelineController and GlobalHotkeyMonitor (background contexts).
    static func postTrialLimitNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "SmartScreenShot"
            content.body = "Daily trial limit reached (\(dailyLimit)/\(dailyLimit)). Buy the full version for unlimited renames."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "trialLimit-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
