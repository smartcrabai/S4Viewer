import Foundation
import Synchronization
import Testing
@testable import S4_Viewer

struct S3ListBucketsResponseParserTests {
    @Test
    func parsesBucketsRegionsAndContinuationToken() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
            <Owner><ID>owner</ID></Owner>
            <Buckets>
                <Bucket>
                    <Name>logs</Name>
                    <CreationDate>2024-01-02T03:04:05.000Z</CreationDate>
                    <BucketRegion>eu-west-1</BucketRegion>
                </Bucket>
                <Bucket>
                    <Name>media</Name>
                    <CreationDate>2024-02-03T04:05:06Z</CreationDate>
                </Bucket>
            </Buckets>
            <ContinuationToken>next-page</ContinuationToken>
        </ListAllMyBucketsResult>
        """

        let page = try S3ListBucketsResponseParser().parse(data: Data(xml.utf8))

        #expect(page.buckets.map(\.name) == ["logs", "media"])
        #expect(page.buckets.map(\.region) == ["eu-west-1", nil])
        #expect(page.buckets[0].createdAt == Date(timeIntervalSince1970: 1_704_164_645))
        #expect(page.continuationToken == "next-page")
    }

    @Test
    func emptyBucketListHasNoContinuation() throws {
        let xml = """
        <ListAllMyBucketsResult><Buckets/></ListAllMyBucketsResult>
        """

        let page = try S3ListBucketsResponseParser().parse(data: Data(xml.utf8))

        #expect(page.buckets.isEmpty)
        #expect(page.continuationToken == nil)
    }
}

struct S3ConnectionConfigurationScopingTests {
    private func configuration(endpoint: String, region: String = "us-east-1") -> S3ConnectionConfiguration {
        S3ConnectionConfiguration(
            name: "Work",
            endpointURL: URL(string: endpoint)!,
            region: region,
            bucket: "",
            credentials: S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET"),
            usePathStyle: false
        )
    }

    @Test
    func awsEndpointFollowsTheBucketRegion() {
        let scoped = configuration(endpoint: "https://s3.us-east-1.amazonaws.com")
            .scoped(to: S3Bucket(name: "logs", region: "eu-west-1", createdAt: nil))

        #expect(scoped.bucket == "logs")
        #expect(scoped.region == "eu-west-1")
        #expect(scoped.endpointURL == URL(string: "https://s3.eu-west-1.amazonaws.com"))
    }

    @Test
    func globalAWSEndpointFollowsTheBucketRegion() {
        let scoped = configuration(endpoint: "https://s3.amazonaws.com")
            .scoped(to: S3Bucket(name: "logs", region: "ap-northeast-1", createdAt: nil))

        #expect(scoped.region == "ap-northeast-1")
        #expect(scoped.endpointURL == URL(string: "https://s3.ap-northeast-1.amazonaws.com"))
    }

    @Test
    func compatibleEndpointKeepsProfileRegionAndHost() {
        let scoped = configuration(endpoint: "https://minio.example.com:9000", region: "auto")
            .scoped(to: S3Bucket(name: "logs", region: "eu-west-1", createdAt: nil))

        #expect(scoped.bucket == "logs")
        #expect(scoped.region == "auto")
        #expect(scoped.endpointURL == URL(string: "https://minio.example.com:9000"))
    }

    @Test
    func bucketWithoutRegionKeepsProfileRegion() {
        let scoped = configuration(endpoint: "https://s3.us-east-1.amazonaws.com")
            .scoped(to: S3Bucket(name: "logs", region: nil, createdAt: nil))

        #expect(scoped.region == "us-east-1")
        #expect(scoped.endpointURL == URL(string: "https://s3.us-east-1.amazonaws.com"))
    }
}

@Suite(.serialized)
struct S3HTTPClientListBucketsTests {
    private func makeClient(usePathStyle: Bool) -> S3HTTPClient {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [StubURLProtocol.self]
        return S3HTTPClient(
            configuration: S3ConnectionConfiguration(
                name: "Work",
                endpointURL: URL(string: "https://s3.us-east-1.amazonaws.com")!,
                region: "us-east-1",
                bucket: "",
                credentials: S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET"),
                usePathStyle: usePathStyle
            ),
            session: URLSession(configuration: sessionConfiguration)
        )
    }

    @Test(arguments: [false, true])
    func listsBucketsFromServiceRootAndFollowsContinuation(usePathStyle: Bool) async throws {
        StubURLProtocol.reset(host: "s3.us-east-1.amazonaws.com", responses: [
            """
            <ListAllMyBucketsResult><Buckets><Bucket><Name>logs</Name></Bucket></Buckets>\
            <ContinuationToken>page-2</ContinuationToken></ListAllMyBucketsResult>
            """,
            """
            <ListAllMyBucketsResult><Buckets><Bucket><Name>media</Name></Bucket></Buckets></ListAllMyBucketsResult>
            """,
        ])

        let buckets = try await makeClient(usePathStyle: usePathStyle).listBuckets()

        #expect(buckets.map(\.name) == ["logs", "media"])
        let requests = StubURLProtocol.recordedRequests(host: "s3.us-east-1.amazonaws.com").map(\.request)
        #expect(requests.map { $0.url?.absoluteString } == [
            "https://s3.us-east-1.amazonaws.com/",
            "https://s3.us-east-1.amazonaws.com/?continuation-token=page-2",
        ])
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization")?.hasPrefix("AWS4-HMAC-SHA256") == true })
    }
}

@MainActor
struct S3BrowserModelAllBucketsTests {
    private let buckets = [
        S3Bucket(name: "logs", region: "eu-west-1", createdAt: nil),
        S3Bucket(name: "media", region: nil, createdAt: nil),
    ]

    private func makeProfile(bucket: String) -> ConnectionProfile {
        ConnectionProfile(
            name: "Work",
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: bucket,
            usePathStyle: false
        )
    }

    private func makeModel(client: FakeS3Client) -> S3BrowserModel {
        S3BrowserModel(
            clientFactory: { configuration in
                client.recordConfiguration(configuration)
                return client
            },
            credentialProvider: { _ in S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET") }
        )
    }

    @Test
    func profileWithoutBucketListsEveryBucketAtTheRoot() async {
        let client = FakeS3Client(buckets: buckets)
        let model = makeModel(client: client)

        await model.connect(to: makeProfile(bucket: ""))

        #expect(model.errorMessage == nil)
        #expect(model.items.map(\.key) == ["logs", "media"])
        #expect(model.items.allSatisfy { $0.kind == .bucket })
        #expect(model.isAtBucketList)
        #expect(model.canNavigateUp == false)
        #expect(model.currentLocationTitle == "/")
    }

    @Test
    func openingABucketListsItsObjectsWithTheBucketScopedConfiguration() async {
        let client = FakeS3Client(buckets: buckets)
        let model = makeModel(client: client)
        let profile = makeProfile(bucket: "")

        await model.connect(to: profile)
        await model.openFolder(withKey: "logs", using: profile)

        #expect(model.errorMessage == nil)
        #expect(model.isAtBucketList == false)
        #expect(model.items.map(\.key) == ["2026/", "app.log"])
        #expect(model.currentLocationTitle == "/logs/")
        #expect(model.canNavigateUp)
        let configuration = client.configurations.last
        #expect(configuration?.bucket == "logs")
        #expect(configuration?.region == "eu-west-1")
        #expect(configuration?.endpointURL == URL(string: "https://s3.eu-west-1.amazonaws.com"))

        await model.openFolder(withKey: "2026/", using: profile)
        #expect(model.currentLocationTitle == "/logs/2026/")
    }

    @Test
    func navigatingUpFromABucketRootReturnsToTheBucketList() async {
        let client = FakeS3Client(buckets: buckets)
        let model = makeModel(client: client)
        let profile = makeProfile(bucket: "")

        await model.connect(to: profile)
        await model.openFolder(withKey: "media", using: profile)
        await model.navigateUp(using: profile)

        #expect(model.isAtBucketList)
        #expect(model.items.map(\.key) == ["logs", "media"])
        #expect(model.currentLocationTitle == "/")
    }

    @Test
    func bucketListRejectsObjectMutations() async {
        let client = FakeS3Client(buckets: buckets)
        let model = makeModel(client: client)
        let profile = makeProfile(bucket: "")

        await model.connect(to: profile)
        await model.createFolder(named: "new", using: profile)

        #expect(client.createdFolders.isEmpty)
        await model.selectItem(withKey: "logs", using: profile)
        if case let .empty(message) = model.previewState {
            #expect(message == "Buckets do not have a preview.")
        } else {
            Issue.record("a bucket must not load a preview")
        }
    }

    @Test
    func profileWithBucketKeepsBrowsingThatBucketOnly() async {
        let client = FakeS3Client(buckets: buckets)
        let model = makeModel(client: client)

        await model.connect(to: makeProfile(bucket: "media"))

        #expect(client.listedBuckets == 0)
        #expect(model.isAtBucketList == false)
        #expect(model.items.map(\.key) == ["2026/", "app.log"])
        #expect(model.currentLocationTitle == "/")
        #expect(model.canNavigateUp == false)
        #expect(client.configurations.last?.bucket == "media")
    }
}

final class FakeS3Client: S3ClientProtocol, Sendable {
    private struct State {
        var configurations: [S3ConnectionConfiguration] = []
        var listedBuckets = 0
        var createdFolders: [String] = []
    }

    private let buckets: [S3Bucket]
    private let state = Mutex(State())

    init(buckets: [S3Bucket]) {
        self.buckets = buckets
    }

    var configurations: [S3ConnectionConfiguration] { state.withLock { $0.configurations } }
    var listedBuckets: Int { state.withLock { $0.listedBuckets } }
    var createdFolders: [String] { state.withLock { $0.createdFolders } }

    func recordConfiguration(_ configuration: S3ConnectionConfiguration) {
        state.withLock { $0.configurations.append(configuration) }
    }

    func listBuckets() async throws -> [S3Bucket] {
        state.withLock { $0.listedBuckets += 1 }
        return buckets
    }

    func list(prefix: String) async throws -> S3ListObjectsPage {
        let items: [S3BrowserItem] = prefix.isEmpty
            ? [.folder(key: "2026/"), .object(key: "app.log", size: 1, modifiedAt: nil, eTag: nil, contentType: nil)]
            : [.object(key: prefix + "day.log", size: 1, modifiedAt: nil, eTag: nil, contentType: nil)]
        return S3ListObjectsPage(items: items, nextContinuationToken: nil)
    }

    func createFolder(named folderName: String, in prefix: String) async throws {
        state.withLock { $0.createdFolders.append(prefix + folderName) }
    }

    func rename(item: S3BrowserItem, to newName: String) async throws -> String { item.key }
    func delete(item: S3BrowserItem) async throws {}
    func uploadFile(at fileURL: URL, to prefix: String, progress: @escaping @Sendable (Double) -> Void) async throws {}
    func download(item: S3BrowserItem, to destinationURL: URL, progress: @escaping @Sendable (Double) -> Void) async throws {}
    func preparePreview(
        for item: S3BrowserItem,
        in directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        throw S3ClientError.previewUnavailable
    }
}
