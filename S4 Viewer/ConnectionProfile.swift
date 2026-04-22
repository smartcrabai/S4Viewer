import Foundation
import SwiftData

@Model
final class ConnectionProfile {
    var id: UUID
    var name: String
    var endpoint: String
    var region: String
    var bucket: String
    var accessKey: String
    var secretKey: String
    var usePathStyle: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        endpoint: String,
        region: String,
        bucket: String,
        accessKey: String,
        secretKey: String,
        usePathStyle: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.accessKey = accessKey
        self.secretKey = secretKey
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
            accessKey: validated.accessKey,
            secretKey: validated.secretKey,
            usePathStyle: validated.usePathStyle
        )
    }

    func apply(_ validated: ValidatedConnectionProfile, now: Date = .now) {
        name = validated.name
        endpoint = validated.endpointURL.absoluteString
        region = validated.region
        bucket = validated.bucket
        accessKey = validated.accessKey
        secretKey = validated.secretKey
        usePathStyle = validated.usePathStyle
        updatedAt = now
    }

    func configuration() throws -> S3ConnectionConfiguration {
        try ConnectionProfileDraft(profile: self).validated().configuration
    }
}
