import Foundation
import Observation

struct BrowserPreviewContent {
    let item: S3BrowserItem
    let kind: ObjectPreviewKind
    let localURL: URL
    let text: String?
}

enum BrowserPreviewState {
    case empty(String)
    case loading
    case ready(BrowserPreviewContent)
    case failed(String)
}

struct TransferActivity: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case upload
        case download
    }

    enum Status: String, Equatable {
        case running
        case succeeded
        case failed
    }

    let id: UUID
    let name: String
    let kind: Kind
    var progress: Double
    var status: Status
    var message: String?
}

@Observable
final class S3BrowserModel {
    var items: [S3BrowserItem] = []
    var sortMode: S3BrowserSortMode = .nameAscending
    var filterText: String = ""
    private(set) var currentPrefix: String = ""
    private(set) var selectedItemKey: String?
    private(set) var isLoading: Bool = false
    private(set) var previewState: BrowserPreviewState = .empty("Select a file to preview.")
    private(set) var transfers: [TransferActivity] = []
    private(set) var errorMessage: String?

    /// Bucket opened from the bucket list; `nil` at the list itself or for a fixed-bucket profile.
    private(set) var currentBucket: S3Bucket?
    /// The profile leaves the bucket empty, so the root is the `ListBuckets` result.
    private(set) var browsesAllBuckets: Bool = false

    @ObservationIgnored
    private var knownBuckets: [S3Bucket] = []

    @ObservationIgnored
    private let clientFactory: @Sendable (S3ConnectionConfiguration) -> any S3ClientProtocol
    @ObservationIgnored
    private let previewDirectory: URL
    @ObservationIgnored
    private let fileManager: FileManager
    @ObservationIgnored
    private var currentPreviewURL: URL?
    @ObservationIgnored
    private var previewRequestID = UUID()
    @ObservationIgnored
    private let credentialProvider: @Sendable (UUID) throws -> S3Credentials
    @ObservationIgnored
    private let stsClientFactory: @Sendable (URL, String) -> any STSClientProtocol
    @ObservationIgnored
    private let temporaryCredentials: TemporaryCredentialProvider

    init(
        clientFactory: @escaping @Sendable (S3ConnectionConfiguration) -> any S3ClientProtocol = {
            S3HTTPClient(configuration: $0)
        },
        credentialProvider: @escaping @Sendable (UUID) throws -> S3Credentials = {
            try ConnectionCredentialStore.shared.load(for: $0)
        },
        stsClientFactory: @escaping @Sendable (URL, String) -> any STSClientProtocol = {
            STSHTTPClient(endpointURL: $0, region: $1)
        },
        temporaryCredentials: TemporaryCredentialProvider = .shared,
        previewDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("S4ViewerPreviewCache", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.clientFactory = clientFactory
        self.credentialProvider = credentialProvider
        self.stsClientFactory = stsClientFactory
        self.temporaryCredentials = temporaryCredentials
        self.previewDirectory = previewDirectory
        self.fileManager = fileManager
    }

    static func makeDefault() -> S3BrowserModel {
#if DEBUG
        if DemoMode.isEnabled {
            return S3BrowserModel(
                clientFactory: { _ in DemoS3Client() },
                credentialProvider: { _ in DemoMode.credentials },
                stsClientFactory: { _, _ in DemoSTSClient() }
            )
        }
#endif
        return S3BrowserModel()
    }

    var filteredItems: [S3BrowserItem] {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var sortedItems: [S3BrowserItem] {
        sortMode.sorted(filteredItems)
    }

    var isFilterActive: Bool {
        !filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedItem: S3BrowserItem? {
        guard let selectedItemKey else {
            return nil
        }
        return items.first(where: { $0.key == selectedItemKey })
    }

    var isAtBucketList: Bool {
        browsesAllBuckets && currentBucket == nil
    }

    var canNavigateUp: Bool {
        !currentPrefix.isEmpty || (browsesAllBuckets && currentBucket != nil)
    }

    var currentLocationTitle: String {
        let bucketPath = currentBucket.map { $0.name + "/" } ?? ""
        return "/" + bucketPath + currentPrefix
    }

    func connect(to profile: ConnectionProfile?) async {
        resetBrowser()
        guard let profile else {
            previewState = .empty("Create or select a connection profile.")
            return
        }
        await refresh(using: profile)
    }

    func refresh(using profile: ConnectionProfile) async {
        do {
            browsesAllBuckets = profile.bucket.isEmpty
            if !browsesAllBuckets {
                currentBucket = nil
            }
            isLoading = true
            let client = try await makeClient(for: profile)
            errorMessage = nil
            if isAtBucketList {
                knownBuckets = try await client.listBuckets()
                items = knownBuckets.map(S3BrowserItem.bucket)
            } else {
                items = try await client.list(prefix: currentPrefix).items
            }
            isLoading = false
            if let selectedItemKey, !items.contains(where: { $0.key == selectedItemKey }) {
                self.selectedItemKey = nil
                clearPreview()
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func navigateUp(using profile: ConnectionProfile) async {
        if currentPrefix.isEmpty, browsesAllBuckets, currentBucket != nil {
            currentBucket = nil
            selectedItemKey = nil
            clearPreview()
        } else {
            currentPrefix = currentPrefix.parentS3Prefix
        }
        await refresh(using: profile)
    }

    func openSelectedFolder(using profile: ConnectionProfile) async {
        guard let selectedItem, selectedItem.kind != .object else {
            return
        }
        if selectedItem.kind == .bucket {
            currentBucket = knownBuckets.first { $0.name == selectedItem.key }
                ?? S3Bucket(name: selectedItem.key, region: nil, createdAt: nil)
            currentPrefix = ""
        } else {
            currentPrefix = selectedItem.key
        }
        selectedItemKey = nil
        clearPreview()
        await refresh(using: profile)
    }

    func selectItem(withKey key: String?, using profile: ConnectionProfile) async {
        selectedItemKey = key
        clearPreview()

        guard let item = selectedItem else {
            previewState = .empty("Select a file to preview.")
            return
        }

        guard item.kind == .object else {
            previewState = .empty(
                item.kind == .bucket ? "Buckets do not have a preview." : "Folders do not have a preview."
            )
            return
        }

        let previewKind = ObjectPreviewKind.resolve(key: item.key, contentType: item.contentType)
        guard previewKind != .unsupported else {
            previewState = .failed("Preview is not available for this file type.")
            return
        }

        let requestID = UUID()
        previewRequestID = requestID
        previewState = .loading

        do {
            try ensurePreviewDirectoryExists()
            let client = try await makeClient(for: profile)
            let previewURL = try await client.preparePreview(for: item, in: previewDirectory) { _ in }
            guard requestID == previewRequestID else {
                try? fileManager.removeItem(at: previewURL)
                return
            }
            currentPreviewURL = previewURL

            switch previewKind {
            case .inlineText:
                if let text = try? String(contentsOf: previewURL, encoding: .utf8) {
                    previewState = .ready(
                        BrowserPreviewContent(
                            item: item,
                            kind: .inlineText,
                            localURL: previewURL,
                            text: text
                        )
                    )
                } else {
                    previewState = .ready(
                        BrowserPreviewContent(
                            item: item,
                            kind: .quickLook,
                            localURL: previewURL,
                            text: nil
                        )
                    )
                }
            case .quickLook:
                previewState = .ready(
                    BrowserPreviewContent(
                        item: item,
                        kind: .quickLook,
                        localURL: previewURL,
                        text: nil
                    )
                )
            case .unsupported:
                assertionFailure("preview kind .unsupported should have been handled by the earlier guard")
                previewState = .failed("Preview is not available for this file type.")
            }
        } catch {
            previewState = .failed(error.localizedDescription)
        }
    }

    func createFolder(named folderName: String, using profile: ConnectionProfile) async {
        guard !isAtBucketList else {
            return
        }
        do {
            let client = try await makeClient(for: profile)
            try await client.createFolder(named: folderName, in: currentPrefix)
            await refresh(using: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameSelection(to newName: String, using profile: ConnectionProfile) async {
        guard !isAtBucketList else {
            return
        }
        guard let item = selectedItem else {
            return
        }

        do {
            let client = try await makeClient(for: profile)
            let renamedKey = try await client.rename(item: item, to: newName)
            await refresh(using: profile)
            selectedItemKey = renamedKey
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelection(using profile: ConnectionProfile) async {
        guard !isAtBucketList else {
            return
        }
        guard let item = selectedItem else {
            return
        }

        do {
            let client = try await makeClient(for: profile)
            try await client.delete(item: item)
            selectedItemKey = nil
            clearPreview()
            await refresh(using: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadFiles(_ urls: [URL], using profile: ConnectionProfile) async {
        guard !isAtBucketList else {
            return
        }
        do {
            let client = try await makeClient(for: profile)
            let prefix = currentPrefix
            let jobs: [(url: URL, transferID: UUID)] = urls.map { url in
                (url, startTransfer(name: url.lastPathComponent, kind: .upload))
            }

            await withTaskGroup(of: (UUID, Result<Void, any Error>).self) { group in
                var jobIterator = jobs.makeIterator()

                @discardableResult
                func submit() -> Bool {
                    guard let job = jobIterator.next() else { return false }
                    group.addTask { [client, prefix] in
                        do {
                            try await client.uploadFile(at: job.url, to: prefix) { progress in
                                Task { @MainActor in
                                    self.updateTransfer(id: job.transferID, progress: progress)
                                }
                            }
                            return (job.transferID, .success(()))
                        } catch {
                            return (job.transferID, .failure(error))
                        }
                    }
                    return true
                }

                for _ in 0..<min(Self.maxConcurrentUploads, jobs.count) {
                    submit()
                }

                while let (transferID, result) = await group.next() {
                    switch result {
                    case .success:
                        finishTransfer(id: transferID, status: .succeeded, message: "Upload completed.")
                    case let .failure(error):
                        finishTransfer(id: transferID, status: .failed, message: error.localizedDescription)
                    }
                    submit()
                }
            }

            await refresh(using: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static let maxConcurrentUploads = 3

    func downloadSelection(to destinationURL: URL, using profile: ConnectionProfile) async {
        guard let item = selectedItem, item.kind == .object else {
            return
        }

        do {
            let client = try await makeClient(for: profile)
            let transferID = startTransfer(name: item.name, kind: .download)
            do {
                try await client.download(item: item, to: destinationURL) { progress in
                    Task { @MainActor in
                        self.updateTransfer(id: transferID, progress: progress)
                    }
                }
                finishTransfer(id: transferID, status: .succeeded, message: "Download completed.")
            } catch {
                finishTransfer(id: transferID, status: .failed, message: error.localizedDescription)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reportError(_ message: String) {
        errorMessage = message
    }

    func openFolder(withKey key: String, using profile: ConnectionProfile) async {
        guard let item = items.first(where: { $0.key == key }), item.kind != .object else {
            errorMessage = "Folder \(key.lastS3PathComponent) was not found."
            return
        }
        selectedItemKey = item.key
        await openSelectedFolder(using: profile)
    }

    func clearError() {
        errorMessage = nil
    }

    func clearPreview() {
        previewRequestID = UUID()
        if let currentPreviewURL {
            try? fileManager.removeItem(at: currentPreviewURL)
            self.currentPreviewURL = nil
        }
        previewState = .empty("Select a file to preview.")
    }

    private func makeClient(for profile: ConnectionProfile) async throws -> any S3ClientProtocol {
        var configuration = try profile.configuration(credentials: credentialProvider(profile.id))
        if let assumeRole = configuration.assumeRole {
            let base = configuration.credentials
            let sts = stsClientFactory(
                STSHTTPClient.endpoint(forS3Endpoint: configuration.endpointURL, region: configuration.region),
                configuration.region
            )
            configuration.credentials = try await temporaryCredentials.credentials(
                for: profile.id,
                settings: assumeRole,
                base: base
            ) {
                try await sts.assumeRole(assumeRole, using: base)
            }
        }
        if let currentBucket {
            configuration = configuration.scoped(to: currentBucket)
        }
        return clientFactory(configuration)
    }

    private func resetBrowser() {
        items = []
        selectedItemKey = nil
        currentPrefix = ""
        currentBucket = nil
        filterText = ""
        isLoading = false
        transfers = []
        errorMessage = nil
        clearPreview()
    }

    private func ensurePreviewDirectoryExists() throws {
        try fileManager.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
    }

    private func startTransfer(name: String, kind: TransferActivity.Kind) -> UUID {
        let transfer = TransferActivity(
            id: UUID(),
            name: name,
            kind: kind,
            progress: 0,
            status: .running,
            message: nil
        )
        transfers.insert(transfer, at: 0)
        trimTransfers()
        return transfer.id
    }

    private func updateTransfer(id: UUID, progress: Double) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        transfers[index].progress = progress
    }

    private func finishTransfer(id: UUID, status: TransferActivity.Status, message: String) {
        guard let index = transfers.firstIndex(where: { $0.id == id }) else {
            return
        }
        if status == .succeeded {
            transfers[index].progress = 1
        }
        transfers[index].status = status
        transfers[index].message = message

        if status != .running {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.transferAutoDismissSeconds))
                self.transfers.removeAll { $0.id == id }
            }
        }
    }

    private func trimTransfers() {
        if transfers.count > Self.maxTransfers {
            transfers.removeLast(transfers.count - Self.maxTransfers)
        }
    }

    private static let maxTransfers = 8
    private static let transferAutoDismissSeconds: Int = 5
}
