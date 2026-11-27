import Foundation

nonisolated struct S3Credentials: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let accessKeyID: String
    let secretAccessKey: String
    /// STS session token for temporary credentials; sent as `X-Amz-Security-Token`.
    var sessionToken: String? = nil

    var description: String {
        "S3Credentials(accessKeyID: \(accessKeyID), secretAccessKey: [REDACTED], sessionToken: \(sessionToken == nil ? "none" : "[REDACTED]"))"
    }

    var debugDescription: String {
        description
    }
}

/// `sts:AssumeRole` target. The base credentials sign the call; the returned temporary
/// credentials sign every S3 request.
nonisolated struct AssumeRoleSettings: Equatable, Hashable, Sendable {
    let roleARN: String
    let externalID: String?
}

nonisolated struct S3ConnectionConfiguration: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    var name: String
    var endpointURL: URL
    var region: String
    var bucket: String
    var credentials: S3Credentials
    var usePathStyle: Bool
    var assumeRole: AssumeRoleSettings? = nil

    var description: String {
        "S3ConnectionConfiguration(name: \(name), endpointHost: \(endpointURL.host ?? endpointURL.absoluteString), region: \(region), bucket: \(bucket), credentials: [REDACTED], usePathStyle: \(usePathStyle))"
    }

    var debugDescription: String {
        description
    }

    /// The configuration for one bucket picked from `ListBuckets`. On AWS the request has to go
    /// to the bucket's own region, so a reported `BucketRegion` replaces the signing region and
    /// the regional host. S3-compatible endpoints keep the profile's region and host.
    func scoped(to bucket: S3Bucket) -> S3ConnectionConfiguration {
        var scoped = self
        scoped.bucket = bucket.name
        if
            let bucketRegion = bucket.region,
            let host = endpointURL.host?.lowercased(),
            Self.isAWSS3Host(host),
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        {
            components.host = "s3.\(bucketRegion).amazonaws.com"
            scoped.endpointURL = components.url ?? endpointURL
            scoped.region = bucketRegion
        }
        return scoped
    }

    /// `s3.amazonaws.com`, `s3.<region>.amazonaws.com`, or the legacy `s3-<region>.amazonaws.com`.
    static func isAWSS3Host(_ host: String) -> Bool {
        guard host.hasSuffix(".amazonaws.com") else {
            return false
        }
        let label = host.dropLast(".amazonaws.com".count)
        return label == "s3" || (label.hasPrefix("s3.") || label.hasPrefix("s3-")) && !label.dropFirst(3).contains(".")
    }
}
