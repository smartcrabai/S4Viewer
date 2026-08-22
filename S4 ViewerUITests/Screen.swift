import XCTest

/// Page object over the app running in demo mode (`-S4ViewerDemoData`), where the S3 client,
/// the credential store, and both file panels are replaced by in-memory fixtures.
///
/// The identifier strings mirror `A11y` in the app target, which a UI test bundle cannot
/// import. Rename an identifier on one side and these tests fail loudly.
@MainActor
struct Screen {
    let app: XCUIApplication

    private static let rowPrefix = "browser.row."

    static func launch(file: StaticString = #filePath, line: UInt = #line) -> Screen {
        let app = XCUIApplication(bundleIdentifier: "ai.smartcrab.s4viewer")
        // A leftover instance from an earlier test would be activated instead of launched,
        // and its window state would not match this test's expectations.
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES", "-S4ViewerDemoData"]
        app.launchEnvironment["S4VIEWER_DEMO_MODE"] = "1"
        app.launch()
        app.activate()

        let screen = Screen(app: app)
        XCTAssertTrue(
            screen.table.waitForExistence(timeout: 60),
            "the browser never finished its first listing",
            file: file,
            line: line
        )
        return screen
    }

    // MARK: Sidebar

    var sidebarEmptyState: XCUIElement { app.staticTexts["sidebar.empty"].firstMatch }
    var addProfileButton: XCUIElement { app.buttons["sidebar.add"] }
    var editProfileButton: XCUIElement { app.buttons["sidebar.edit"] }
    var deleteProfileButton: XCUIElement { app.buttons["sidebar.delete"] }

    func profileRow(_ profileName: String) -> XCUIElement {
        app.staticTexts["sidebar.row.\(profileName)"].firstMatch
    }

    // MARK: Browser

    var locationTitle: XCUIElement { app.staticTexts["browser.locationTitle"] }
    var refreshButton: XCUIElement { app.buttons["browser.refresh"] }
    var openButton: XCUIElement { app.buttons["browser.open"] }
    var upButton: XCUIElement { app.buttons["browser.up"] }
    var uploadButton: XCUIElement { app.buttons["browser.upload"] }
    var downloadButton: XCUIElement { app.buttons["browser.download"] }
    var newFolderButton: XCUIElement { app.buttons["browser.newFolder"] }
    var renameButton: XCUIElement { app.buttons["browser.rename"] }
    var deleteButton: XCUIElement { app.buttons["browser.delete"] }
    var filterField: XCUIElement { app.textFields["browser.filterField"] }
    var filterClearButton: XCUIElement { app.buttons["browser.filterClear"] }
    var sortPicker: XCUIElement { app.popUpButtons["browser.sortPicker"] }
    var table: XCUIElement { app.descendants(matching: .any)["browser.table"] }
    var emptyObjectsState: XCUIElement { app.staticTexts["browser.emptyObjects"].firstMatch }
    var emptyMatchesState: XCUIElement { app.staticTexts["browser.emptyMatches"].firstMatch }
    var noConnectionState: XCUIElement { app.staticTexts["browser.noConnection"].firstMatch }

    /// The name column carries the identifier, so a row is addressed by its full S3 key.
    func row(_ key: String) -> XCUIElement {
        app.staticTexts["\(Self.rowPrefix)\(key)"]
    }

    /// Keys of the listed rows, top to bottom, which is what makes sort order assertable.
    var rowKeys: [String] {
        app.staticTexts.allElementsBoundByIndex
            .filter { $0.identifier.hasPrefix(Self.rowPrefix) }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map { String($0.identifier.dropFirst(Self.rowPrefix.count)) }
    }

    func select(_ key: String) {
        row(key).click()
    }

    func openByDoubleClick(_ key: String) {
        row(key).doubleClick()
    }

    func chooseSort(_ title: String) {
        sortPicker.click()
        app.menuItems[title].click()
    }

    func typeFilter(_ text: String) {
        filterField.click()
        filterField.typeText(text)
    }

    // MARK: Name prompt

    var namePromptField: XCUIElement { app.textFields["namePrompt.field"] }
    var namePromptSubmit: XCUIElement { app.buttons["namePrompt.submit"] }

    func submitNamePrompt(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            namePromptField.waitForExistence(timeout: 10),
            "the name prompt never appeared",
            file: file,
            line: line
        )
        namePromptField.click()
        namePromptField.typeKey("a", modifierFlags: .command)
        namePromptField.typeText(name)
        namePromptSubmit.click()
    }

    // MARK: Profile editor

    var profileNameField: XCUIElement { app.textFields["profileEditor.name"] }
    var profileEndpointField: XCUIElement { app.textFields["profileEditor.endpoint"] }
    var profileRegionField: XCUIElement { app.textFields["profileEditor.region"] }
    var profileBucketField: XCUIElement { app.textFields["profileEditor.bucket"] }
    var profileAccessKeyField: XCUIElement { app.textFields["profileEditor.accessKey"] }
    var profileSecretKeyField: XCUIElement { app.secureTextFields["profileEditor.secretKey"] }
    var profileSaveButton: XCUIElement { app.buttons["profileEditor.save"] }
    var profileCancelButton: XCUIElement { app.buttons["profileEditor.cancel"] }
    var profileValidationMessage: XCUIElement { app.staticTexts["profileEditor.validationMessage"] }

    func fillProfile(
        name: String,
        endpoint: String,
        region: String,
        bucket: String,
        accessKey: String,
        secretKey: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            profileNameField.waitForExistence(timeout: 10),
            "the profile editor never appeared",
            file: file,
            line: line
        )
        replaceText(in: profileNameField, with: name)
        replaceText(in: profileEndpointField, with: endpoint)
        replaceText(in: profileRegionField, with: region)
        replaceText(in: profileBucketField, with: bucket)
        replaceText(in: profileAccessKeyField, with: accessKey)
        replaceText(in: profileSecretKeyField, with: secretKey)
    }

    func replaceText(in field: XCUIElement, with text: String) {
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
    }

    // MARK: Confirmations, alerts, transfers, preview

    var confirmDeleteProfileButton: XCUIElement { app.buttons["confirm.deleteProfile"] }
    var confirmDeleteItemButton: XCUIElement { app.buttons["confirm.deleteItem"] }
    var errorAlertMessage: XCUIElement { app.staticTexts["errorAlert.message"].firstMatch }
    var errorAlertDismissButton: XCUIElement { app.buttons["errorAlert.dismiss"] }

    func transferStatus(_ name: String) -> XCUIElement {
        app.staticTexts["transfers.status.\(name)"].firstMatch
    }

    var previewName: XCUIElement { app.staticTexts["preview.name"] }
    var previewKey: XCUIElement { app.staticTexts["preview.key"] }
    var previewInlineText: XCUIElement { app.staticTexts["preview.inlineText"] }
    var previewQuickLook: XCUIElement { app.descendants(matching: .any)["preview.quickLook"] }

    /// `ContentUnavailableView` renders its title and description as separate elements that
    /// share the identifier, so tests match against every value.
    func values(identifier: String) -> [String] {
        app.staticTexts.matching(identifier: identifier)
            .allElementsBoundByIndex
            .compactMap { $0.value as? String }
    }

    // MARK: Waiting

    func waitUntil(
        _ description: String,
        timeout: TimeInterval = 15,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: () -> Bool
    ) {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() {
                return
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("timed out waiting until \(description)", file: file, line: line)
    }

    func waitForDisappearance(
        of element: XCUIElement,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never disappeared", file: file, line: line)
    }

    func waitForValue(
        _ value: String,
        of element: XCUIElement,
        timeout: TimeInterval = 20,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", value),
            object: element
        )
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "\(element) never reported \(value)", file: file, line: line)
    }
}

/// Fixtures seeded by `DemoBucket` on every launch.
enum Fixture {
    static let profileName = "Production Media"

    static let rootFolders = ["campaigns/", "exports/", "raw-footage/"]
    static let rootObjects = [
        "archive-2025.bin",
        "inventory-2026.csv",
        "keynote-recording.mov",
        "product-hero.png",
        "quarterly-report.pdf",
        "release-notes.md",
    ]
    static let root = rootFolders + rootObjects
}
