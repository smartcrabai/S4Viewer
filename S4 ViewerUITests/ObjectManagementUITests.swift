import XCTest

/// Create folder, rename, delete, and the error path when the bucket rejects an operation.
final class ObjectManagementUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateFolderAppearsInListing() throws {
        let screen = Screen.launch()

        screen.newFolderButton.click()
        screen.submitNamePrompt("2027-plans")

        screen.waitUntil("the new folder is listed") {
            screen.rowKeys.contains("2027-plans/")
        }
        XCTAssertEqual(
            Array(screen.rowKeys[0..<4]),
            ["2027-plans/", "campaigns/", "exports/", "raw-footage/"],
            "a new folder stays pinned above the objects"
        )
    }

    @MainActor
    func testCreateFolderInsideCurrentPrefix() throws {
        let screen = Screen.launch()

        screen.openByDoubleClick("exports/")
        screen.waitUntil("the exports prefix is listed") {
            screen.locationTitle.value as? String == "/exports/"
        }

        screen.newFolderButton.click()
        screen.submitNamePrompt("weekly")

        screen.waitUntil("the nested folder is listed") {
            screen.rowKeys.contains("exports/weekly/")
        }
    }

    @MainActor
    func testDuplicateFolderSurfacesTheError() throws {
        let screen = Screen.launch()

        screen.newFolderButton.click()
        screen.submitNamePrompt("campaigns")

        XCTAssertTrue(screen.errorAlertMessage.waitForExistence(timeout: 15))
        XCTAssertEqual(
            screen.errorAlertMessage.value as? String,
            "An item named campaigns already exists here.",
            "the failure must be shown, not swallowed"
        )

        screen.errorAlertDismissButton.click()
        screen.waitForDisappearance(of: screen.errorAlertMessage)
    }

    @MainActor
    func testRenameObjectReplacesTheRow() throws {
        let screen = Screen.launch()

        screen.select("release-notes.md")
        screen.waitUntil("the selection enables Rename") { screen.renameButton.isEnabled }

        screen.renameButton.click()
        screen.submitNamePrompt("release-notes-v2.md")

        screen.waitUntil("the renamed object is listed") {
            screen.rowKeys.contains("release-notes-v2.md") && !screen.rowKeys.contains("release-notes.md")
        }
    }

    @MainActor
    func testRenameFolderKeepsItsChildren() throws {
        let screen = Screen.launch()

        screen.select("campaigns/")
        screen.waitUntil("the selection enables Rename") { screen.renameButton.isEnabled }

        screen.renameButton.click()
        screen.submitNamePrompt("archive")

        screen.waitUntil("the renamed folder is listed") {
            screen.rowKeys.contains("archive/") && !screen.rowKeys.contains("campaigns/")
        }

        screen.openByDoubleClick("archive/")

        screen.waitUntil("the children moved with the folder") {
            screen.rowKeys == ["archive/2026-spring/", "archive/brief.md"]
        }
    }

    @MainActor
    func testDeleteObjectRemovesTheRow() throws {
        let screen = Screen.launch()

        screen.select("archive-2025.bin")
        screen.waitUntil("the selection enables Delete") { screen.deleteButton.isEnabled }

        screen.deleteButton.click()
        XCTAssertTrue(screen.confirmDeleteItemButton.waitForExistence(timeout: 10))
        screen.confirmDeleteItemButton.click()

        screen.waitUntil("the object is gone") {
            !screen.rowKeys.contains("archive-2025.bin")
        }
        XCTAssertEqual(screen.rowKeys.count, Fixture.root.count - 1)
    }

    @MainActor
    func testDeleteFolderRemovesItsChildren() throws {
        let screen = Screen.launch()

        screen.select("campaigns/")
        screen.deleteButton.click()
        XCTAssertTrue(screen.confirmDeleteItemButton.waitForExistence(timeout: 10))
        screen.confirmDeleteItemButton.click()

        screen.waitUntil("the folder is gone") {
            !screen.rowKeys.contains("campaigns/")
        }

        // Recreating the prefix proves the descendants went with it: a surviving
        // `campaigns/brief.md` would list here.
        screen.newFolderButton.click()
        screen.submitNamePrompt("campaigns")
        screen.waitUntil("the prefix exists again") { screen.rowKeys.contains("campaigns/") }

        screen.openByDoubleClick("campaigns/")

        XCTAssertTrue(screen.emptyObjectsState.waitForExistence(timeout: 15))
        XCTAssertTrue(screen.rowKeys.isEmpty)
    }
}
