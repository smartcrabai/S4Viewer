import Foundation
import Security

nonisolated enum ConnectionCredentialStoreError: LocalizedError, Equatable {
    case missingCredentials
    case invalidCredentials
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Enter the access key and secret key again. Credentials are stored in your Keychain and are not part of iCloud profile sync unless iCloud Keychain is enabled."
        case .invalidCredentials:
            return "The saved credentials could not be read."
        case let .keychain(status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "Keychain operation failed (\(status))."
        }
    }
}

nonisolated struct ConnectionCredentialStore: Sendable {
    static let shared = ConnectionCredentialStore(
        service: "ai.smartcrab.s4viewer.s3-credentials",
        synchronizes: true,
        usesDataProtectionKeychain: true
    )

    private let service: String
    private let synchronizes: Bool
    private let usesDataProtectionKeychain: Bool

    init(service: String, synchronizes: Bool, usesDataProtectionKeychain: Bool) {
        self.service = service
        self.synchronizes = synchronizes
        self.usesDataProtectionKeychain = usesDataProtectionKeychain
    }

    func save(_ credentials: S3Credentials, for profileID: UUID) throws {
        let data = try JSONEncoder().encode(credentials)
        let query = itemQuery(for: profileID)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var attributes = query
            attributes[kSecValueData as String] = data
            if usesDataProtectionKeychain {
                attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            }
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw ConnectionCredentialStoreError.keychain(addStatus)
            }
        default:
            throw ConnectionCredentialStoreError.keychain(updateStatus)
        }
    }

    func load(for profileID: UUID) throws -> S3Credentials {
        var query = itemQuery(for: profileID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard
                let data = result as? Data,
                let stored = try? JSONDecoder().decode(S3Credentials.self, from: data)
            else {
                throw ConnectionCredentialStoreError.invalidCredentials
            }
            return stored
        case errSecItemNotFound:
            throw ConnectionCredentialStoreError.missingCredentials
        default:
            throw ConnectionCredentialStoreError.keychain(status)
        }
    }

    func delete(for profileID: UUID) throws {
        let status = SecItemDelete(itemQuery(for: profileID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ConnectionCredentialStoreError.keychain(status)
        }
    }

    private func itemQuery(for profileID: UUID) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString,
            kSecAttrSynchronizable as String: synchronizes,
        ]
        if usesDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }
}
