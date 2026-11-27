import Foundation
import SwiftData

@Model
final class ConnectionProfile {
    var id: UUID = UUID()
    var name: String = ""
    var endpoint: String = ""
    var region: String = ""
    var bucket: String = ""
    var usePathStyle: Bool = true
    /// Empty means the stored keys sign requests directly. Not secret, so it syncs with the
    /// profile; keys and session tokens stay in the Keychain.
    var roleARN: String = ""
    var externalID: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        endpoint: String,
        region: String,
        bucket: String,
        usePathStyle: Bool,
        roleARN: String = "",
        externalID: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.usePathStyle = usePathStyle
        self.roleARN = roleARN
        self.externalID = externalID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(validated: ValidatedConnectionProfile) {
        self.init(
            name: validated.name,
            endpoint: validated.endpointURL.absoluteString,
            region: validated.region,
            bucket: validated.bucket,
            usePathStyle: validated.usePathStyle,
            roleARN: validated.assumeRole?.roleARN ?? "",
            externalID: validated.assumeRole?.externalID ?? ""
        )
    }

    func apply(_ validated: ValidatedConnectionProfile, now: Date = .now) {
        name = validated.name
        endpoint = validated.endpointURL.absoluteString
        region = validated.region
        bucket = validated.bucket
        usePathStyle = validated.usePathStyle
        roleARN = validated.assumeRole?.roleARN ?? ""
        externalID = validated.assumeRole?.externalID ?? ""
        updatedAt = now
    }

    func configuration(credentials: S3Credentials) throws -> S3ConnectionConfiguration {
        return try ConnectionProfileDraft(profile: self, credentials: credentials)
            .validated()
            .configuration
    }
}
