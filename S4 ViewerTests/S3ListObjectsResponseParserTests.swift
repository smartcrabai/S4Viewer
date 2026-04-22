import Foundation
import Testing
@testable import S4_Viewer

struct S3ListObjectsResponseParserTests {
    @Test
    func parserBuildsFolderAndObjectEntries() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult>
            <Name>examplebucket</Name>
            <Prefix>photos/</Prefix>
            <KeyCount>3</KeyCount>
            <MaxKeys>1000</MaxKeys>
            <IsTruncated>false</IsTruncated>
            <EncodingType>url</EncodingType>
            <Contents>
                <Key>photos/beach.jpg</Key>
                <LastModified>2026-04-20T11:00:00.000Z</LastModified>
                <ETag>"etag-beach"</ETag>
                <Size>20</Size>
                <StorageClass>STANDARD</StorageClass>
            </Contents>
            <Contents>
                <Key>photos/notes%20space.txt</Key>
                <LastModified>2026-04-20T12:00:00.000Z</LastModified>
                <ETag>"etag-notes"</ETag>
                <Size>5</Size>
                <StorageClass>STANDARD</StorageClass>
            </Contents>
            <CommonPrefixes>
                <Prefix>photos/archive/</Prefix>
            </CommonPrefixes>
        </ListBucketResult>
        """

        let page = try S3ListObjectsResponseParser().parse(data: Data(xml.utf8), prefix: "photos/")

        #expect(page.nextContinuationToken == nil)
        #expect(page.items.map(\.key) == [
            "photos/archive/",
            "photos/beach.jpg",
            "photos/notes space.txt",
        ])
        #expect(page.items.first?.kind == .folder)
        #expect(page.items.last?.name == "notes space.txt")
    }
}
