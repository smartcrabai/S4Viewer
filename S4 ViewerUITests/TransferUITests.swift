import XCTest

/// Upload and download activity: the transfer rows appear, report completion, and clear.
/// Demo mode substitutes fixtures for the system panels; the multipart threshold and real
/// throughput stay a manual check against a live endpoint.
final class TransferUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDownloadReportsCompletionThenClears() throws {
        let screen = Screen.launch()

        screen.select("release-notes.md")
        screen.waitUntil("the object selection enables Download") { screen.downloadButton.isEnabled }

        screen.downloadButton.click()

        let status = screen.transferStatus("release-notes.md")
        XCTAssertTrue(status.waitForExistence(timeout: 15), "no transfer row appeared")
        screen.waitForValue("Download completed.", of: status)
        screen.waitForDisappearance(of: status)
    }

    @MainActor
    func testDownloadIsDisabledForFolders() throws {
        let screen = Screen.launch()

        screen.select("campaigns/")

        screen.waitUntil("the folder selection disables Download") { !screen.downloadButton.isEnabled }
    }

    @MainActor
    func testUploadRunsThreeFilesAndListsThem() throws {
        let screen = Screen.launch()

        screen.uploadButton.click()

        for index in 1...3 {
            let status = screen.transferStatus("fixture-\(index).txt")
            XCTAssertTrue(
                status.waitForExistence(timeout: 20),
                "fixture-\(index).txt never showed a transfer row"
            )
            screen.waitForValue("Upload completed.", of: status)
        }

        screen.waitUntil("the uploaded objects are listed", timeout: 20) {
            let keys = screen.rowKeys
            return keys.contains("fixture-1.txt")
                && keys.contains("fixture-2.txt")
                && keys.contains("fixture-3.txt")
        }
    }

    @MainActor
    func testUploadTargetsTheCurrentPrefix() throws {
        let screen = Screen.launch()

        screen.openByDoubleClick("exports/")
        screen.waitUntil("the exports prefix is listed") {
            screen.locationTitle.value as? String == "/exports/"
        }

        screen.uploadButton.click()

        screen.waitUntil("the objects land under the open prefix", timeout: 30) {
            screen.rowKeys.contains("exports/fixture-1.txt")
        }
    }
}
