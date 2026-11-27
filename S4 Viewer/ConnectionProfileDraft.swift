import Foundation

nonisolated enum ConnectionProfileValidationError: LocalizedError, Equatable {
    case missingName
    case invalidEndpoint
    case missingRegion
    case missingAccessKey
    case missingSecretKey
    case invalidRoleARN
    case externalIDWithoutRole

    var errorDescription: String? {
        switch self {
        case .missingName:
            return "Enter a profile name."
        case .invalidEndpoint:
            return "Enter a valid endpoint URL."
        case .missingRegion:
            return "Enter a region."
        case .missingAccessKey:
            return "Enter an access key."
        case .missingSecretKey:
            return "Enter a secret key."
        case .invalidRoleARN:
            return "Enter a role ARN such as arn:aws:iam::123456789012:role/Name, or leave it empty."
        case .externalIDWithoutRole:
            return "An external ID needs a role ARN."
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
    var sessionToken: String? = nil
    var assumeRole: AssumeRoleSettings? = nil

    var credentials: S3Credentials {
        S3Credentials(accessKeyID: accessKey, secretAccessKey: secretKey, sessionToken: sessionToken)
    }

    var configuration: S3ConnectionConfiguration {
        S3ConnectionConfiguration(
            name: name,
            endpointURL: endpointURL,
            region: region,
            bucket: bucket,
            credentials: credentials,
            usePathStyle: usePathStyle,
            assumeRole: assumeRole
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
    var sessionToken: String = ""
    var roleARN: String = ""
    var externalID: String = ""

    init() {}

    init(
        name: String,
        endpoint: String,
        region: String,
        bucket: String,
        accessKey: String,
        secretKey: String,
        usePathStyle: Bool,
        sessionToken: String = "",
        roleARN: String = "",
        externalID: String = ""
    ) {
        self.name = name
        self.endpoint = endpoint
        self.region = region
        self.bucket = bucket
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.usePathStyle = usePathStyle
        self.sessionToken = sessionToken
        self.roleARN = roleARN
        self.externalID = externalID
    }

    init(profile: ConnectionProfile, credentials: S3Credentials?) {
        name = profile.name
        endpoint = profile.endpoint
        region = profile.region
        bucket = profile.bucket
        accessKey = credentials?.accessKeyID ?? ""
        secretKey = credentials?.secretAccessKey ?? ""
        sessionToken = credentials?.sessionToken ?? ""
        usePathStyle = profile.usePathStyle
        roleARN = profile.roleARN
        externalID = profile.externalID
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

        // Empty means "every bucket the credentials can list".
        let normalizedBucket = bucket.trimmed()

        let normalizedAccessKey = accessKey.trimmed()
        guard !normalizedAccessKey.isEmpty else {
            throw ConnectionProfileValidationError.missingAccessKey
        }

        let normalizedSecretKey = secretKey.trimmed()
        guard !normalizedSecretKey.isEmpty else {
            throw ConnectionProfileValidationError.missingSecretKey
        }

        let normalizedToken = sessionToken.trimmed()
        let normalizedRoleARN = roleARN.trimmed()
        let normalizedExternalID = externalID.trimmed()
        guard normalizedRoleARN.isEmpty || normalizedRoleARN.hasPrefix("arn:") else {
            throw ConnectionProfileValidationError.invalidRoleARN
        }
        guard normalizedExternalID.isEmpty || !normalizedRoleARN.isEmpty else {
            throw ConnectionProfileValidationError.externalIDWithoutRole
        }

        return ValidatedConnectionProfile(
            name: normalizedName,
            endpointURL: endpointURL,
            region: normalizedRegion,
            bucket: normalizedBucket,
            accessKey: normalizedAccessKey,
            secretKey: normalizedSecretKey,
            usePathStyle: usePathStyle,
            sessionToken: normalizedToken.isEmpty ? nil : normalizedToken,
            assumeRole: normalizedRoleARN.isEmpty
                ? nil
                : AssumeRoleSettings(
                    roleARN: normalizedRoleARN,
                    externalID: normalizedExternalID.isEmpty ? nil : normalizedExternalID
                )
        )
    }
}

private extension String {
    nonisolated func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
