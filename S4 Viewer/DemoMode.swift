#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only fixture mode. It populates the UI with representative data for screenshots
/// and makes the UI test suite runnable without a real S3 endpoint, a Keychain item, or a
/// system file panel. Enable it by passing `-S4ViewerDemoData` as a launch argument.
nonisolated enum DemoMode {
    static let launchArgument = "-S4ViewerDemoData"

    static var isEnabled: Bool {
#if S4VIEWER_INTENT_TESTING
        true
#else
        ProcessInfo.processInfo.arguments.contains(launchArgument)
            || ProcessInfo.processInfo.environment["S4VIEWER_DEMO_MODE"] == "1"
#endif
    }

    static let credentials = S3Credentials(
        accessKeyID: "DEMOACCESSKEY",
        secretAccessKey: "DEMOSECRETKEY"
    )

    static func makeProfile() -> ConnectionProfile {
        ConnectionProfile(
            name: "Production Media",
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: "smartcrab-media",
            usePathStyle: false
        )
    }

    @MainActor
    static func makeContainer(schema: Schema) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let profile = makeProfile()
        container.mainContext.insert(profile)
        try container.mainContext.save()
        // `shared` is the in-memory store while demo mode is on, so the editor can show
        // credentials that were "read back" the way a real profile would.
        try ConnectionCredentialStore.shared.save(credentials, for: profile.id)
        return container
    }

    /// Stands in for `NSSavePanel`: UI tests exercise the download path but cannot drive a
    /// system panel.
    static func downloadDestination(suggestedName: String) -> URL? {
        guard let directory = makeWorkingDirectory(named: "downloads") else {
            return nil
        }
        return directory.appending(path: suggestedName)
    }

    /// Stands in for the system file importer, for the same reason. Three files exercise the
    /// concurrent upload path.
    // ponytail: fixed three-fixture case; add a count only for a new test scenario.
    static func makeUploadFixtures() throws -> [URL] {
        guard let directory = makeWorkingDirectory(named: "uploads") else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try (1...3).map { index in
            let url = directory.appending(path: "fixture-\(index).txt")
            let body = String(repeating: "demo upload \(index)\n", count: 128)
            try Data(body.utf8).write(to: url, options: .atomic)
            return url
        }
    }

    private static func makeWorkingDirectory(named name: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "S4ViewerDemo", directoryHint: .isDirectory)
            .appending(path: name, directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }
}

nonisolated enum DemoS3Error: LocalizedError, Equatable {
    case notFound(String)
    case alreadyExists(String)
    case invalidName(String)

    var errorDescription: String? {
        switch self {
        case let .notFound(key):
            return "\(key.lastS3PathComponent) no longer exists in this bucket."
        case let .alreadyExists(key):
            return "An item named \(key.lastS3PathComponent) already exists here."
        case let .invalidName(value):
            return "Enter a valid name. \"\(value)\" is not allowed here."
        }
    }
}

/// In-memory stand-in for a bucket. Shared statically because `S3BrowserModel` builds a
/// fresh client for every request, so mutations have to outlive a single call. Each app
/// launch starts from the seeded fixture set, which is what isolates one UI test from the
/// next.
actor DemoBucket {
    static let shared = DemoBucket()

    private struct StoredObject {
        var size: Int64
        var modifiedAt: Date
        var contentType: String?
        var data: Data
    }

    private static let textBody = """
    # Release Notes

    - Multipart uploads switch on automatically above 8 MiB.
    - Folders stay pinned above files in every sort mode.
    - Inline preview renders text-like objects without downloading them twice.
    """

    private static let pdfBody = Data(base64Encoded: "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCA2MTIgNzkyXSAvQ29udGVudHMgNCAwIFIgL1Jlc291cmNlcyA8PCAvRm9udCA8PCAvRjEgNSAwIFIgPj4gPj4gPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCA0OCA+PgpzdHJlYW0KQlQKL0YxIDI0IFRmCjcyIDcyMCBUZAooUXVhcnRlcmx5IFJlcG9ydCkgVGoKRVQKZW5kc3RyZWFtCmVuZG9iago1IDAgb2JqCjw8IC9UeXBlIC9Gb250IC9TdWJ0eXBlIC9UeXBlMSAvQmFzZUZvbnQgL0hlbHZldGljYSA+PgplbmRvYmoKeHJlZgowIDYKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDE1IDAwMDAwIG4gCjAwMDAwMDAwNjQgMDAwMDAgbiAKMDAwMDAwMDEyMSAwMDAwMCBuIAowMDAwMDAwMjQ3IDAwMDAwIG4gCjAwMDAwMDAzNDQgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA2IC9Sb290IDEgMCBSID4+CnN0YXJ0eHJlZgo0MTQKJSVFT0YK")!

    private var folders: Set<String>
    private var objects: [String: StoredObject]

    init() {
        let fixtures = Self.makeFixtures()
        folders = fixtures.folders
        objects = fixtures.objects
    }

    /// Restores the fixture set. `ResetDemoBucketIntent` calls this so an automated run can
    /// start from a known state without relaunching the app.
    func reset() {
        let fixtures = Self.makeFixtures()
        folders = fixtures.folders
        objects = fixtures.objects
    }

    private static func makeFixtures() -> (folders: Set<String>, objects: [String: StoredObject]) {
        let now = Date.now
        let folders: Set<String> = [
            "campaigns/",
            "campaigns/2026-spring/",
            "exports/",
            "raw-footage/",
        ]
        var objects: [String: StoredObject] = [:]

        func seed(
            _ key: String,
            _ size: Int64,
            _ modifiedAt: Date,
            _ contentType: String,
            data: Data? = nil
        ) {
            objects[key] = StoredObject(
                size: size,
                modifiedAt: modifiedAt,
                contentType: contentType,
                data: data ?? Data(textBody.utf8)
            )
        }

        seed("release-notes.md", 4_182, now.addingTimeInterval(-3_600), "text/markdown")
        seed(
            "quarterly-report.pdf",
            2_486_912,
            now.addingTimeInterval(-86_400),
            "application/pdf",
            data: pdfBody
        )
        seed("keynote-recording.mov", 1_073_741_824, now.addingTimeInterval(-172_800), "video/quicktime")
        seed("product-hero.png", 8_388_608, now.addingTimeInterval(-259_200), "image/png")
        seed("inventory-2026.csv", 512_000, now.addingTimeInterval(-604_800), "text/csv")
        seed("archive-2025.bin", 65_536, now.addingTimeInterval(-1_209_600), "application/octet-stream")
        seed("campaigns/brief.md", 2_048, now.addingTimeInterval(-7_200), "text/markdown")
        seed("exports/report-q1.csv", 96_000, now.addingTimeInterval(-43_200), "text/csv")

        return (folders, objects)
    }

    func children(of prefix: String) -> [S3BrowserItem] {
        let folderItems = folders
            .filter { isImmediateChild($0, of: prefix) }
            .map(S3BrowserItem.folder(key:))
        let objectItems = objects.compactMap { key, stored -> S3BrowserItem? in
            guard isImmediateChild(key, of: prefix) else {
                return nil
            }
            return .object(
                key: key,
                size: stored.size,
                modifiedAt: stored.modifiedAt,
                eTag: nil,
                contentType: stored.contentType
            )
        }
        return folderItems + objectItems
    }

    func createFolder(named folderName: String, in prefix: String) throws {
        let normalized = try validateSinglePathComponent(folderName)
        let key = prefix + normalized + "/"
        guard !folders.contains(key) else {
            throw DemoS3Error.alreadyExists(key)
        }
        folders.insert(key)
    }

    func putObject(named name: String, in prefix: String, data: Data) {
        objects[prefix + name] = StoredObject(
            size: Int64(data.count),
            modifiedAt: .now,
            contentType: "text/plain",
            data: data
        )
    }

    func rename(_ item: S3BrowserItem, to newName: String) throws -> String {
        let parent = item.key.parentS3Prefix

        switch item.kind {
        case .object:
            let normalized = try validateSinglePathComponent(newName)
            guard let stored = objects.removeValue(forKey: item.key) else {
                throw DemoS3Error.notFound(item.key)
            }
            let newKey = parent + normalized
            guard objects[newKey] == nil else {
                objects[item.key] = stored
                throw DemoS3Error.alreadyExists(newKey)
            }
            objects[newKey] = stored
            return newKey
        case .folder:
            let normalized = try validateSinglePathComponent(newName)
            let newKey = parent + normalized + "/"
            guard folders.contains(item.key) else {
                throw DemoS3Error.notFound(item.key)
            }
            guard !folders.contains(newKey) else {
                throw DemoS3Error.alreadyExists(newKey)
            }
            folders = Set(folders.map { replacingPrefix($0, item.key, with: newKey) })
            objects = Dictionary(
                uniqueKeysWithValues: objects.map { (replacingPrefix($0.key, item.key, with: newKey), $0.value) }
            )
            return newKey
        }
    }

    func delete(_ item: S3BrowserItem) throws {
        switch item.kind {
        case .object:
            guard objects.removeValue(forKey: item.key) != nil else {
                throw DemoS3Error.notFound(item.key)
            }
        case .folder:
            guard folders.remove(item.key) != nil else {
                throw DemoS3Error.notFound(item.key)
            }
            folders = folders.filter { !$0.hasPrefix(item.key) }
            objects = objects.filter { !$0.key.hasPrefix(item.key) }
        }
    }

    func data(for item: S3BrowserItem) throws -> Data {
        guard let stored = objects[item.key] else {
            throw DemoS3Error.notFound(item.key)
        }
        return stored.data
    }

    private func validateSinglePathComponent(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalized.isEmpty, !normalized.contains("/") else {
            throw DemoS3Error.invalidName(value)
        }
        return normalized
    }

    private func isImmediateChild(_ key: String, of prefix: String) -> Bool {
        guard key.hasPrefix(prefix), key != prefix else {
            return false
        }
        let remainder = String(key.dropFirst(prefix.count)).trimmingTrailingSlashes
        return !remainder.isEmpty && !remainder.contains("/")
    }

    private func replacingPrefix(_ key: String, _ oldPrefix: String, with newPrefix: String) -> String {
        guard key.hasPrefix(oldPrefix) else {
            return key
        }
        return newPrefix + key.dropFirst(oldPrefix.count)
    }
}

nonisolated final class DemoS3Client: S3ClientProtocol {
    private let bucket: DemoBucket

    init(bucket: DemoBucket = .shared) {
        self.bucket = bucket
    }

    func list(prefix: String) async throws -> S3ListObjectsPage {
        S3ListObjectsPage(items: await bucket.children(of: prefix), nextContinuationToken: nil)
    }

    func createFolder(named folderName: String, in prefix: String) async throws {
        try await bucket.createFolder(named: folderName, in: prefix)
    }

    func rename(item: S3BrowserItem, to newName: String) async throws -> String {
        try await bucket.rename(item, to: newName)
    }

    func delete(item: S3BrowserItem) async throws {
        try await bucket.delete(item)
    }

    func uploadFile(
        at fileURL: URL,
        to prefix: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let data = try Data(contentsOf: fileURL)
        try await reportProgress(progress)
        await bucket.putObject(named: fileURL.lastPathComponent, in: prefix, data: data)
    }

    func download(
        item: S3BrowserItem,
        to destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let data = try await bucket.data(for: item)
        try await reportProgress(progress)
        try data.write(to: destinationURL, options: .atomic)
    }

    func preparePreview(
        for item: S3BrowserItem,
        in directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let data = try await bucket.data(for: item)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(item.name)
        try data.write(to: url, options: .atomic)
        progress(1)
        return url
    }

    private func reportProgress(_ progress: @escaping @Sendable (Double) -> Void) async throws {
        for step in 1...5 {
            try await Task.sleep(for: .milliseconds(120))
            progress(Double(step) / 5)
        }
    }
}
#endif
