import XCTest

/// Preview column behaviour: inline text, Quick Look, unsupported types, and folders.
final class PreviewUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTextObjectPreviewsInline() throws {
        let screen = Screen.launch()

        screen.select("release-notes.md")

        XCTAssertTrue(screen.previewInlineText.waitForExistence(timeout: 15))
        XCTAssertEqual(screen.previewName.value as? String, "release-notes.md")
        XCTAssertEqual(screen.previewKey.value as? String, "release-notes.md")
        let body = screen.previewInlineText.value as? String ?? ""
        XCTAssertTrue(
            body.contains("Multipart uploads switch on automatically above 8 MiB."),
            "inline preview showed \(body)"
        )
    }

    @MainActor
    func testBinaryObjectUsesQuickLookInsteadOfInlineText() throws {
        let screen = Screen.launch()

        screen.select("quarterly-report.pdf")

        screen.waitUntil("the pdf preview header appears") {
            screen.previewName.value as? String == "quarterly-report.pdf"
        }
        XCTAssertTrue(
            screen.previewQuickLook.waitForExistence(timeout: 15),
            "the valid PDF must be handed to Quick Look"
        )
        XCTAssertFalse(
            screen.previewInlineText.exists,
            "a pdf must not be rendered as inline text"
        )
    }

    @MainActor
    func testUnsupportedTypeReportsNoPreview() throws {
        let screen = Screen.launch()

        screen.select("archive-2025.bin")

        screen.waitUntil("the failure state appears") {
            screen.values(identifier: "preview.failed")
                .contains("Preview is not available for this file type.")
        }
        XCTAssertFalse(screen.previewName.exists)
    }

    @MainActor
    func testFolderSelectionHasNoPreview() throws {
        let screen = Screen.launch()

        screen.select("campaigns/")

        screen.waitUntil("the folder empty state appears") {
            screen.values(identifier: "preview.empty").contains("Folders do not have a preview.")
        }
    }

    @MainActor
    func testPreviewClearsWhenSelectedObjectIsDeleted() throws {
        let screen = Screen.launch()

        screen.select("release-notes.md")
        XCTAssertTrue(screen.previewInlineText.waitForExistence(timeout: 15))

        screen.deleteButton.click()
        XCTAssertTrue(screen.confirmDeleteItemButton.waitForExistence(timeout: 10))
        screen.confirmDeleteItemButton.click()

        screen.waitUntil("the preview returns to its empty state") {
            screen.values(identifier: "preview.empty").contains("Select a file to preview.")
        }
        XCTAssertFalse(screen.previewInlineText.exists)
    }
}
