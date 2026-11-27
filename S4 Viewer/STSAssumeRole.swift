import CryptoKit
import Foundation

nonisolated enum STSError: LocalizedError, Equatable {
    case invalidResponse
    case httpFailure(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "AssumeRole returned no temporary credentials."
        case let .httpFailure(statusCode, message):
            return "AssumeRole failed with status \(statusCode): \(message)"
        }
    }
}

nonisolated struct TemporaryCredentials: Equatable, Sendable {
    let credentials: S3Credentials
    let expiration: Date
}

protocol STSClientProtocol: Sendable {
    func assumeRole(_ settings: AssumeRoleSettings, using credentials: S3Credentials) async throws -> TemporaryCredentials
}

nonisolated struct STSAssumeRoleResponseParser {
    func parse(data: Data) throws -> TemporaryCredentials {
        let document = try XMLDocument(data: data)
        guard
            let credentials = document.rootElement()?.firstDescendant(named: "Credentials"),
            let accessKeyID = credentials.firstValue(for: "AccessKeyId"),
            let secretAccessKey = credentials.firstValue(for: "SecretAccessKey"),
            let sessionToken = credentials.firstValue(for: "SessionToken"),
            let expiration = parseS3Timestamp(credentials.firstValue(for: "Expiration"))
        else {
            throw STSError.invalidResponse
        }
        return TemporaryCredentials(
            credentials: S3Credentials(
                accessKeyID: accessKeyID,
                secretAccessKey: secretAccessKey,
                sessionToken: sessionToken
            ),
            expiration: expiration
        )
    }
}

/// `AssumeRole` over the STS Query API, signed with SigV4 for the `sts` service.
nonisolated final class STSHTTPClient: STSClientProtocol, @unchecked Sendable {
    private static let durationSeconds = 3_600

    private let endpointURL: URL
    private let region: String
    private let session: URLSession
    private let signer: S3RequestSigner
    private let parser = STSAssumeRoleResponseParser()

    init(
        endpointURL: URL,
        region: String,
        session: URLSession = .shared,
        signer: S3RequestSigner = S3RequestSigner()
    ) {
        self.endpointURL = endpointURL
        self.region = region
        self.session = session
        self.signer = signer
    }

    /// AWS S3 endpoints use the regional STS endpoint. S3-compatible services that implement
    /// AssumeRole (MinIO) answer it on the S3 endpoint itself.
    static func endpoint(forS3Endpoint s3Endpoint: URL, region: String) -> URL {
        guard
            let host = s3Endpoint.host?.lowercased(),
            S3ConnectionConfiguration.isAWSS3Host(host),
            var components = URLComponents(url: s3Endpoint, resolvingAgainstBaseURL: false)
        else {
            return s3Endpoint
        }
        components.host = "sts.\(region).amazonaws.com"
        components.path = ""
        return components.url ?? s3Endpoint
    }

    func assumeRole(_ settings: AssumeRoleSettings, using credentials: S3Credentials) async throws -> TemporaryCredentials {
        var parameters = [
            ("Action", "AssumeRole"),
            ("Version", "2011-06-15"),
            ("RoleArn", settings.roleARN),
            ("RoleSessionName", "S4Viewer-\(Int(Date.now.timeIntervalSince1970))"),
            ("DurationSeconds", String(Self.durationSeconds)),
        ]
        if let externalID = settings.externalID {
            parameters.append(("ExternalId", externalID))
        }
        let body = Data(
            parameters
                .map { "\(S3RequestSigner.uriEncodeComponent($0.0))=\(S3RequestSigner.uriEncodeComponent($0.1))" }
                .joined(separator: "&")
                .utf8
        )

        var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        if components?.path.isEmpty == true {
            components?.path = "/"
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let signed = try signer.sign(
            request,
            payload: body,
            credentials: credentials,
            region: region,
            service: "sts"
        )
        let (data, response) = try await session.data(for: signed)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STSError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw STSError.httpFailure(statusCode: httpResponse.statusCode, message: Self.errorMessage(from: data))
        }
        return try parser.parse(data: data)
    }

    private static func errorMessage(from data: Data) -> String {
        if
            let document = try? XMLDocument(data: data),
            let message = document.rootElement()?.firstDescendant(named: "Message")?.stringValue,
            !message.isEmpty
        {
            return message
        }
        return "The STS endpoint returned an unreadable error response."
    }
}

/// Holds assumed-role credentials in memory only, keyed by profile and by a digest of the
/// base credentials and role settings, so rotating keys or editing the role assumes again.
/// Credentials are refreshed `refreshMargin` seconds before they expire; concurrent callers
/// share one in-flight `AssumeRole`.
actor TemporaryCredentialProvider {
    static let shared = TemporaryCredentialProvider()

    private struct Entry {
        let id = UUID()
        let fingerprint: String
        let task: Task<TemporaryCredentials, any Error>
    }

    private let refreshMargin: TimeInterval
    private let now: @Sendable () -> Date
    private var entries: [UUID: Entry] = [:]

    init(refreshMargin: TimeInterval = 300, now: @escaping @Sendable () -> Date = { .now }) {
        self.refreshMargin = refreshMargin
        self.now = now
    }

    func credentials(
        for profileID: UUID,
        settings: AssumeRoleSettings,
        base: S3Credentials,
        assume: @escaping @Sendable () async throws -> TemporaryCredentials
    ) async throws -> S3Credentials {
        let fingerprint = Self.fingerprint(settings: settings, base: base)

        // Reuse a fresh or in-flight result. If the entry was replaced while this caller
        // awaited (another caller started a refresh), check the replacement instead.
        while let entry = entries[profileID], entry.fingerprint == fingerprint {
            if let temporary = try? await entry.task.value,
               temporary.expiration.timeIntervalSince(now()) > refreshMargin {
                return temporary.credentials
            }
            if entries[profileID]?.id == entry.id {
                break
            }
        }

        let entry = Entry(fingerprint: fingerprint, task: Task { try await assume() })
        entries[profileID] = entry
        do {
            return try await entry.task.value.credentials
        } catch {
            // A failure is never cached.
            if entries[profileID]?.id == entry.id {
                entries[profileID] = nil
            }
            throw error
        }
    }

    private static func fingerprint(settings: AssumeRoleSettings, base: S3Credentials) -> String {
        let material = [
            settings.roleARN,
            settings.externalID ?? "",
            base.accessKeyID,
            base.secretAccessKey,
            base.sessionToken ?? "",
        ].joined(separator: "\u{0}")
        return SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private extension XMLElement {
    nonisolated func firstDescendant(named name: String) -> XMLElement? {
        for child in children ?? [] {
            guard let element = child as? XMLElement else {
                continue
            }
            if element.localName == name {
                return element
            }
            if let match = element.firstDescendant(named: name) {
                return match
            }
        }
        return nil
    }
}
