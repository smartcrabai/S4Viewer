import Foundation

nonisolated struct S3Credentials: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let accessKeyID: String
    let secretAccessKey: String

    var description: String {
        "S3Credentials(accessKeyID: \(accessKeyID), secretAccessKey: [REDACTED])"
    }

    var debugDescription: String {
        description
    }
}

nonisolated struct S3ConnectionConfiguration: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let name: String
    let endpointURL: URL
    let region: String
    let bucket: String
    let credentials: S3Credentials
    let usePathStyle: Bool

    var description: String {
        "S3ConnectionConfiguration(name: \(name), endpointHost: \(endpointURL.host ?? endpointURL.absoluteString), region: \(region), bucket: \(bucket), credentials: [REDACTED], usePathStyle: \(usePathStyle))"
    }

    var debugDescription: String {
        description
    }
}
