import Foundation

nonisolated struct S3ListObjectsPage: Equatable, Sendable {
    let items: [S3BrowserItem]
    let nextContinuationToken: String?
}

nonisolated struct S3ListObjectsResponseParser {
    func parse(
        data: Data,
        prefix: String,
        includePrefixPlaceholder: Bool = false
    ) throws -> S3ListObjectsPage {
        let document = try XMLDocument(data: data)
        guard let root = document.rootElement() else {
            return S3ListObjectsPage(items: [], nextContinuationToken: nil)
        }

        let shouldDecodeKeys = root.firstValue(for: "EncodingType") == "url"
        let currentPrefix = prefix

        let folders = root.elements(forName: "CommonPrefixes")
            .compactMap { $0.firstValue(for: "Prefix") }
            .compactMap { decodeIfNeeded($0, shouldDecode: shouldDecodeKeys) }
            .map { S3BrowserItem.folder(key: $0) }

        let objects = root.elements(forName: "Contents")
            .compactMap { element -> S3BrowserItem? in
                guard
                    let rawKey = element.firstValue(for: "Key"),
                    let key = decodeIfNeeded(rawKey, shouldDecode: shouldDecodeKeys)
                else {
                    return nil
                }

                if key == currentPrefix && !includePrefixPlaceholder {
                    return nil
                }

                let size = Int64(element.firstValue(for: "Size") ?? "")
                return S3BrowserItem.object(
                    key: key,
                    size: size ?? 0,
                    modifiedAt: parseS3Timestamp(element.firstValue(for: "LastModified")),
                    eTag: element.firstValue(for: "ETag"),
                    contentType: nil
                )
            }

        return S3ListObjectsPage(
            items: folders + objects,
            nextContinuationToken: root.firstValue(for: "NextContinuationToken")
        )
    }

    private func decodeIfNeeded(_ value: String, shouldDecode: Bool) -> String? {
        guard shouldDecode else {
            return value
        }
        return value.removingPercentEncoding
    }
}

/// ISO 8601 with or without fractional seconds, as S3 and compatible services emit it.
nonisolated func parseS3Timestamp(_ value: String?) -> Date? {
    guard let value else {
        return nil
    }
    if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
        return date
    }
    return try? Date.ISO8601FormatStyle().parse(value)
}

extension XMLElement {
    nonisolated func firstValue(for name: String) -> String? {
        elements(forName: name).first?.stringValue
    }
}

