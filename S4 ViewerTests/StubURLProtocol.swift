import Foundation
import Synchronization

/// Serves canned responses per host, in order, and records each request with its body, so
/// client tests never reach the network. Keyed by host because Swift Testing runs suites in
/// parallel; each suite stubs its own host.
final class StubURLProtocol: URLProtocol {
    struct Recorded {
        let request: URLRequest
        let body: Data
    }

    private struct HostState {
        var responses: [(status: Int, body: String)] = []
        var requests: [Recorded] = []
    }

    private static let state = Mutex([String: HostState]())

    static func reset(host: String, responses: [String]) {
        reset(host: host, statusResponses: responses.map { (200, $0) })
    }

    static func reset(host: String, statusResponses: [(status: Int, body: String)]) {
        state.withLock { $0[host] = HostState(responses: statusResponses) }
    }

    static func recordedRequests(host: String) -> [Recorded] {
        state.withLock { $0[host]?.requests ?? [] }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        let recorded = Recorded(request: request, body: Self.readBody(of: request))
        let next = Self.state.withLock { state -> (status: Int, body: String) in
            state[host, default: HostState()].requests.append(recorded)
            guard state[host]?.responses.isEmpty == false else {
                return (404, "")
            }
            return state[host]!.responses.removeFirst()
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: next.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(next.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands protocols the body as a stream, not `httpBody`.
    private static func readBody(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
