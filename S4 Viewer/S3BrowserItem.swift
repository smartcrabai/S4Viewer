import Foundation

nonisolated struct S3BrowserItem: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case folder
        case object

        var label: String {
            switch self {
            case .folder:
                return "Folder"
            case .object:
                return "File"
            }
        }

        var systemImageName: String {
            switch self {
            case .folder:
                return "folder"
            case .object:
                return "doc"
            }
        }
    }

    let key: String
    let name: String
    let kind: Kind
    let size: Int64?
    let modifiedAt: Date?
    let eTag: String?
    let contentType: String?

    var id: String { key }

    static func folder(key: String) -> S3BrowserItem {
        S3BrowserItem(
            key: key,
            name: key.lastS3PathComponent,
            kind: .folder,
            size: nil,
            modifiedAt: nil,
            eTag: nil,
            contentType: nil
        )
    }

    static func object(
        key: String,
        size: Int64,
        modifiedAt: Date?,
        eTag: String?,
        contentType: String?
    ) -> S3BrowserItem {
        S3BrowserItem(
            key: key,
            name: key.lastS3PathComponent,
            kind: .object,
            size: size,
            modifiedAt: modifiedAt,
            eTag: eTag,
            contentType: contentType
        )
    }
}

nonisolated enum S3BrowserSortMode: String, CaseIterable, Identifiable, Sendable {
    case nameAscending
    case nameDescending
    case sizeAscending
    case sizeDescending
    case modifiedNewestFirst
    case modifiedOldestFirst
    case kind

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nameAscending:
            return "Name A-Z"
        case .nameDescending:
            return "Name Z-A"
        case .sizeAscending:
            return "Size Smallest"
        case .sizeDescending:
            return "Size Largest"
        case .modifiedNewestFirst:
            return "Modified Newest"
        case .modifiedOldestFirst:
            return "Modified Oldest"
        case .kind:
            return "Kind"
        }
    }

    func sorted(_ items: [S3BrowserItem]) -> [S3BrowserItem] {
        items.sorted(by: compare)
    }

    private func compare(_ lhs: S3BrowserItem, _ rhs: S3BrowserItem) -> Bool {
        if lhs.kind != rhs.kind {
            return lhs.kind == .folder
        }

        switch self {
        case .nameAscending:
            return compareStrings(lhs.name, rhs.name, ascending: true)
        case .nameDescending:
            return compareStrings(lhs.name, rhs.name, ascending: false)
        case .sizeAscending:
            return compareNumbers(lhs.size ?? -1, rhs.size ?? -1, fallbackNameLHS: lhs.name, fallbackNameRHS: rhs.name, ascending: true)
        case .sizeDescending:
            return compareNumbers(lhs.size ?? -1, rhs.size ?? -1, fallbackNameLHS: lhs.name, fallbackNameRHS: rhs.name, ascending: false)
        case .modifiedNewestFirst:
            return compareDates(lhs.modifiedAt, rhs.modifiedAt, fallbackNameLHS: lhs.name, fallbackNameRHS: rhs.name, newestFirst: true)
        case .modifiedOldestFirst:
            return compareDates(lhs.modifiedAt, rhs.modifiedAt, fallbackNameLHS: lhs.name, fallbackNameRHS: rhs.name, newestFirst: false)
        case .kind:
            return compareStrings(lhs.name, rhs.name, ascending: true)
        }
    }

    private func compareStrings(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        switch comparison {
        case .orderedSame:
            return lhs < rhs
        case .orderedAscending:
            return ascending
        case .orderedDescending:
            return !ascending
        }
    }

    private func compareNumbers(
        _ lhs: Int64,
        _ rhs: Int64,
        fallbackNameLHS: String,
        fallbackNameRHS: String,
        ascending: Bool
    ) -> Bool {
        guard lhs != rhs else {
            return compareStrings(fallbackNameLHS, fallbackNameRHS, ascending: true)
        }
        return ascending ? lhs < rhs : lhs > rhs
    }

    private func compareDates(
        _ lhs: Date?,
        _ rhs: Date?,
        fallbackNameLHS: String,
        fallbackNameRHS: String,
        newestFirst: Bool
    ) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?) where left != right:
            return newestFirst ? left > right : left < right
        default:
            return compareStrings(fallbackNameLHS, fallbackNameRHS, ascending: true)
        }
    }
}

