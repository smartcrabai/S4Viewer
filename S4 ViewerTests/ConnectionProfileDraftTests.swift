import Foundation
import Testing
@testable import S4_Viewer

struct ConnectionProfileDraftTests {
    @Test
    func validatedDraftNormalizesWhitespaceAndEndpoint() throws {
        let draft = ConnectionProfileDraft(
            name: "  Work  ",
            endpoint: " https://s3.example.com/// ",
            region: " us-east-1 ",
            bucket: " media ",
            accessKey: " ACCESS ",
            secretKey: " SECRET ",
            usePathStyle: true
        )

        let validated = try draft.validated()

        #expect(validated.name == "Work")
        #expect(validated.endpointURL == URL(string: "https://s3.example.com"))
        #expect(validated.region == "us-east-1")
        #expect(validated.bucket == "media")
        #expect(validated.accessKey == "ACCESS")
        #expect(validated.secretKey == "SECRET")
        #expect(validated.usePathStyle)
    }

    @Test
    func validatedDraftRejectsInvalidEndpoint() {
        let draft = ConnectionProfileDraft(
            name: "Work",
            endpoint: "not a url",
            region: "us-east-1",
            bucket: "media",
            accessKey: "ACCESS",
            secretKey: "SECRET",
            usePathStyle: true
        )

        #expect(throws: ConnectionProfileValidationError.invalidEndpoint) {
            try draft.validated()
        }
    }

    @Test
    func draftFromProfileTakesCredentialsFromArgument() {
        let profile = ConnectionProfile(
            name: "Work",
            endpoint: "https://s3.example.com",
            region: "us-east-1",
            bucket: "media",
            usePathStyle: false
        )

        let draft = ConnectionProfileDraft(
            profile: profile,
            credentials: S3Credentials(accessKeyID: "ACCESS", secretAccessKey: "SECRET")
        )

        #expect(draft.name == "Work")
        #expect(draft.endpoint == "https://s3.example.com")
        #expect(draft.region == "us-east-1")
        #expect(draft.bucket == "media")
        #expect(draft.usePathStyle == false)
        #expect(draft.accessKey == "ACCESS")
        #expect(draft.secretKey == "SECRET")
    }

    @Test
    func draftWithoutCredentialsLeavesKeysEmptyAndFailsValidation() {
        let profile = ConnectionProfile(
            name: "Work",
            endpoint: "https://s3.example.com",
            region: "us-east-1",
            bucket: "media",
            usePathStyle: true
        )

        let draft = ConnectionProfileDraft(profile: profile, credentials: nil)

        #expect(draft.accessKey.isEmpty)
        #expect(draft.secretKey.isEmpty)
        #expect(throws: ConnectionProfileValidationError.missingAccessKey) {
            try draft.validated()
        }
    }
}
