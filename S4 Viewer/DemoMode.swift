#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only fixture mode used to populate the UI with representative data for screenshots.
/// Enable it by passing `-S4ViewerDemoData` as a launch argument.
nonisolated enum DemoMode {
    static let launchArgument = "-S4ViewerDemoData"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static let credentials = S3Credentials(
        accessKeyID: "DEMOACCESSKEY",
        secretAccessKey: "DEMOSECRETKEY"
    )

    @MainActor
    static func makeContainer(schema: Schema) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let profile = ConnectionProfile(
            name: "Production Media",
            endpoint: "https://s3.us-east-1.amazonaws.com",
            region: "us-east-1",
            bucket: "smartcrab-media",
            usePathStyle: false
        )
        container.mainContext.insert(profile)
        try container.mainContext.save()
        return container
    }
}

nonisolated final class DemoS3Client: S3ClientProtocol {
    private static let previewText = """
    # Release Notes

    - Multipart uploads switch on automatically above 8 MiB.
    - Folders stay pinned above files in every sort mode.
    - Inline preview renders text-like objects without downloading them twice.
    """

    func list(prefix: String) async throws -> S3ListObjectsPage {
        guard prefix.isEmpty else {
            return S3ListObjectsPage(items: [], nextContinuationToken: nil)
        }
        let now = Date.now
        return S3ListObjectsPage(
            items: [
                .folder(key: "campaigns/"),
                .folder(key: "exports/"),
                .folder(key: "raw-footage/"),
                object("release-notes.md", 4_182, now.addingTimeInterval(-3_600)),
                object("quarterly-report.pdf", 2_486_912, now.addingTimeInterval(-86_400)),
                object("keynote-recording.mov", 1_073_741_824, now.addingTimeInterval(-172_800)),
                object("product-hero.png", 8_388_608, now.addingTimeInterval(-259_200)),
                object("inventory-2026.csv", 512_000, now.addingTimeInterval(-604_800)),
            ],
            nextContinuationToken: nil
        )
    }

    func createFolder(named folderName: String, in prefix: String) async throws {}

    func rename(item: S3BrowserItem, to newName: String) async throws -> String {
        newName
    }

    func delete(item: S3BrowserItem) async throws {}

    func uploadFile(
        at fileURL: URL,
        to prefix: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await reportProgress(progress)
    }

    func download(
        item: S3BrowserItem,
        to destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await reportProgress(progress)
        try Data(Self.previewText.utf8).write(to: destinationURL, options: .atomic)
    }

    func preparePreview(
        for item: S3BrowserItem,
        in directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(item.name)
        try Data(Self.previewText.utf8).write(to: url, options: .atomic)
        progress(1)
        return url
    }

    private func object(_ name: String, _ size: Int64, _ modifiedAt: Date) -> S3BrowserItem {
        .object(key: name, size: size, modifiedAt: modifiedAt, eTag: nil, contentType: nil)
    }

    private func reportProgress(_ progress: @escaping @Sendable (Double) -> Void) async throws {
        for step in 1...5 {
            try await Task.sleep(for: .milliseconds(200))
            progress(Double(step) / 5)
        }
    }
}
#endif
