import XCTest

/// Connection profile lifecycle: create, validate, edit (including credential read-back),
/// and delete. Demo mode keeps credentials in memory, so Keychain persistence across
/// relaunches and iCloud sync stay manual checks on a signed build.
final class ConnectionProfileUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddedProfileAppearsInSidebarAndBecomesSelected() throws {
        let screen = Screen.launch()

        screen.addProfileButton.click()
        screen.fillProfile(
            name: "Staging Mirror",
            endpoint: "https://storage.example.com",
            region: "eu-central-1",
            bucket: "staging-mirror",
            accessKey: "STAGINGKEY",
            secretKey: "STAGINGSECRET"
        )
        screen.profileSaveButton.click()

        XCTAssertTrue(screen.profileRow("Staging Mirror").waitForExistence(timeout: 15))
        // Saving selects the new profile, so the browser reconnects at the bucket root.
        screen.waitUntil("the new profile is browsed") {
            screen.locationTitle.value as? String == "/" && screen.rowKeys == Fixture.root
        }
    }

    @MainActor
    func testInvalidEndpointKeepsTheEditorOpenWithAMessage() throws {
        let screen = Screen.launch()

        screen.addProfileButton.click()
        screen.fillProfile(
            name: "Broken",
            endpoint: "not a url",
            region: "eu-central-1",
            bucket: "staging-mirror",
            accessKey: "STAGINGKEY",
            secretKey: "STAGINGSECRET"
        )
        screen.profileSaveButton.click()

        XCTAssertTrue(screen.profileValidationMessage.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.profileSaveButton.exists, "the editor must stay open on a rejection")
        XCTAssertFalse(screen.profileRow("Broken").exists)

        screen.profileCancelButton.click()
        screen.waitForDisappearance(of: screen.profileValidationMessage)
    }

    @MainActor
    func testEditingAProfilePrefillsStoredCredentials() throws {
        let screen = Screen.launch()

        screen.editProfileButton.click()

        XCTAssertTrue(screen.profileNameField.waitForExistence(timeout: 10))
        XCTAssertEqual(screen.profileNameField.value as? String, Fixture.profileName)
        XCTAssertEqual(screen.profileBucketField.value as? String, "smartcrab-media")
        XCTAssertEqual(
            screen.profileAccessKeyField.value as? String,
            "DEMOACCESSKEY",
            "the access key must be read back from the credential store"
        )
        XCTAssertFalse(
            (screen.profileSecretKeyField.value as? String ?? "").isEmpty,
            "the secret key must be read back from the credential store"
        )

        screen.profileCancelButton.click()
        screen.waitForDisappearance(of: screen.profileNameField)
    }

    @MainActor
    func testRenamingAProfileUpdatesTheSidebar() throws {
        let screen = Screen.launch()

        screen.editProfileButton.click()
        XCTAssertTrue(screen.profileNameField.waitForExistence(timeout: 10))
        screen.replaceText(in: screen.profileNameField, with: "Production Media EU")
        screen.profileSaveButton.click()

        XCTAssertTrue(screen.profileRow("Production Media EU").waitForExistence(timeout: 15))
        XCTAssertFalse(screen.profileRow(Fixture.profileName).exists)
    }

    @MainActor
    func testDeletingTheLastProfileEmptiesSidebarAndBrowser() throws {
        let screen = Screen.launch()

        screen.deleteProfileButton.click()
        XCTAssertTrue(screen.confirmDeleteProfileButton.waitForExistence(timeout: 10))
        screen.confirmDeleteProfileButton.click()

        XCTAssertTrue(screen.sidebarEmptyState.waitForExistence(timeout: 15))
        XCTAssertTrue(screen.noConnectionState.waitForExistence(timeout: 15))
        XCTAssertFalse(screen.table.exists)
        XCTAssertFalse(screen.editProfileButton.isEnabled)
        XCTAssertFalse(screen.deleteProfileButton.isEnabled)
    }
}
