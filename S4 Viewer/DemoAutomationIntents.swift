#if DEBUG
import AppIntents
import Foundation

/// Testing-only App Intents. They drive the live `S3BrowserModel` when the app service shares
/// the window process, and otherwise use the same fixture-backed model path without XCUITest
/// taking over the cursor and keyboard.
///
/// Every intent sets `isDiscoverable = false`, so none of them appear in Shortcuts, Siri, or
/// Spotlight, and the whole file is compiled out of Release builds. They are only reachable
/// in a Debug build launched with `-S4ViewerDemoData`.

/// Bridge between the view that owns the model and the intents that drive it. A plain
/// singleton rather than `@AppDependency`, because the model is created by `ContentView` and
/// replaced when the selected profile changes; intents also have a fixture-backed fallback
/// when they execute in a separate service process.
/// Not `@Observable`: nothing renders it, the views own the model.
@MainActor
final class DemoAutomationContext {
    static let shared = DemoAutomationContext()

    // Strong: the intents outlive the call that attached the model, and this DEBUG-only
    // glue holding one extra reference is harmless.
    private(set) var browser: S3BrowserModel?
    private(set) var profile: ConnectionProfile?

    private init() {}

    func attach(browser: S3BrowserModel, profile: ConnectionProfile?) {
        self.browser = browser
        self.profile = profile
    }

    func detach(browser: S3BrowserModel) {
        guard self.browser === browser else {
            return
        }
        self.browser = nil
        profile = nil
    }

    func require() async throws -> (browser: S3BrowserModel, profile: ConnectionProfile) {
        if let browser, let profile {
            return (browser, profile)
        }
#if DEBUG
        // App Intents may execute in a separate service process, so a process-local singleton
        // cannot always see the window's model. The demo entry point still needs a complete
        // model/client path; use the same fixture-backed implementation when no window model
        // is available.
        if DemoMode.isEnabled {
            let browser = S3BrowserModel.makeDefault()
            let profile = DemoMode.makeProfile()
            await browser.connect(to: profile)
            attach(browser: browser, profile: profile)
            return (browser, profile)
        }
#endif
        throw DemoAutomationError.notReady
    }
}

enum DemoAutomationError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case notReady
    case unknownSortMode(String)
    case unknownItem(String)
    case operationFailed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady:
            return "The app has no connected profile yet."
        case let .unknownSortMode(mode):
            return "\(mode) is not a sort mode."
        case let .unknownItem(key):
            return "\(key) is not listed in the current location."
        case let .operationFailed(message):
            return "\(message)"
        }
    }
}

// MARK: - Shared helpers

private func navigate(_ browser: S3BrowserModel, _ profile: ConnectionProfile, to prefix: String) async {
    await browser.connect(to: profile)
    var current = ""
    for component in prefix.split(separator: "/") {
        current += component + "/"
        await browser.openFolder(withKey: current, using: profile)
    }
}

private func select(_ key: String, _ browser: S3BrowserModel, _ profile: ConnectionProfile) async throws {
    guard browser.items.contains(where: { $0.key == key }) else {
        throw DemoAutomationError.unknownItem(key)
    }
    await browser.selectItem(withKey: key, using: profile)
}

/// Errors surface in the UI as an alert rather than as thrown values, so the intents read
/// and clear the model's message to fail the calling test instead of passing silently.
private func failIfErrored(_ browser: S3BrowserModel) throws {
    guard let message = browser.errorMessage else {
        return
    }
    browser.clearError()
    throw DemoAutomationError.operationFailed(message)
}

private func listing(_ browser: S3BrowserModel) -> [String] {
    browser.sortedItems.map(\.key)
}

// MARK: - Setup

struct ResetDemoBucketIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset Demo Bucket"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        await DemoBucket.shared.reset()
        browser.sortMode = .nameAscending
        await browser.connect(to: profile)
        try failIfErrored(browser)
        return .result()
    }
}

// MARK: - Browsing

struct ListObjectsIntent: AppIntent {
    static let title: LocalizedStringResource = "List Objects"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Prefix") var prefix: String
    @Parameter(title: "Sort Mode") var sort: String?
    @Parameter(title: "Filter") var filter: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        await navigate(browser, profile, to: prefix)
        try failIfErrored(browser)

        if let sort {
            guard let mode = S3BrowserSortMode(rawValue: sort) else {
                throw DemoAutomationError.unknownSortMode(sort)
            }
            browser.sortMode = mode
        }
        browser.filterText = filter ?? ""

        return .result(value: listing(browser))
    }
}

struct CurrentLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Current Location"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let (browser, _) = try await DemoAutomationContext.shared.require()
        return .result(value: browser.currentLocationTitle)
    }
}

// MARK: - Editing

struct CreateFolderIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Folder"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Name") var name: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        await browser.createFolder(named: name, using: profile)
        try failIfErrored(browser)
        return .result(value: listing(browser))
    }
}

struct RenameItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Rename Item"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Key") var key: String
    @Parameter(title: "New Name") var newName: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        try await select(key, browser, profile)
        await browser.renameSelection(to: newName, using: profile)
        try failIfErrored(browser)
        return .result(value: listing(browser))
    }
}

struct DeleteItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Item"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Key") var key: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        try await select(key, browser, profile)
        await browser.deleteSelection(using: profile)
        try failIfErrored(browser)
        return .result(value: listing(browser))
    }
}

// MARK: - Transfers

struct UploadFixturesIntent: AppIntent {
    static let title: LocalizedStringResource = "Upload Fixtures"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        let urls = try DemoMode.makeUploadFixtures()
        await browser.uploadFiles(urls, using: profile)
        try failIfErrored(browser)
        return .result(value: listing(browser))
    }
}

struct DownloadItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Download Item"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Key") var key: String

    /// Returns the transfer row's final message, which is what the UI shows and then clears.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        try await select(key, browser, profile)
        guard let destination = DemoMode.downloadDestination(suggestedName: key.lastS3PathComponent) else {
            throw DemoAutomationError.operationFailed("No writable download destination.")
        }
        await browser.downloadSelection(to: destination, using: profile)
        try failIfErrored(browser)
        return .result(value: browser.transfers.first?.message ?? "")
    }
}

// MARK: - Preview

struct PreviewSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Preview Summary"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "Key") var key: String

    /// Encodes `BrowserPreviewState` as `state:detail`, so a test can assert both the branch
    /// the preview column takes and the text it renders.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let (browser, profile) = try await DemoAutomationContext.shared.require()
        try await select(key, browser, profile)

        switch browser.previewState {
        case let .empty(message):
            return .result(value: "empty:\(message)")
        case .loading:
            return .result(value: "loading:")
        case let .failed(message):
            return .result(value: "failed:\(message)")
        case let .ready(preview):
            switch preview.kind {
            case .inlineText:
                return .result(value: "inlineText:\(preview.text ?? "")")
            case .quickLook:
                return .result(value: "quickLook:\(preview.localURL.lastPathComponent)")
            case .unsupported:
                return .result(value: "unsupported:")
            }
        }
    }
}
#endif
