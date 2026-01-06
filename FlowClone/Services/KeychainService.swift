//
//  KeychainService.swift
//  FlowClone
//
//  Created by Claude
//

import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.michalbastrzyk.FlowClone"
    private let groqAPIKeyAccount = "groq_api_key"

    private init() {}

    // MARK: - Groq API Key

    func setGroqAPIKey(_ key: String) throws {
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: groqAPIKeyAccount,
            kSecValueData as String: data
        ]

        // Delete existing first
        SecItemDelete(query as CFDictionary)

        // Add new
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            Logger.shared.error("Failed to store API key in keychain: \(status)")
            throw KeychainError.unableToStore
        }

        Logger.shared.info("Groq API key stored in keychain")
    }

    func getGroqAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: groqAPIKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            throw KeychainError.notFound
        }

        if status != errSecSuccess || result == nil {
            Logger.shared.error("Failed to retrieve API key from keychain: \(status)")
            throw KeychainError.unableToRetrieve
        }

        if let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            Logger.shared.debug("Groq API key retrieved from keychain")
            return key
        }

        throw KeychainError.unableToRetrieve
    }

    func deleteGroqAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: groqAPIKeyAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.shared.error("Failed to delete API key from keychain: \(status)")
            throw KeychainError.unableToDelete
        }

        Logger.shared.info("Groq API key deleted from keychain")
    }

    func hasGroqAPIKey() -> Bool {
        do {
            _ = try getGroqAPIKey()
            return true
        } catch {
            return false
        }
    }
}

enum KeychainError: LocalizedError {
    case notFound
    case unableToStore
    case unableToRetrieve
    case unableToDelete

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "API key not found in keychain"
        case .unableToStore:
            return "Unable to store API key in keychain"
        case .unableToRetrieve:
            return "Unable to retrieve API key from keychain"
        case .unableToDelete:
            return "Unable to delete API key from keychain"
        }
    }
}
