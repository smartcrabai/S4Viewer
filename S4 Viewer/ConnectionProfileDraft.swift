import Foundation

nonisolated enum ConnectionProfileValidationError: LocalizedError, Equatable {
    case missingName
    case invalidEndpoint
    case missingRegion
    case missingBucket
    case missingAccessKey
    case missingSecretKey

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Enter a profile name."
        case .invalidEndpoint:
            return "Enter a valid endpoint URL."
        case .missingRegion:
            return "Enter a region."
        case .missingBucket:
            return "Enter a bucket name."
        case .missingAccessKey:
            return "Enter an access key."
        case .missingSecretKey:
            return "Enter a secret key."
        }
    }
}

nonisolated struct ValidatedConnectionProfile: Equatable, Sendable {
    let name: String
    let endpointURL: URL
    let region: String
    let bucket: String
    let accessKey: String
    let secretKey: String
    let usePathStyle: Bool

    var configuration: S3ConnectionConfiguration {
        S3ConnectionConfiguration(
            name: name,
            endpointURL: endpointURL,
            region: region,
            bucket: bucket,
            credentials: S3Credentials(
                accessKeyID: accessKey,
                secretAccessKey: secretKey
            ),
            usePathStyle: usePathStyle
        )
    }
}

nonisolated struct ConnectionProfileDraft: Equatable, Sendable {
    var name: String = ""
    var endpoint: String = ""
    var region: String = ""
    var bucket: String = ""
    var accessKey: String = ""
    var secretKey: String = ""
    var usePathStyle: Bool = true

    init() {}

    init(
        name: String,
        endpoint: String,
        region: String,
        bucket: String,
        accessKey: String,
        secretKey: String,
        usePathStyle: Bool
    ) {
        self.name = name
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.usePathStyle = usePathStyle
    }

    init(profile: ConnectionProfile) {
        name = profile.name
        endpoint = profile.endpoint
        region = profile.region
        bucket = profile.bucket
        accessKey = profile.accessKey
        secretKey = profile.secretKey
        usePathStyle = profile.usePathStyle
    }

    func validated() throws -> ValidatedConnectionProfile {
        let normalizedName = name.trimmed()
        guard !normalizedName.isEmpty else {
            throw ConnectionProfileValidationError.missingName
        }

        let normalizedEndpoint = endpoint.trimmed().trimmingTrailingSlashes
        guard
            let endpointURL = URL(string: normalizedEndpoint),
            let scheme = endpointURL.scheme?.lowercased(),
            let host = endpointURL.host,
            !host.isEmpty,
            scheme == "https" || scheme == "http"
        else {
            throw ConnectionProfileValidationError.invalidEndpoint
        }

        let normalizedRegion = region.trimmed()
        guard !normalizedRegion.isEmpty else {
            throw ConnectionProfileValidationError.missingRegion
        }

        let normalizedBucket = bucket.trimmed()
        guard !normalizedBucket.isEmpty else {
            throw ConnectionProfileValidationError.missingBucket
        }

        let normalizedAccessKey = accessKey.trimmed()
        guard !normalizedAccessKey.isEmpty else {
            throw ConnectionProfileValidationError.missingAccessKey
        }

        let normalizedSecretKey = secretKey.trimmed()
        guard !normalizedSecretKey.isEmpty else {
            throw ConnectionProfileValidationError.missingSecretKey
        }

        return ValidatedConnectionProfile(
            name: normalizedName,
            endpointURL: endpointURL,
            region: normalizedRegion,
            bucket: normalizedBucket,
            accessKey: normalizedAccessKey,
            secretKey: normalizedSecretKey,
            usePathStyle: usePathStyle
        )
    }
}

private extension String {
    nonisolated func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
