import Foundation

nonisolated struct S3Bucket: Equatable, Sendable {
    let name: String
    /// `BucketRegion` from `ListBuckets`. AWS returns it; most S3-compatible services do not.
    let region: String?
    let createdAt: Date?
}

nonisolated struct S3ListBucketsPage: Equatable, Sendable {
    let buckets: [S3Bucket]
    let continuationToken: String?
}

nonisolated struct S3ListBucketsResponseParser {
    func parse(data: Data) throws -> S3ListBucketsPage {
        let document = try XMLDocument(data: data)
        guard let root = document.rootElement() else {
            return S3ListBucketsPage(buckets: [], continuationToken: nil)
        }

        let buckets = root.elements(forName: "Buckets")
            .flatMap { $0.elements(forName: "Bucket") }
            .compactMap { element -> S3Bucket? in
                guard let name = element.firstValue(for: "Name"), !name.isEmpty else {
                    return nil
                }
                let region = element.firstValue(for: "BucketRegion")
                return S3Bucket(
                    name: name,
                    region: region?.isEmpty == false ? region : nil,
                    createdAt: parseS3Timestamp(element.firstValue(for: "CreationDate"))
                )
            }

        let token = root.firstValue(for: "ContinuationToken")
        return S3ListBucketsPage(
            buckets: buckets,
            continuationToken: token?.isEmpty == false ? token : nil
        )
    }
}
