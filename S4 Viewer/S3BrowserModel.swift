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

    init(
        clientFactory: @escaping @Sendable (S3ConnectionConfiguration) -> any S3ClientProtocol = {
            S3HTTPClient(configuration: $0)
        },
        previewDirectory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("S4ViewerPreviewCache", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.clientFactory = clientFactory
        self.previewDirectory = previewDirectory
        self.fileManager = fileManager
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

    var canNavigateUp: Bool {
        !currentPrefix.isEmpty
    }

    var currentLocationTitle: String {
        currentPrefix.isEmpty ? "/" : "/" + currentPrefix
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
            let client = try makeClient(for: profile)
            isLoading = true
            errorMessage = nil
            let page = try await client.list(prefix: currentPrefix)
            items = page.items
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
        currentPrefix = currentPrefix.parentS3Prefix
        await refresh(using: profile)
    }

    func openSelectedFolder(using profile: ConnectionProfile) async {
        guard let selectedItem, selectedItem.kind == .folder else {
            return
        }
        currentPrefix = selectedItem.key
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
            previewState = .empty("Folders do not have a preview.")
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
            let client = try makeClient(for: profile)
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
        do {
            let client = try makeClient(for: profile)
            try await client.createFolder(named: folderName, in: currentPrefix)
            await refresh(using: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameSelection(to newName: String, using profile: ConnectionProfile) async {
        guard let item = selectedItem else {
            return
        }

        do {
            let client = try makeClient(for: profile)
            let renamedKey = try await client.rename(item: item, to: newName)
            await refresh(using: profile)
            selectedItemKey = renamedKey
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSelection(using profile: ConnectionProfile) async {
        guard let item = selectedItem else {
            return
        }

        do {
            let client = try makeClient(for: profile)
            try await client.delete(item: item)
            selectedItemKey = nil
            clearPreview()
            await refresh(using: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadFiles(_ urls: [URL], using profile: ConnectionProfile) async {
        do {
            let client = try makeClient(for: profile)
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
            let client = try makeClient(for: profile)
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
        selectedItemKey = key
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

    private func makeClient(for profile: ConnectionProfile) throws -> any S3ClientProtocol {
        clientFactory(try profile.configuration())
    }

    private func resetBrowser() {
        items = []
        selectedItemKey = nil
        currentPrefix = ""
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
