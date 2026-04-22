import Foundation

extension String {
    nonisolated var parentS3Prefix: String {
        let normalized = trimmingTrailingSlashes
        guard let range = normalized.range(of: "/", options: .backwards) else {
            return ""
        }
        return String(normalized[..<range.upperBound])
    }

    nonisolated var trimmingTrailingSlashes: String {
        var result = self
        while result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    nonisolated var lastS3PathComponent: String {
        let normalized = trimmingTrailingSlashes
        guard let last = normalized.split(separator: "/").last else {
            return normalized
        }
        return String(last)
    }
}
