import Foundation
import Security

/// Where the API key is kept.
///
/// It lives in a file only this user can read, under Application Support. The keychain
/// would be the textbook place, but the app is signed ad hoc, so every rebuild looks like
/// a different app to the keychain and triggers an "allow access" prompt.
enum APIKeyStore {
    static let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("PreflopCoach/api-key")

    static func load() -> String? {
        if let data = try? Data(contentsOf: file), let key = String(data: data, encoding: .utf8) {
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        // Earlier builds kept the key in the keychain; move it over once.
        if let key = Keychain.load(), save(key) {
            Keychain.delete()
            return key
        }
        return nil
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(key.utf8).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            return true
        } catch {
            Log.write("couldn't save API key: \(error)")
            return false
        }
    }
}

enum Keychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "PreflopCoach",
        kSecAttrAccount as String: "anthropic-api-key",
    ]

    static func load() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
