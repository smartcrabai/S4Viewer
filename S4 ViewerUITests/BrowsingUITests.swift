import XCTest

/// Listing, navigation, sorting, and filtering - the paths the release checklist calls
/// "list objects, enter a folder, navigate back up" and "sort and filter".
final class BrowsingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRootListingShowsFoldersBeforeObjects() throws {
        let screen = Screen.launch()

        XCTAssertEqual(screen.rowKeys, Fixture.root)
        XCTAssertEqual(screen.locationTitle.value as? String, "/")
        XCTAssertFalse(screen.upButton.isEnabled, "the bucket root has no parent")
    }

    @MainActor
    func testDoubleClickEntersFolderAndUpReturns() throws {
        let screen = Screen.launch()

        screen.openByDoubleClick("campaigns/")

        screen.waitUntil("the campaigns prefix is listed") {
            screen.locationTitle.value as? String == "/campaigns/"
        }
        XCTAssertEqual(screen.rowKeys, ["campaigns/2026-spring/", "campaigns/brief.md"])
        XCTAssertTrue(screen.upButton.isEnabled)

        screen.upButton.click()

        screen.waitUntil("the bucket root is listed again") {
            screen.locationTitle.value as? String == "/"
        }
        XCTAssertEqual(screen.rowKeys, Fixture.root)
    }

    @MainActor
    func testOpenButtonEntersSelectedFolder() throws {
        let screen = Screen.launch()

        XCTAssertFalse(screen.openButton.isEnabled, "no selection means nothing to open")
        screen.select("exports/")
        screen.waitUntil("the folder selection enables Open") { screen.openButton.isEnabled }

        screen.openButton.click()

        screen.waitUntil("the exports prefix is listed") {
            screen.locationTitle.value as? String == "/exports/"
        }
        XCTAssertEqual(screen.rowKeys, ["exports/report-q1.csv"])
    }

    @MainActor
    func testEmptyFolderShowsEmptyState() throws {
        let screen = Screen.launch()

        screen.openByDoubleClick("raw-footage/")

        XCTAssertTrue(screen.emptyObjectsState.waitForExistence(timeout: 15))
        XCTAssertTrue(screen.rowKeys.isEmpty)
        XCTAssertTrue(
            screen.values(identifier: "browser.emptyObjects")
                .contains("Upload files or create folders in the current location.")
        )
    }

    @MainActor
    func testSortModesReorderObjectsAndKeepFoldersPinned() throws {
        let screen = Screen.launch()

        screen.chooseSort("Name Z-A")
        screen.waitUntil("the descending name order is applied") {
            screen.rowKeys == ["raw-footage/", "exports/", "campaigns/"] + Fixture.rootObjects.reversed()
        }

        screen.chooseSort("Size Largest")
        screen.waitUntil("the descending size order is applied") {
            screen.rowKeys == Fixture.rootFolders + [
                "keynote-recording.mov",
                "product-hero.png",
                "quarterly-report.pdf",
                "inventory-2026.csv",
                "archive-2025.bin",
                "release-notes.md",
            ]
        }

        screen.chooseSort("Modified Newest")
        screen.waitUntil("the newest-first order is applied") {
            screen.rowKeys == Fixture.rootFolders + [
                "release-notes.md",
                "quarterly-report.pdf",
                "keynote-recording.mov",
                "product-hero.png",
                "inventory-2026.csv",
                "archive-2025.bin",
            ]
        }

        screen.chooseSort("Modified Oldest")
        screen.waitUntil("the oldest-first order is applied") {
            screen.rowKeys == Fixture.rootFolders + [
                "archive-2025.bin",
                "inventory-2026.csv",
                "product-hero.png",
                "keynote-recording.mov",
                "quarterly-report.pdf",
                "release-notes.md",
            ]
        }
    }

    @MainActor
    func testFilterNarrowsRowsAndClearingRestoresThem() throws {
        let screen = Screen.launch()

        screen.typeFilter("csv")
        screen.waitUntil("only the csv object is listed") {
            screen.rowKeys == ["inventory-2026.csv"]
        }

        screen.filterClearButton.click()
        screen.waitUntil("the full listing is restored") {
            screen.rowKeys == Fixture.root
        }

        screen.typeFilter("no-such-object")
        XCTAssertTrue(screen.emptyMatchesState.waitForExistence(timeout: 15))
        XCTAssertTrue(
            screen.values(identifier: "browser.emptyMatches")
                .contains("No items match \"no-such-object\" in this location.")
        )
    }

    @MainActor
    func testRefreshKeepsCurrentPrefix() throws {
        let screen = Screen.launch()

        screen.openByDoubleClick("exports/")
        screen.waitUntil("the exports prefix is listed") {
            screen.rowKeys == ["exports/report-q1.csv"]
        }

        screen.refreshButton.click()

        screen.waitUntil("the listing is unchanged after a refresh") {
            screen.locationTitle.value as? String == "/exports/" && screen.rowKeys == ["exports/report-q1.csv"]
        }
    }
}
