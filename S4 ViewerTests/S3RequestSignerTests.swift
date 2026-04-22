import Foundation
import Testing
@testable import S4_Viewer

struct S3RequestSignerTests {
    @Test
    func signerMatchesAwsGetObjectExample() throws {
        var request = URLRequest(url: URL(string: "https://examplebucket.s3.amazonaws.com/test.txt")!)
        request.httpMethod = "GET"
        request.setValue("bytes=0-9", forHTTPHeaderField: "Range")

        let signed = try S3RequestSigner().sign(
            request,
            payload: Data(),
            credentials: S3Credentials(
                accessKeyID: "AKIAIOSFODNN7EXAMPLE",
                secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
            ),
            region: "us-east-1",
            timestamp: Date.awsExampleTimestamp
        )

        #expect(signed.value(forHTTPHeaderField: "x-amz-date") == "20130524T000000Z")
        #expect(signed.value(forHTTPHeaderField: "Authorization") == "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=host;range;x-amz-content-sha256;x-amz-date,Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41")
    }

    @Test
    func signerMatchesAwsListObjectsExample() throws {
        var request = URLRequest(url: URL(string: "https://examplebucket.s3.amazonaws.com/?max-keys=2&prefix=J")!)
        request.httpMethod = "GET"

        let signed = try S3RequestSigner().sign(
            request,
            payload: Data(),
            credentials: S3Credentials(
                accessKeyID: "AKIAIOSFODNN7EXAMPLE",
                secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
            ),
            region: "us-east-1",
            timestamp: Date.awsExampleTimestamp
        )

        #expect(signed.value(forHTTPHeaderField: "Authorization") == "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,SignedHeaders=host;x-amz-content-sha256;x-amz-date,Signature=34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7")
    }
}

private extension Date {
    static let awsExampleTimestamp = ISO8601DateFormatter.awsSignatureExample.date(from: "2013-05-24T00:00:00Z")!
}

private extension ISO8601DateFormatter {
    static let awsSignatureExample: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
