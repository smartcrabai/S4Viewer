import Foundation
import Synchronization
import Testing
@testable import S4_Viewer

// Every key, secret, and token here is a made-up fixture; the STS endpoint is stubbed.

struct SessionTokenSigningTests {
    @Test
    func sessionTokenIsSentAndSigned() throws {
        var request = URLRequest(url: URL(string: "https://examplebucket.s3.amazonaws.com/test.txt")!)
        request.httpMethod = "GET"

        let signed = try S3RequestSigner().sign(
            request,
            payload: Data(),
            credentials: S3Credentials(accessKeyID: "ASIAFIXTURE", secretAccessKey: "SECRET", sessionToken: "TOKEN"),
            region: "us-east-1",
            timestamp: Date(timeIntervalSince1970: 1_369_353_600)
        )

        #expect(signed.value(forHTTPHeaderField: "X-Amz-Security-Token") == "TOKEN")
        let authorization = try #require(signed.value(forHTTPHeaderField: "Authorization"))
        #expect(authorization.contains("SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-security-token,"))
    }

    @Test
    func stsServiceGoesIntoTheCredentialScope() throws {
        var request = URLRequest(url: URL(string: "https://sts.us-east-1.amazonaws.com/")!)
        request.httpMethod = "POST"

        let signed = try S3RequestSigner().sign(
            request,
            payload: Data("Action=AssumeRole".utf8),
            credentials: S3Credentials(accessKeyID: "AKIAFIXTURE", secretAccessKey: "SECRET"),
            region: "us-east-1",
            service: "sts",
            timestamp: Date(timeIntervalSince1970: 1_369_353_600)
        )

        let authorization = try #require(signed.value(forHTTPHeaderField: "Authorization"))
        #expect(authorization.hasPrefix("AWS4-HMAC-SHA256 Credential=AKIAFIXTURE/20130524/us-east-1/sts/aws4_request,"))
        #expect(signed.value(forHTTPHeaderField: "X-Amz-Security-Token") == nil)
    }
}

struct S3CredentialsTests {
    @Test
    func keychainPayloadWithoutTokenStillDecodes() throws {
        let legacy = Data(#"{"accessKeyID":"ACCESS","secretAccessKey":"SECRET"}"#.utf8)

        let decoded = try JSONDecoder().decode(S3Credentials.self, from: legacy)

        #expect(decoded == S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET"))
        #expect(decoded.sessionToken == nil)
    }

    @Test
    func descriptionRedactsSecretAndToken() {
        let credentials = S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET", sessionToken: "TOKEN")

        #expect(!"\(credentials)".contains("SECRET"))
        #expect(!"\(credentials)".contains("TOKEN"))
        #expect(!String(reflecting: credentials).contains("TOKEN"))
    }
}

struct IAMProfileDraftTests {
    private func draft(sessionToken: String = "", roleARN: String = "", externalID: String = "") -> ConnectionProfileDraft {
        ConnectionProfileDraft(
            name: "Work",
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: "",
            accessKey: "ACCESS",
            secretKey: "SECRET",
            usePathStyle: false,
            sessionToken: sessionToken,
            roleARN: roleARN,
            externalID: externalID
        )
    }

    @Test
    func optionalIAMFieldsAreTrimmedIntoTheConfiguration() throws {
        let validated = try draft(
            sessionToken: " TOKEN ",
            roleARN: " arn:aws:iam::123456789012:role/Reader ",
            externalID: " partner "
        ).validated()

        #expect(validated.credentials.sessionToken == "TOKEN")
        #expect(validated.configuration.assumeRole == AssumeRoleSettings(
            roleARN: "arn:aws:iam::123456789012:role/Reader",
            externalID: "partner"
        ))
    }

    @Test
    func emptyIAMFieldsMeanStaticKeys() throws {
        let validated = try draft().validated()

        #expect(validated.credentials.sessionToken == nil)
        #expect(validated.configuration.assumeRole == nil)
    }

    @Test
    func roleARNMustBeAnARN() {
        #expect(throws: ConnectionProfileValidationError.invalidRoleARN) {
            try draft(roleARN: "Reader").validated()
        }
    }

    @Test
    func externalIDNeedsARole() {
        #expect(throws: ConnectionProfileValidationError.externalIDWithoutRole) {
            try draft(externalID: "partner").validated()
        }
    }

    @Test
    func profileRoundTripsRoleSettingsAndCredentialToken() {
        let profile = ConnectionProfile(
            name: "Work",
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: "",
            usePathStyle: false,
            roleARN: "arn:aws:iam::123456789012:role/Reader",
            externalID: "partner"
        )

        let restored = ConnectionProfileDraft(
            profile: profile,
            credentials: S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET", sessionToken: "TOKEN")
        )

        #expect(restored.roleARN == "arn:aws:iam::123456789012:role/Reader")
        #expect(restored.externalID == "partner")
        #expect(restored.sessionToken == "TOKEN")
    }
}

struct STSAssumeRoleResponseParserTests {
    @Test
    func parsesTemporaryCredentials() throws {
        let xml = """
        <AssumeRoleResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
          <AssumeRoleResult>
            <Credentials>
              <AccessKeyId>ASIAFIXTURE</AccessKeyId>
              <SecretAccessKey>TEMP-SECRET</SecretAccessKey>
              <SessionToken>TEMP-TOKEN</SessionToken>
              <Expiration>2026-11-27T13:00:00Z</Expiration>
            </Credentials>
          </AssumeRoleResult>
        </AssumeRoleResponse>
        """

        let temporary = try STSAssumeRoleResponseParser().parse(data: Data(xml.utf8))

        #expect(temporary.credentials == S3Credentials(
            accessKeyID: "ASIAFIXTURE",
            secretAccessKey: "TEMP-SECRET",
            sessionToken: "TEMP-TOKEN"
        ))
        #expect(temporary.expiration == Date(timeIntervalSince1970: 1_795_784_400))
    }

    @Test
    func responseWithoutCredentialsIsRejected() {
        #expect(throws: STSError.invalidResponse) {
            try STSAssumeRoleResponseParser().parse(data: Data("<AssumeRoleResponse/>".utf8))
        }
    }
}

struct STSEndpointTests {
    @Test
    func awsS3EndpointUsesRegionalSTS() {
        #expect(
            STSHTTPClient.endpoint(forS3Endpoint: URL(string: "https://s3.amazonaws.com")!, region: "eu-west-1")
                == URL(string: "https://sts.eu-west-1.amazonaws.com")
        )
    }

    @Test
    func compatibleEndpointServesSTSItself() {
        // MinIO answers AssumeRole on the same endpoint as S3.
        #expect(
            STSHTTPClient.endpoint(forS3Endpoint: URL(string: "http://minio.local:9000")!, region: "us-east-1")
                == URL(string: "http://minio.local:9000")
        )
    }
}

@Suite(.serialized)
struct STSHTTPClientTests {
    private let host = "sts.ap-northeast-1.amazonaws.com"

    private func makeClient() -> STSHTTPClient {
        STSHTTPClient(
            endpointURL: URL(string: "https://\(host)")!,
            region: "ap-northeast-1",
            session: StubURLProtocol.makeSession()
        )
    }

    @Test
    func assumeRolePostsASignedFormAndParsesCredentials() async throws {
        StubURLProtocol.reset(host: host, responses: [
            """
            <AssumeRoleResponse><AssumeRoleResult><Credentials>\
            <AccessKeyId>ASIAFIXTURE</AccessKeyId><SecretAccessKey>TEMP-SECRET</SecretAccessKey>\
            <SessionToken>TEMP-TOKEN</SessionToken><Expiration>2026-11-27T13:00:00Z</Expiration>\
            </Credentials></AssumeRoleResult></AssumeRoleResponse>
            """,
        ])

        let temporary = try await makeClient().assumeRole(
            AssumeRoleSettings(roleARN: "arn:aws:iam::123456789012:role/Reader", externalID: "partner"),
            using: S3Credentials(accessKeyID: "AKIAFIXTURE", secretAccessKey: "SECRET", sessionToken: "BASE-TOKEN")
        )

        #expect(temporary.credentials.accessKeyID == "ASIAFIXTURE")
        let recorded = try #require(StubURLProtocol.recordedRequests(host: host).first)
        #expect(recorded.request.httpMethod == "POST")
        #expect(recorded.request.url?.absoluteString == "https://\(host)/")
        #expect(recorded.request.value(forHTTPHeaderField: "X-Amz-Security-Token") == "BASE-TOKEN")
        let authorization = try #require(recorded.request.value(forHTTPHeaderField: "Authorization"))
        #expect(authorization.contains("/ap-northeast-1/sts/aws4_request,"))

        let form = Dictionary(
            uniqueKeysWithValues: String(decoding: recorded.body, as: UTF8.self)
                .split(separator: "&")
                .map { pair -> (String, String) in
                    let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                    return (parts[0], parts[1].removingPercentEncoding ?? parts[1])
                }
        )
        #expect(form["Action"] == "AssumeRole")
        #expect(form["Version"] == "2011-06-15")
        #expect(form["RoleArn"] == "arn:aws:iam::123456789012:role/Reader")
        #expect(form["ExternalId"] == "partner")
        #expect(form["DurationSeconds"] == "3600")
        #expect(form["RoleSessionName"]?.hasPrefix("S4Viewer-") == true)
    }

    @Test
    func stsErrorMessageSurfaces() async {
        StubURLProtocol.reset(host: host, statusResponses: [(
            status: 403,
            body: """
            <ErrorResponse><Error><Code>AccessDenied</Code>\
            <Message>User is not authorized to perform: sts:AssumeRole</Message></Error></ErrorResponse>
            """
        )])

        await #expect(throws: STSError.httpFailure(statusCode: 403, message: "User is not authorized to perform: sts:AssumeRole")) {
            _ = try await makeClient().assumeRole(
                AssumeRoleSettings(roleARN: "arn:aws:iam::123456789012:role/Reader", externalID: nil),
                using: S3Credentials(accessKeyID: "AKIAFIXTURE", secretAccessKey: "SECRET")
            )
        }
    }
}

struct TemporaryCredentialProviderTests {
    private let settings = AssumeRoleSettings(roleARN: "arn:aws:iam::123456789012:role/Reader", externalID: nil)
    private let base = S3Credentials(accessKeyID: "AKIAFIXTURE", secretAccessKey: "SECRET")

    private func temporary(_ name: String, expiresAt expiration: Date) -> TemporaryCredentials {
        TemporaryCredentials(
            credentials: S3Credentials(accessKeyID: name, secretAccessKey: "TEMP-SECRET", sessionToken: "TEMP-TOKEN"),
            expiration: expiration
        )
    }

    @Test
    func reusesCredentialsUntilTheRefreshMarginThenAssumesAgain() async throws {
        let clock = Mutex(Date(timeIntervalSince1970: 0))
        let calls = Mutex(0)
        let provider = TemporaryCredentialProvider(refreshMargin: 300, now: { clock.withLock { $0 } })
        let profileID = UUID()
        let assume: @Sendable () async throws -> TemporaryCredentials = {
            let call = calls.withLock { $0 += 1; return $0 }
            return temporary("ASIA\(call)", expiresAt: Date(timeIntervalSince1970: 3_600 * Double(call)))
        }

        let first = try await provider.credentials(for: profileID, settings: settings, base: base, assume: assume)
        clock.withLock { $0 = Date(timeIntervalSince1970: 3_299) }
        let cached = try await provider.credentials(for: profileID, settings: settings, base: base, assume: assume)
        clock.withLock { $0 = Date(timeIntervalSince1970: 3_301) }
        let refreshed = try await provider.credentials(for: profileID, settings: settings, base: base, assume: assume)

        #expect(first.accessKeyID == "ASIA1")
        #expect(cached.accessKeyID == "ASIA1")
        #expect(refreshed.accessKeyID == "ASIA2")
        #expect(calls.withLock { $0 } == 2)
    }

    @Test
    func changedBaseKeysOrRoleAssumeAgain() async throws {
        let calls = Mutex(0)
        let provider = TemporaryCredentialProvider(now: { Date(timeIntervalSince1970: 0) })
        let profileID = UUID()
        let assume: @Sendable () async throws -> TemporaryCredentials = {
            calls.withLock { $0 += 1 }
            return temporary("ASIA", expiresAt: Date(timeIntervalSince1970: 3_600))
        }

        _ = try await provider.credentials(for: profileID, settings: settings, base: base, assume: assume)
        _ = try await provider.credentials(
            for: profileID,
            settings: settings,
            base: S3Credentials(accessKeyID: "AKIAFIXTURE", secretAccessKey: "ROTATED"),
            assume: assume
        )
        _ = try await provider.credentials(
            for: profileID,
            settings: AssumeRoleSettings(roleARN: settings.roleARN, externalID: "partner"),
            base: base,
            assume: assume
        )

        #expect(calls.withLock { $0 } == 3)
    }

    @Test
    func concurrentRequestsShareOneAssumeRole() async throws {
        let calls = Mutex(0)
        let provider = TemporaryCredentialProvider(now: { Date(timeIntervalSince1970: 0) })
        let profileID = UUID()
        let assume: @Sendable () async throws -> TemporaryCredentials = {
            calls.withLock { $0 += 1 }
            try await Task.sleep(for: .milliseconds(50))
            return temporary("ASIA", expiresAt: Date(timeIntervalSince1970: 3_600))
        }

        try await withThrowingTaskGroup(of: S3Credentials.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await provider.credentials(for: profileID, settings: settings, base: base, assume: assume)
                }
            }
            for try await credentials in group {
                #expect(credentials.accessKeyID == "ASIA")
            }
        }

        #expect(calls.withLock { $0 } == 1)
    }

    @Test
    func failedAssumeRoleIsNotCached() async throws {
        let calls = Mutex(0)
        let provider = TemporaryCredentialProvider(now: { Date(timeIntervalSince1970: 0) })
        let profileID = UUID()
        let assume: @Sendable () async throws -> TemporaryCredentials = {
            let call = calls.withLock { $0 += 1; return $0 }
            if call == 1 {
                throw STSError.httpFailure(statusCode: 403, message: "denied")
            }
            return temporary("ASIA", expiresAt: Date(timeIntervalSince1970: 3_600))
        }

        await #expect(throws: STSError.self) {
            _ = try await provider.credentials(for: profileID, settings: settings, base: base, assume: assume)
        }
        let recovered = try await provider.credentials(for: profileID, settings: settings, base: base, assume: assume)

        #expect(recovered.accessKeyID == "ASIA")
    }
}

@MainActor
struct S3BrowserModelAssumeRoleTests {
    @Test
    func roleProfileBrowsesWithTemporaryCredentialsAndAssumesOnce() async throws {
        let client = FakeS3Client(buckets: [])
        let sts = FakeSTSClient()
        let model = S3BrowserModel(
            clientFactory: { configuration in
                client.recordConfiguration(configuration)
                return client
            },
            credentialProvider: { _ in S3Credentials(accessKeyID: "AKIAFIXTURE", secretAccessKey: "SECRET") },
            stsClientFactory: { endpoint, region in
                sts.recordEndpoint(endpoint, region: region)
                return sts
            },
            temporaryCredentials: TemporaryCredentialProvider(now: { Date(timeIntervalSince1970: 0) })
        )
        let profile = ConnectionProfile(
            name: "Work",
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: "media",
            usePathStyle: false,
            roleARN: "arn:aws:iam::123456789012:role/Reader",
            externalID: ""
        )

        await model.connect(to: profile)
        await model.refresh(using: profile)

        #expect(model.errorMessage == nil)
        #expect(client.configurations.count == 2)
        #expect(client.configurations.allSatisfy {
            $0.credentials == S3Credentials(accessKeyID: "ASIAFIXTURE", secretAccessKey: "TEMP-SECRET", sessionToken: "TEMP-TOKEN")
        })
        #expect(sts.assumedRoles == ["arn:aws:iam::123456789012:role/Reader"])
        #expect(Set(sts.endpoints) == ["https://sts.us-east-1.amazonaws.com us-east-1"])
    }

    @Test
    func assumeRoleFailureIsReported() async {
        let sts = FakeSTSClient(failure: STSError.httpFailure(statusCode: 403, message: "denied"))
        let model = S3BrowserModel(
            clientFactory: { _ in FakeS3Client(buckets: []) },
            credentialProvider: { _ in S3Credentials(accessKeyID: "AKIAFIXTURE", secretAccessKey: "SECRET") },
            stsClientFactory: { _, _ in sts },
            temporaryCredentials: TemporaryCredentialProvider()
        )
        let profile = ConnectionProfile(
            name: "Work",
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: "media",
            usePathStyle: false,
            roleARN: "arn:aws:iam::123456789012:role/Reader",
            externalID: ""
        )

        await model.connect(to: profile)

        #expect(model.errorMessage == "AssumeRole failed with status 403: denied")
    }
}

final class FakeSTSClient: STSClientProtocol, Sendable {
    private struct State {
        var endpoints: [String] = []
        var assumedRoles: [String] = []
    }

    private let state = Mutex(State())
    private let failure: STSError?

    init(failure: STSError? = nil) {
        self.failure = failure
    }

    var endpoints: [String] { state.withLock { $0.endpoints } }
    var assumedRoles: [String] { state.withLock { $0.assumedRoles } }

    func recordEndpoint(_ endpoint: URL, region: String) {
        state.withLock { $0.endpoints.append("\(endpoint.absoluteString) \(region)") }
    }

    func assumeRole(_ settings: AssumeRoleSettings, using credentials: S3Credentials) async throws -> TemporaryCredentials {
        state.withLock { $0.assumedRoles.append(settings.roleARN) }
        if let failure {
            throw failure
        }
        return TemporaryCredentials(
            credentials: S3Credentials(accessKeyID: "ASIAFIXTURE", secretAccessKey: "TEMP-SECRET", sessionToken: "TEMP-TOKEN"),
            expiration: Date(timeIntervalSince1970: 3_600)
        )
    }
}
