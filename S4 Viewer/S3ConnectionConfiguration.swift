import Foundation

nonisolated struct S3Credentials: Codable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
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

    /// The configuration for one bucket picked from `ListBuckets`. On AWS the request has to go
    /// to the bucket's own region, so a reported `BucketRegion` replaces the signing region and
    /// the regional host. S3-compatible endpoints keep the profile's region and host.
    func scoped(to bucket: S3Bucket) -> S3ConnectionConfiguration {
        var scopedEndpoint = endpointURL
        var scopedRegion = region
        if
            let bucketRegion = bucket.region,
            let host = endpointURL.host?.lowercased(),
            Self.isAWSS3Host(host),
            var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        {
            components.host = "s3.\(bucketRegion).amazonaws.com"
            scopedEndpoint = components.url ?? endpointURL
            scopedRegion = bucketRegion
        }

        return S3ConnectionConfiguration(
            name: name,
            endpointURL: scopedEndpoint,
            region: scopedRegion,
            bucket: bucket.name,
            credentials: credentials,
            usePathStyle: usePathStyle
        )
    }

    /// `s3.amazonaws.com`, `s3.<region>.amazonaws.com`, or the legacy `s3-<region>.amazonaws.com`.
    private static func isAWSS3Host(_ host: String) -> Bool {
        guard host.hasSuffix(".amazonaws.com") else {
            return false
        }
        let label = host.dropLast(".amazonaws.com".count)
        return label == "s3" || (label.hasPrefix("s3.") || label.hasPrefix("s3-")) && !label.dropFirst(3).contains(".")
    }
}
