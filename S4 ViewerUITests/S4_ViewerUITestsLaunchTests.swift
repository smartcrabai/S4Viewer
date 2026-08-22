import XCTest

/// Captures the App Store screenshot from the demo fixtures. Keeping it in the suite means
/// a launch regression fails CI instead of surfacing at screenshot time.
final class S4_ViewerUITestsLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchRendersPopulatedWindow() throws {
        let screen = Screen.launch()

        screen.select("release-notes.md")
        XCTAssertTrue(screen.previewInlineText.waitForExistence(timeout: 15))
        XCTAssertEqual(screen.rowKeys, Fixture.root)
        XCTAssertTrue(screen.profileRow(Fixture.profileName).exists)

        let attachment = XCTAttachment(screenshot: screen.app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
