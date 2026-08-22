#if DEBUG
import Foundation
import PDFKit
import Testing
@testable import S4_Viewer

struct DemoModeTests {
    @Test
    func quarterlyReportFixtureIsAValidPDF() async throws {
        let bucket = DemoBucket()
        let item = S3BrowserItem.object(
            key: "quarterly-report.pdf",
            size: 0,
            modifiedAt: nil,
            eTag: nil,
            contentType: "application/pdf"
        )

        let data = try await bucket.data(for: item)

        #expect(PDFDocument(data: data) != nil)
    }

    @Test @MainActor
    func automationContextDetachesTheLiveBrowserWhenItsViewDisappears() {
        let context = DemoAutomationContext.shared
        let browser = S3BrowserModel()
        context.attach(browser: browser, profile: nil)

        context.detach(browser: browser)

        #expect(context.browser == nil)
        #expect(context.profile == nil)
    }

    @Test
    func demoRejectsPathContainingNames() async throws {
        let bucket = DemoBucket()
        let item = S3BrowserItem.object(
            key: "release-notes.md",
            size: 0,
            modifiedAt: nil,
            eTag: nil,
            contentType: "text/markdown"
        )

        await #expect(throws: DemoS3Error.invalidName("a/b")) {
            try await bucket.createFolder(named: "a/b", in: "")
        }
        await #expect(throws: DemoS3Error.invalidName("a/b")) {
            try await bucket.rename(item, to: "a/b")
        }
    }

#if S4VIEWER_INTENT_TESTING
    @Test @MainActor
    func fallbackAutomationContextConnectsDemoModel() async throws {
        let context = DemoAutomationContext.shared
        if let browser = context.browser {
            context.detach(browser: browser)
        }

        let (browser, _) = try await context.require()

        #expect(browser.items.contains { $0.key == "release-notes.md" })
        context.detach(browser: browser)
    }
#endif

    @Test @MainActor
    func openingMissingFolderReportsAnError() async {
        let bucket = DemoBucket()
        let profile = ConnectionProfile(
            name: "Demo",
            endpoint: "https://s3.example.com",
            region: "us-east-1",
            bucket: "demo",
            usePathStyle: false
        )
        let model = S3BrowserModel(
            clientFactory: { _ in DemoS3Client(bucket: bucket) },
            credentialProvider: { _ in DemoMode.credentials }
        )

        await model.connect(to: profile)
        await model.openFolder(withKey: "missing/", using: profile)

        #expect(model.currentLocationTitle == "/")
        #expect(model.errorMessage == "Folder missing was not found.")
    }
}
#endif
