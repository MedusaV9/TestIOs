import Foundation
import Security

/// Secrets shared by the app and widget extension. Nothing confidential is
/// mirrored through UserDefaults/App Group files. When a sideload signature
/// strips keychain-sharing, the app falls back to its private Keychain; widgets
/// then degrade to cached snapshots instead of exposing a token in defaults.
enum SharedKeychain {
    private static let service = "app.sooodreamy.session.v4"
    private static var sharedAccessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "SoooDreamyKeychainAccessGroup") as? String
    }
    private static let tokenPrefix = "profile-token:"
    private static let deviceAccount = "device-id"

    static func token(profileID: UUID) -> String? {
        read(account: tokenPrefix + profileID.uuidString)
    }

    @discardableResult
    static func setToken(_ token: String?, profileID: UUID) -> Bool {
        write(token, account: tokenPrefix + profileID.uuidString)
    }

    static func removeToken(profileID: UUID) {
        _ = write(nil, account: tokenPrefix + profileID.uuidString)
    }

    static func deviceID() -> String {
        if let existing = read(account: deviceAccount), !existing.isEmpty { return existing }
        let created = UUID().uuidString.lowercased()
        _ = write(created, account: deviceAccount)
        return created
    }

    /// Widget/background helpers read only the currently active profile's
    /// token. The account name is metadata; the bearer value remains Keychain.
    static func activeToken(profileID: UUID) -> String? {
        token(profileID: profileID)
    }

    private static func baseQuery(account: String, shared: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if shared, let accessGroup = sharedAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private static func read(account: String) -> String? {
        if let shared = read(account: account, shared: true) { return shared }
        return read(account: account, shared: false)
    }

    private static func read(account: String, shared: Bool) -> String? {
        var query = baseQuery(account: account, shared: shared)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func write(_ value: String?, account: String) -> Bool {
        guard sharedAccessGroup != nil else {
            let status = write(value, account: account, shared: false)
            return status == errSecSuccess || (value == nil && status == errSecItemNotFound)
        }
        if value == nil {
            // A token may have been written to the private fallback by an
            // older/sideloaded signature. Always clear both locations so a
            // stale local credential cannot reappear after entitlement changes.
            let sharedStatus = write(nil, account: account, shared: true)
            let localStatus = write(nil, account: account, shared: false)
            let accepted: Set<OSStatus> = [errSecSuccess, errSecItemNotFound, errSecMissingEntitlement]
            return accepted.contains(sharedStatus) && accepted.contains(localStatus)
        }
        let sharedStatus = write(value, account: account, shared: true)
        if sharedStatus == errSecSuccess {
            // Shared storage is authoritative; remove a possible old fallback.
            _ = write(nil, account: account, shared: false)
            return true
        }
        // Free/sideload signatures may strip the access-group entitlement.
        let localStatus = write(value, account: account, shared: false)
        return localStatus == errSecSuccess
    }

    private static func write(_ value: String?, account: String, shared: Bool) -> OSStatus {
        let query = baseQuery(account: account, shared: shared)
        guard let value else { return SecItemDelete(query as CFDictionary) }
        guard let data = value.data(using: .utf8) else { return errSecParam }
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updated != errSecItemNotFound { return updated }
        return SecItemAdd(query.merging(attrs) { _, new in new } as CFDictionary, nil)
    }
}
