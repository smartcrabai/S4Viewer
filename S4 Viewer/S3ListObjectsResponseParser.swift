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
                    modifiedAt: parseDate(element.firstValue(for: "LastModified")),
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

    private func parseDate(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }
        return ISO8601DateFormatter.withFractionalSeconds.date(from: value)
            ?? ISO8601DateFormatter.standardInternet.date(from: value)
    }
}

private extension XMLElement {
    func firstValue(for name: String) -> String? {
        elements(forName: name).first?.stringValue
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standardInternet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
