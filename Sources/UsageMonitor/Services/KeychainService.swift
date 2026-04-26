// Sources/UsageMonitor/Services/KeychainService.swift
import Foundation
import Security

enum KeychainService {
    private static let service = "com.usage.monitor"
    private static let authTokenAccount = "auth-token"
    private static let codexCookieAccount = "codex-cookie"

    static func save(token: String) throws {
        try save(value: token, account: authTokenAccount)
    }

    static func load() -> String? {
        load(account: authTokenAccount)
    }

    static func delete() {
        delete(account: authTokenAccount)
    }

    static func saveCodexCookie(_ cookie: String) throws {
        try save(value: cookie, account: codexCookieAccount)
    }

    static func loadCodexCookie() -> String? {
        load(account: codexCookieAccount)
    }

    static func deleteCodexCookie() {
        delete(account: codexCookieAccount)
    }

    private static func save(value: String, account: String) throws {
        let data = Data(value.utf8)

        // Delete any existing token first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            "Keychain save failed with status: \(status)"
        }
    }
}
