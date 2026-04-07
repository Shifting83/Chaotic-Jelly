import Foundation
import Security

// MARK: - KeychainService

/// Secure storage for API keys and tokens using macOS Keychain.
struct KeychainService {
    private static let serviceName = "com.chaoticjelly.app"

    // MARK: - Keys

    enum KeychainKey: String {
        case githubPAT = "github-pat"
        case llmAPIKey = "llm-api-key"
    }

    // MARK: - Save

    static func save(key: KeychainKey, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first
        try? delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Load

    static func load(key: KeychainKey) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.loadFailed(status)
        }

        return string
    }

    // MARK: - Delete

    static func delete(key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Check

    static func exists(key: KeychainKey) -> Bool {
        (try? load(key: key)) != nil
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode value for Keychain"
        case .saveFailed(let status):
            return "Keychain save failed: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)"
        case .loadFailed(let status):
            return "Keychain load failed: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(SecCopyErrorMessageString(status, nil) ?? "unknown" as CFString)"
        }
    }
}
