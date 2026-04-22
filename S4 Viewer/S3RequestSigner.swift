import CryptoKit
import Foundation

nonisolated struct S3RequestSigner {
    private static let emptyPayloadHash = SHA256.hash(data: Data()).hexDigest
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()
    private static let scopeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    nonisolated init() {}

    nonisolated func sign(
        _ request: URLRequest,
        payload: Data,
        credentials: S3Credentials,
        region: String,
        timestamp: Date = .now
    ) throws -> URLRequest {
        guard let url = request.url else {
            throw URLError(.badURL)
        }

        var signedRequest = request
        let timestampValue = Self.timestampFormatter.string(from: timestamp)
        let scopeDate = Self.scopeDateFormatter.string(from: timestamp)
        let payloadHash = payload.isEmpty ? Self.emptyPayloadHash : SHA256.hash(data: payload).hexDigest
        let host = url.hostWithPort
        guard !host.isEmpty else {
            throw URLError(.badURL)
        }

        signedRequest.setValue(host, forHTTPHeaderField: "Host")
        signedRequest.setValue(timestampValue, forHTTPHeaderField: "x-amz-date")
        signedRequest.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        if !payload.isEmpty {
            signedRequest.httpBody = payload
        }

        let canonicalHeaders = canonicalHeaders(for: signedRequest)
        let signedHeaders = canonicalHeaders.map(\.name).joined(separator: ";")
        let canonicalRequest = [
            signedRequest.httpMethod ?? "GET",
            canonicalURI(for: url),
            canonicalQueryString(for: url),
            canonicalHeaders.map { "\($0.name):\($0.value)" }.joined(separator: "\n") + "\n",
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")

        let stringToSign = [
            "AWS4-HMAC-SHA256",
            timestampValue,
            "\(scopeDate)/\(region)/s3/aws4_request",
            SHA256.hash(data: Data(canonicalRequest.utf8)).hexDigest,
        ].joined(separator: "\n")

        let signingKey = signingKey(
            secretAccessKey: credentials.secretAccessKey,
            date: scopeDate,
            region: region,
            service: "s3"
        )
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: signingKey
        ).hexDigest

        let authorization = "AWS4-HMAC-SHA256 Credential=\(credentials.accessKeyID)/\(scopeDate)/\(region)/s3/aws4_request,SignedHeaders=\(signedHeaders),Signature=\(signature)"
        signedRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
        return signedRequest
    }

    private func canonicalHeaders(for request: URLRequest) -> [(name: String, value: String)] {
        let headers = request.allHTTPHeaderFields ?? [:]
        return headers
            .map { (name: $0.key.lowercased(), value: normalizedHeaderValue($0.value)) }
            .sorted { $0.name < $1.name }
    }

    private func normalizedHeaderValue(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private func canonicalURI(for url: URL) -> String {
        let path = url.path.isEmpty ? "/" : url.path
        return path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { Self.uriEncodeComponent(String($0)) }
            .joined(separator: "/")
    }

    private func canonicalQueryString(for url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return ""
        }

        return (components.queryItems ?? [])
            .map {
                (
                    Self.uriEncodeComponent($0.name),
                    Self.uriEncodeComponent($0.value ?? "")
                )
            }
            .sorted {
                if $0.0 == $1.0 {
                    return $0.1 < $1.1
                }
                return $0.0 < $1.0
            }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
    }

    private func signingKey(secretAccessKey: String, date: String, region: String, service: String) -> SymmetricKey {
        let initialKey = SymmetricKey(data: Data("AWS4\(secretAccessKey)".utf8))
        let dateKey = hmac(date, using: initialKey)
        let regionKey = hmac(region, using: dateKey)
        let serviceKey = hmac(service, using: regionKey)
        return hmac("aws4_request", using: serviceKey)
    }

    private func hmac(_ string: String, using key: SymmetricKey) -> SymmetricKey {
        let data = Data(HMAC<SHA256>.authenticationCode(for: Data(string.utf8), using: key))
        return SymmetricKey(data: data)
    }

    nonisolated static func uriEncodeComponent(_ string: String) -> String {
        let allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return string.utf8.reduce(into: "") { partialResult, byte in
            let scalar = UnicodeScalar(byte)
            if allowed.unicodeScalars.contains(scalar) {
                partialResult.append(Character(scalar))
            } else {
                partialResult.append(String(format: "%%%02X", byte))
            }
        }
    }
}

private extension URL {
    var hostWithPort: String {
        if let port, let host {
            return "\(host):\(port)"
        }
        return host ?? ""
    }
}

private extension ContiguousBytes {
    nonisolated var hexDigest: String {
        withUnsafeBytes { buffer in
            buffer.map { String(format: "%02x", $0) }.joined()
        }
    }
}
