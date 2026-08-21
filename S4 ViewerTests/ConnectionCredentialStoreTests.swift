import Foundation
import Security
import Testing
@testable import S4_Viewer

struct ConnectionCredentialStoreTests {
    private let service = "ai.smartcrab.s4viewer.tests.\(UUID().uuidString)"

    private func makeStore() -> ConnectionCredentialStore {
        ConnectionCredentialStore(
            service: service,
            synchronizes: false,
            usesDataProtectionKeychain: false
        )
    }

    @Test
    func credentialsRoundTripUpdateAndDelete() throws {
        let profileID = UUID()
        let store = makeStore()
        defer { try? store.delete(for: profileID) }

        let original = S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET")
        try store.save(original, for: profileID)
        #expect(try store.load(for: profileID) == original)

        let updated = S3Credentials(accessKeyID: "UPDATED", secretAccessKey: "REPLACED")
        try store.save(updated, for: profileID)
        #expect(try store.load(for: profileID) == updated)

        try store.delete(for: profileID)
        #expect(throws: ConnectionCredentialStoreError.missingCredentials) {
            try store.load(for: profileID)
        }
    }

    @Test
    func credentialsAreIsolatedPerProfile() throws {
        let firstID = UUID()
        let secondID = UUID()
        let store = makeStore()
        defer {
            try? store.delete(for: firstID)
            try? store.delete(for: secondID)
        }

        let first = S3Credentials(accessKeyID: "FIRST", secretAccessKey: "FIRST-SECRET")
        let second = S3Credentials(accessKeyID: "SECOND", secretAccessKey: "SECOND-SECRET")
        try store.save(first, for: firstID)
        try store.save(second, for: secondID)

        #expect(try store.load(for: firstID) == first)
        #expect(try store.load(for: secondID) == second)

        try store.delete(for: firstID)

        #expect(try store.load(for: secondID) == second)
        #expect(throws: ConnectionCredentialStoreError.missingCredentials) {
            try store.load(for: firstID)
        }
    }

    @Test
    func corruptedPayloadIsReportedAsInvalid() throws {
        let profileID = UUID()
        let store = makeStore()
        defer { try? store.delete(for: profileID) }

        try store.save(S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET"), for: profileID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString,
            kSecAttrSynchronizable as String: false,
        ]
        let status = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: Data("not json".utf8)] as CFDictionary
        )
        #expect(status == errSecSuccess)

        #expect(throws: ConnectionCredentialStoreError.invalidCredentials) {
            try store.load(for: profileID)
        }
    }

    @Test
    func deletingUnknownProfileSucceeds() throws {
        try makeStore().delete(for: UUID())
    }
}
