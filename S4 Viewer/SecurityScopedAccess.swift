import Foundation

enum SecurityScopedAccess {
    static func withAccess<T>(
        to url: URL,
        operation: (URL) async throws -> T
    ) async rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation(url)
    }

    static func withAccess<T>(
        to urls: [URL],
        operation: ([URL]) async throws -> T
    ) async rethrows -> T {
        let started = urls.map { ($0, $0.startAccessingSecurityScopedResource()) }
        defer {
            for (url, didStart) in started where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation(urls)
    }
}
