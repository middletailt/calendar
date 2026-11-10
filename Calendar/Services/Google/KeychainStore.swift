import Foundation
import Security

enum KeychainStore {
    private static let service = "com.middletail.calendar.google"

    static func save(_ data: Data, account: String) throws {
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
    }

    static func load(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.status(status)
        }
        return data
    }

    static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }

    enum KeychainError: LocalizedError {
        case status(OSStatus)

        var errorDescription: String? {
            switch self {
            case .status(let s): "Keychain error (\(s))"
            }
        }
    }
}

struct GoogleOAuthTokens: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
}

enum GoogleTokenStorage {
    private static let account = "google_oauth_tokens"

    static func load() throws -> GoogleOAuthTokens? {
        guard let data = try KeychainStore.load(account: account) else { return nil }
        return try JSONDecoder().decode(GoogleOAuthTokens.self, from: data)
    }

    static func save(_ tokens: GoogleOAuthTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        try KeychainStore.save(data, account: account)
    }

    static func clear() throws {
        try KeychainStore.delete(account: account)
    }
}
