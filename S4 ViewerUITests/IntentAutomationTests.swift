#if canImport(AppIntentsTesting)
import AppIntentsTesting
import XCTest

/// Out-of-process end-to-end coverage: the app runs in demo mode and the tests drive it
/// through the real App Intents infrastructure, so nothing touches the cursor or keyboard.
///
/// Compiled only when the toolchain ships `AppIntentsTesting` (Xcode 27 and later). Until
/// then the same intents are exercised in-process by
/// `S4 ViewerTests/DemoAutomationIntentTests.swift`.
/// The framework itself requires macOS 27, while the app still deploys to macOS 26.4.
@available(macOS 27.0, *)
@MainActor
final class IntentAutomationTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "ai.smartcrab.s4viewer")
    private var definitions: IntentDefinitions!

    private static let fixtureRoot = [
        "campaigns/",
        "exports/",
        "raw-footage/",
        "archive-2025.bin",
        "inventory-2026.csv",
        "keynote-recording.mov",
        "product-hero.png",
        "quarterly-report.pdf",
        "release-notes.md",
    ]

    override func setUp() async throws {
        continueAfterFailure = false
        app.launchArguments = ["-S4ViewerDemoData"]
        app.launchEnvironment["S4VIEWER_DEMO_MODE"] = "1"
        app.launch()
        definitions = IntentDefinitions(bundleIdentifier: "ai.smartcrab.s4viewer")
        _ = try await definitions.intents["ResetDemoBucketIntent"].makeIntent().run()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    private func list(prefix: String = "", sort: String = "nameAscending", filter: String = "") async throws -> [String] {
        let result = try await definitions.intents["ListObjectsIntent"]
            .makeIntent(prefix: prefix, sort: sort, filter: filter)
            .run()
        return try result.value
    }

    func testRootListingKeepsFoldersFirst() async throws {
        let keys = try await list()
        XCTAssertEqual(keys, Self.fixtureRoot)

        let location = try await definitions.intents["CurrentLocationIntent"].makeIntent().run()
        XCTAssertEqual(try location.value, "/")
    }

    func testNestedPrefixAndFilter() async throws {
        let nested = try await list(prefix: "campaigns/")
        XCTAssertEqual(nested, ["campaigns/2026-spring/", "campaigns/brief.md"])

        let filtered = try await list(filter: "csv")
        XCTAssertEqual(filtered, ["inventory-2026.csv"])

        let empty = try await list(prefix: "raw-footage/")
        XCTAssertTrue(empty.isEmpty)
    }

    func testMissingPrefixFailsInsteadOfListingParent() async throws {
        do {
            _ = try await list(prefix: "missing/")
            XCTFail("a missing prefix must not list its parent")
        } catch {
            XCTAssertTrue(
                "\(error)".contains("Folder missing was not found."),
                "unexpected error: \(error)"
            )
        }
    }

    func testSizeSortOrdersObjectsWithinFolders() async throws {
        let bySize = try await list(sort: "sizeDescending")
        XCTAssertEqual(bySize, [
            "campaigns/",
            "exports/",
            "raw-footage/",
            "keynote-recording.mov",
            "product-hero.png",
            "quarterly-report.pdf",
            "inventory-2026.csv",
            "archive-2025.bin",
            "release-notes.md",
        ])
    }

    func testFolderRenameCarriesChildrenAndDeleteRemovesThem() async throws {
        let renamed = try await definitions.intents["RenameItemIntent"]
            .makeIntent(key: "campaigns/", newName: "archive")
            .run()
        let afterRename: [String] = try renamed.value
        XCTAssertTrue(afterRename.contains("archive/"))
        XCTAssertFalse(afterRename.contains("campaigns/"))
        let children = try await list(prefix: "archive/")
        XCTAssertEqual(children, ["archive/2026-spring/", "archive/brief.md"])

        // Back to the root: the folder itself is not listed while its own prefix is open.
        _ = try await list()

        let deleted = try await definitions.intents["DeleteItemIntent"]
            .makeIntent(key: "archive/")
            .run()
        let afterDelete: [String] = try deleted.value
        XCTAssertFalse(afterDelete.contains("archive/"))

        _ = try await definitions.intents["CreateFolderIntent"].makeIntent(name: "archive").run()
        let recreated = try await list(prefix: "archive/")
        XCTAssertTrue(recreated.isEmpty)
    }

    func testDuplicateFolderNameFails() async throws {
        do {
            _ = try await definitions.intents["CreateFolderIntent"].makeIntent(name: "campaigns").run()
            XCTFail("creating a duplicate folder must fail")
        } catch {
            XCTAssertTrue(
                "\(error)".contains("already exists"),
                "unexpected error: \(error)"
            )
        }
    }

    func testUploadAndDownloadReportThroughIntents() async throws {
        _ = try await list(prefix: "exports/")

        let uploaded = try await definitions.intents["UploadFixturesIntent"].makeIntent().run()
        let listing: [String] = try uploaded.value
        XCTAssertTrue(listing.contains("exports/fixture-1.txt"))
        XCTAssertTrue(listing.contains("exports/fixture-3.txt"))

        let downloaded = try await definitions.intents["DownloadItemIntent"]
            .makeIntent(key: "exports/fixture-1.txt")
            .run()
        XCTAssertEqual(try downloaded.value, "Download completed.")
    }

    func testPreviewSummaryPerObjectKind() async throws {
        _ = try await list()

        let text = try await definitions.intents["PreviewSummaryIntent"]
            .makeIntent(key: "release-notes.md")
            .run()
        let textSummary: String = try text.value
        XCTAssertTrue(textSummary.hasPrefix("inlineText:"))
        XCTAssertTrue(textSummary.contains("Multipart uploads switch on automatically above 8 MiB."))

        let binary = try await definitions.intents["PreviewSummaryIntent"]
            .makeIntent(key: "quarterly-report.pdf")
            .run()
        XCTAssertEqual(try binary.value, "quickLook:quarterly-report.pdf")

        let unsupported = try await definitions.intents["PreviewSummaryIntent"]
            .makeIntent(key: "archive-2025.bin")
            .run()
        XCTAssertEqual(try unsupported.value, "failed:Preview is not available for this file type.")
    }
}
#endif
