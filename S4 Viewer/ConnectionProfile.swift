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
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        endpoint: String,
        region: String,
        bucket: String,
        usePathStyle: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.usePathStyle = usePathStyle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(validated: ValidatedConnectionProfile) {
        self.init(
            name: validated.name,
            endpoint: validated.endpointURL.absoluteString,
            region: validated.region,
            bucket: validated.bucket,
            usePathStyle: validated.usePathStyle
        )
    }

    func apply(_ validated: ValidatedConnectionProfile, now: Date = .now) {
        name = validated.name
        endpoint = validated.endpointURL.absoluteString
        region = validated.region
        bucket = validated.bucket
        usePathStyle = validated.usePathStyle
        updatedAt = now
    }

    func configuration(credentials: S3Credentials) throws -> S3ConnectionConfiguration {
        return try ConnectionProfileDraft(profile: self, credentials: credentials)
            .validated()
            .configuration
    }
}
