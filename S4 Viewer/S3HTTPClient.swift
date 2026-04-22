import Foundation
import UniformTypeIdentifiers

enum S3ClientError: LocalizedError {
    case invalidResponse
    case httpFailure(statusCode: Int, message: String)
    case missingUploadID
    case missingETag
    case invalidName(String)
    case previewUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The S3 service returned an invalid response."
        case let .httpFailure(statusCode, message):
            return "S3 request failed with status \(statusCode): \(message)"
        case .missingUploadID:
            return "The multipart upload response did not include an upload identifier."
        case .missingETag:
            return "The S3 response did not include an ETag for the uploaded part."
        case let .invalidName(value):
            return "Enter a valid name. \"\(value)\" is not allowed here."
        case .previewUnavailable:
            return "Preview is not available for the selected file."
        }
    }
}

protocol S3ClientProtocol: Sendable {
    func list(prefix: String) async throws -> S3ListObjectsPage
    func createFolder(named folderName: String, in prefix: String) async throws
    func rename(item: S3BrowserItem, to newName: String) async throws -> String
    func delete(item: S3BrowserItem) async throws
    func uploadFile(
        at fileURL: URL,
        to prefix: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws
    func download(
        item: S3BrowserItem,
        to destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws
    func preparePreview(
        for item: S3BrowserItem,
        in directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
}

nonisolated private enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case delete = "DELETE"
}

nonisolated private enum S3Header {
    static let contentType = "Content-Type"
    static let range = "Range"
    static let eTag = "ETag"
    static let copySource = "x-amz-copy-source"
}

nonisolated private enum S3QueryKey {
    static let listType = "list-type"
    static let prefix = "prefix"
    static let delimiter = "delimiter"
    static let continuationToken = "continuation-token"
    static let encodingType = "encoding-type"
    static let uploads = "uploads"
    static let uploadID = "uploadId"
    static let partNumber = "partNumber"
}

nonisolated final class S3HTTPClient: S3ClientProtocol, @unchecked Sendable {
    private let configuration: S3ConnectionConfiguration
    private let session: URLSession
    private let signer: S3RequestSigner
    private let multipartPlanner: MultipartTransferPlanner
    private let parser = S3ListObjectsResponseParser()
    private let fileManager: FileManager

    init(
        configuration: S3ConnectionConfiguration,
        session: URLSession = .shared,
        signer: S3RequestSigner = S3RequestSigner(),
        multipartPlanner: MultipartTransferPlanner = MultipartTransferPlanner(),
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.session = session
        self.signer = signer
        self.multipartPlanner = multipartPlanner
        self.fileManager = fileManager
    }

    func list(prefix: String) async throws -> S3ListObjectsPage {
        var items: [S3BrowserItem] = []
        var continuationToken: String?

        repeat {
            let page = try await listPage(prefix: prefix, continuationToken: continuationToken, delimiter: "/")
            items.append(contentsOf: page.items)
            continuationToken = page.nextContinuationToken
        } while continuationToken != nil

        return S3ListObjectsPage(items: items, nextContinuationToken: nil)
    }

    func createFolder(named folderName: String, in prefix: String) async throws {
        let normalized = try validateSinglePathComponent(folderName)
        let key = prefix + normalized + "/"
        _ = try await performRequest(
            method: .put,
            key: key,
            queryItems: [],
            headers: [S3Header.contentType: "application/x-directory"],
            payload: Data()
        )
    }

    func rename(item: S3BrowserItem, to newName: String) async throws -> String {
        let normalized = try validateSinglePathComponent(newName)
        let destinationKey = makeRenamedKey(for: item, using: normalized)

        if item.kind == .object {
            try await copyObject(from: item.key, to: destinationKey)
            try await deleteKey(item.key)
            return destinationKey
        }

        let sourceKeys = try await listAllKeys(prefix: item.key, includePrefixPlaceholder: true)
        for sourceKey in sourceKeys {
            let suffix = String(sourceKey.dropFirst(item.key.count))
            let targetKey = destinationKey + suffix
            try await copyObject(from: sourceKey, to: targetKey)
        }

        for sourceKey in sourceKeys {
            try await deleteKey(sourceKey)
        }

        return destinationKey
    }

    func delete(item: S3BrowserItem) async throws {
        if item.kind == .object {
            try await deleteKey(item.key)
            return
        }

        let keys = try await listAllKeys(prefix: item.key, includePrefixPlaceholder: true)
        for key in keys {
            try await deleteKey(key)
        }
    }

    func uploadFile(
        at fileURL: URL,
        to prefix: String,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let fileName = fileURL.lastPathComponent
        let key = prefix + fileName
        let fileSize = try fileSize(for: fileURL)
        let contentType = mimeType(for: fileURL)
        let plan = multipartPlanner.plan(byteCount: fileSize)

        if !plan.isMultipart {
            let data = try Data(contentsOf: fileURL)
            var headers: [String: String] = [:]
            headers[S3Header.contentType] = contentType
            _ = try await performRequest(
                method: .put,
                key: key,
                queryItems: [],
                headers: headers,
                payload: data
            )
            progress(1)
            return
        }

        let uploadID = try await createMultipartUpload(key: key, contentType: contentType)
        var completedParts: [(partNumber: Int, eTag: String)] = []
        var completedBytes: Int64 = 0

        do {
            for part in plan.parts {
                let data = try readChunk(from: fileURL, offset: part.offset, length: part.length)
                let eTag = try await uploadPart(
                    data,
                    key: key,
                    uploadID: uploadID,
                    partNumber: part.partNumber
                )
                completedParts.append((partNumber: part.partNumber, eTag: eTag))
                completedBytes += part.length
                progress(Double(completedBytes) / Double(fileSize))
            }

            try await completeMultipartUpload(
                key: key,
                uploadID: uploadID,
                parts: completedParts.sorted { $0.partNumber < $1.partNumber }
            )
        } catch {
            try? await abortMultipartUpload(key: key, uploadID: uploadID)
            throw error
        }
    }

    func download(
        item: S3BrowserItem,
        to destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try ensureParentDirectoryExists(for: destinationURL)

        let byteCount = item.size ?? 0
        let plan = multipartPlanner.plan(byteCount: byteCount)

        if !plan.isMultipart || byteCount == 0 {
            let data = try await objectData(forKey: item.key, range: nil)
            try data.write(to: destinationURL, options: .atomic)
            progress(1)
            return
        }

        fileManager.createFile(atPath: destinationURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: destinationURL)
        var completedBytes: Int64 = 0

        do {
            for part in plan.parts {
                guard let range = part.rangeHeaderValue else {
                    throw S3ClientError.invalidResponse
                }
                let data = try await objectData(forKey: item.key, range: range)
                try fileHandle.write(contentsOf: data)
                completedBytes += Int64(data.count)
                progress(Double(completedBytes) / Double(byteCount))
            }
            try fileHandle.close()
        } catch {
            try? fileHandle.close()
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    func preparePreview(
        for item: S3BrowserItem,
        in directory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard item.kind == .object else {
            throw S3ClientError.previewUnavailable
        }

        let previewURL = directory.appendingPathComponent("\(UUID().uuidString)-\(item.name)")
        try await download(item: item, to: previewURL, progress: progress)
        return previewURL
    }

    private func listPage(
        prefix: String,
        continuationToken: String?,
        delimiter: String?
    ) async throws -> S3ListObjectsPage {
        let (data, _) = try await performRequest(
            method: .get,
            key: nil,
            queryItems: makeListQueryItems(
                prefix: prefix,
                continuationToken: continuationToken,
                delimiter: delimiter
            ),
            headers: [:],
            payload: Data()
        )
        return try parser.parse(data: data, prefix: prefix)
    }

    private func listAllKeys(prefix: String, includePrefixPlaceholder: Bool) async throws -> [String] {
        var keys: [String] = []
        var continuationToken: String?

        repeat {
            let (data, _) = try await performRequest(
                method: .get,
                key: nil,
                queryItems: makeListQueryItems(
                    prefix: prefix,
                    continuationToken: continuationToken,
                    delimiter: nil
                ),
                headers: [:],
                payload: Data()
            )
            let page = try parser.parse(
                data: data,
                prefix: prefix,
                includePrefixPlaceholder: includePrefixPlaceholder
            )
            keys.append(contentsOf: page.items.filter { $0.kind == .object }.map(\.key))
            continuationToken = page.nextContinuationToken
        } while continuationToken != nil

        return keys
    }

    private func makeListQueryItems(
        prefix: String,
        continuationToken: String?,
        delimiter: String?
    ) -> [URLQueryItem] {
        var queryItems = [URLQueryItem(name: S3QueryKey.listType, value: "2")]
        if !prefix.isEmpty {
            queryItems.append(URLQueryItem(name: S3QueryKey.prefix, value: prefix))
        }
        if let delimiter {
            queryItems.append(URLQueryItem(name: S3QueryKey.delimiter, value: delimiter))
        }
        if let continuationToken {
            queryItems.append(URLQueryItem(name: S3QueryKey.continuationToken, value: continuationToken))
        }
        queryItems.append(URLQueryItem(name: S3QueryKey.encodingType, value: "url"))
        return queryItems
    }

    private func createMultipartUpload(key: String, contentType: String?) async throws -> String {
        var headers: [String: String] = [:]
        if let contentType {
            headers[S3Header.contentType] = contentType
        }
        let (data, _) = try await performRequest(
            method: .post,
            key: key,
            queryItems: [URLQueryItem(name: S3QueryKey.uploads, value: "")],
            headers: headers,
            payload: Data()
        )

        let document = try XMLDocument(data: data)
        guard
            let uploadID = document.rootElement()?.elements(forName: "UploadId").first?.stringValue,
            !uploadID.isEmpty
        else {
            throw S3ClientError.missingUploadID
        }
        return uploadID
    }

    private func uploadPart(
        _ data: Data,
        key: String,
        uploadID: String,
        partNumber: Int
    ) async throws -> String {
        let (_, response) = try await performRequest(
            method: .put,
            key: key,
            queryItems: [
                URLQueryItem(name: S3QueryKey.partNumber, value: "\(partNumber)"),
                URLQueryItem(name: S3QueryKey.uploadID, value: uploadID),
            ],
            headers: [:],
            payload: data
        )

        guard let eTag = response.value(forHTTPHeaderField: S3Header.eTag), !eTag.isEmpty else {
            throw S3ClientError.missingETag
        }
        return eTag
    }

    private func completeMultipartUpload(
        key: String,
        uploadID: String,
        parts: [(partNumber: Int, eTag: String)]
    ) async throws {
        let partXML = parts.map { "<Part><PartNumber>\($0.partNumber)</PartNumber><ETag>\($0.eTag.xmlEscaped)</ETag></Part>" }.joined()
        let payload = Data("<CompleteMultipartUpload>\(partXML)</CompleteMultipartUpload>".utf8)

        _ = try await performRequest(
            method: .post,
            key: key,
            queryItems: [URLQueryItem(name: S3QueryKey.uploadID, value: uploadID)],
            headers: [S3Header.contentType: "application/xml"],
            payload: payload
        )
    }

    private func abortMultipartUpload(key: String, uploadID: String) async throws {
        _ = try await performRequest(
            method: .delete,
            key: key,
            queryItems: [URLQueryItem(name: S3QueryKey.uploadID, value: uploadID)],
            headers: [:],
            payload: Data()
        )
    }

    private func copyObject(from sourceKey: String, to destinationKey: String) async throws {
        let copySource = "/" + configuration.bucket + "/" + Self.encodeS3Key(sourceKey)
        _ = try await performRequest(
            method: .put,
            key: destinationKey,
            queryItems: [],
            headers: [S3Header.copySource: copySource],
            payload: Data()
        )
    }

    private func deleteKey(_ key: String) async throws {
        _ = try await performRequest(
            method: .delete,
            key: key,
            queryItems: [],
            headers: [:],
            payload: Data()
        )
    }

    private func objectData(forKey key: String, range: String?) async throws -> Data {
        var headers: [String: String] = [:]
        if let range {
            headers[S3Header.range] = range
        }
        let (data, _) = try await performRequest(
            method: .get,
            key: key,
            queryItems: [],
            headers: headers,
            payload: Data()
        )
        return data
    }

    private func performRequest(
        method: HTTPMethod,
        key: String?,
        queryItems: [URLQueryItem],
        headers: [String: String],
        payload: Data
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try makeURL(for: key, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let signedRequest = try signer.sign(
            request,
            payload: payload,
            credentials: configuration.credentials,
            region: configuration.region
        )
        let (data, response) = try await session.data(for: signedRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw S3ClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw S3ClientError.httpFailure(
                statusCode: httpResponse.statusCode,
                message: parseErrorMessage(from: data)
            )
        }

        return (data, httpResponse)
    }

    private func makeURL(for key: String?, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: configuration.endpointURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        if configuration.usePathStyle {
            components.percentEncodedPath = makePercentEncodedPath(
                basePath: configuration.endpointURL.path,
                bucket: configuration.bucket,
                key: key
            )
        } else {
            let existingHost = components.host ?? ""
            components.host = "\(configuration.bucket).\(existingHost)"
            components.percentEncodedPath = makePercentEncodedPath(
                basePath: configuration.endpointURL.path,
                bucket: nil,
                key: key
            )
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private func makePercentEncodedPath(basePath: String, bucket: String?, key: String?) -> String {
        let normalizedBase = basePath == "/" ? "" : basePath
        var components: [String] = []
        if !normalizedBase.isEmpty {
            let trimmed = normalizedBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !trimmed.isEmpty {
                components.append(trimmed)
            }
        }
        if let bucket {
            components.append(bucket)
        }
        if let key, !key.isEmpty {
            components.append(key)
        }

        let encoded = components
            .map(Self.encodeS3Key)
            .joined(separator: "/")

        return "/" + encoded
    }

    private func fileSize(for url: URL) throws -> Int64 {
        let fileValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(fileValues.fileSize ?? 0)
    }

    private func mimeType(for url: URL) -> String? {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return nil
        }
        return type.preferredMIMEType
    }

    private func readChunk(from url: URL, offset: Int64, length: Int64) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        return try handle.read(upToCount: Int(length)) ?? Data()
    }

    private func ensureParentDirectoryExists(for url: URL) throws {
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func parseErrorMessage(from data: Data) -> String {
        guard !data.isEmpty else {
            return "The server returned an empty error response."
        }

        if
            let document = try? XMLDocument(data: data),
            let message = document.rootElement()?.elements(forName: "Message").first?.stringValue,
            !message.isEmpty
        {
            return message
        }

        return String(data: data, encoding: .utf8) ?? "The server returned an unreadable error response."
    }

    private func makeRenamedKey(for item: S3BrowserItem, using newName: String) -> String {
        let parentPrefix = item.key.parentS3Prefix
        if item.kind == .folder {
            return parentPrefix + newName + "/"
        }
        return parentPrefix + newName
    }

    private func validateSinglePathComponent(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalized.isEmpty, !normalized.contains("/") else {
            throw S3ClientError.invalidName(value)
        }
        return normalized
    }

    nonisolated private static func encodeS3Key(_ key: String) -> String {
        key
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { S3RequestSigner.uriEncodeComponent(String($0)) }
            .joined(separator: "/")
    }
}

private extension String {
    nonisolated var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
