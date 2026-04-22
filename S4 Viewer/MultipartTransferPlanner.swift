import Foundation

nonisolated struct MultipartTransferPlan: Equatable, Sendable {
    nonisolated struct Part: Equatable, Sendable {
        let partNumber: Int
        let offset: Int64
        let length: Int64

        var upperBound: Int64 {
            max(offset, offset + length - 1)
        }

        var rangeHeaderValue: String? {
            guard length > 0 else {
                return nil
            }
            return "bytes=\(offset)-\(upperBound)"
        }
    }

    let isMultipart: Bool
    let partSize: Int64
    let parts: [Part]
}

nonisolated struct MultipartTransferPlanner: Equatable, Sendable {
    let multipartThreshold: Int64
    let preferredPartSize: Int64
    let minimumPartSize: Int64
    let maximumPartCount: Int

    nonisolated init(
        multipartThreshold: Int64 = 8 * 1_048_576,
        preferredPartSize: Int64 = 8 * 1_048_576,
        minimumPartSize: Int64 = 5 * 1_048_576,
        maximumPartCount: Int = 10_000
    ) {
        self.multipartThreshold = multipartThreshold
        self.preferredPartSize = preferredPartSize
        self.minimumPartSize = minimumPartSize
        self.maximumPartCount = maximumPartCount
    }

    func plan(byteCount: Int64) -> MultipartTransferPlan {
        guard byteCount > 0 else {
            return MultipartTransferPlan(
                isMultipart: false,
                partSize: 0,
                parts: [.init(partNumber: 1, offset: 0, length: 0)]
            )
        }

        if byteCount < multipartThreshold {
            return MultipartTransferPlan(
                isMultipart: false,
                partSize: byteCount,
                parts: [.init(partNumber: 1, offset: 0, length: byteCount)]
            )
        }

        var partSize = max(preferredPartSize, minimumPartSize)
        if Int(ceil(Double(byteCount) / Double(partSize))) > maximumPartCount {
            let candidate = Int64(ceil(Double(byteCount) / Double(maximumPartCount)))
            partSize = max(candidate, minimumPartSize)
        }

        var offset: Int64 = 0
        var parts: [MultipartTransferPlan.Part] = []
        var partNumber = 1

        while offset < byteCount {
            let remaining = byteCount - offset
            let length = min(partSize, remaining)
            parts.append(.init(partNumber: partNumber, offset: offset, length: length))
            offset += length
            partNumber += 1
        }

        return MultipartTransferPlan(
            isMultipart: true,
            partSize: partSize,
            parts: parts
        )
    }
}
