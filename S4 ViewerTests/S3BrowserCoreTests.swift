import Foundation
import Testing
@testable import S4_Viewer

struct S3BrowserCoreTests {
    @Test
    func nameSortingKeepsFoldersFirst() {
        let items = sampleItems.shuffled()

        let sorted = S3BrowserSortMode.nameAscending.sorted(items)

        #expect(sorted.map(\.key) == [
            "photos/archive/",
            "photos/alpha.txt",
            "photos/zeta.jpg",
        ])
    }

    @Test
    func sizeSortingUsesDescendingSizeInsideFiles() {
        let items = sampleItems.shuffled()

        let sorted = S3BrowserSortMode.sizeDescending.sorted(items)

        #expect(sorted.map(\.key) == [
            "photos/archive/",
            "photos/alpha.txt",
            "photos/zeta.jpg",
        ])
    }

    @Test
    func emptyFilterReturnsAllItems() {
        let model = S3BrowserModel()
        model.items = sampleItems

        model.filterText = ""

        #expect(model.isFilterActive == false)
        #expect(Set(model.sortedItems.map(\.key)) == Set(sampleItems.map(\.key)))
    }

    @Test
    func whitespaceOnlyFilterIsIgnored() {
        let model = S3BrowserModel()
        model.items = sampleItems

        model.filterText = "   "

        #expect(model.isFilterActive == false)
        #expect(model.sortedItems.count == sampleItems.count)
    }

    @Test
    func filterMatchesItemsCaseInsensitively() {
        let model = S3BrowserModel()
        model.items = sampleItems

        model.filterText = "ZET"

        #expect(model.isFilterActive == true)
        #expect(model.sortedItems.map(\.key) == ["photos/zeta.jpg"])
    }

    @Test
    func filterMatchesFoldersAndFilesAndKeepsSortOrder() {
        let model = S3BrowserModel()
        model.items = sampleItems
        model.sortMode = .nameAscending

        model.filterText = "a"

        #expect(model.sortedItems.map(\.key) == [
            "photos/archive/",
            "photos/alpha.txt",
            "photos/zeta.jpg",
        ])
    }

    @Test
    func filterWithNoMatchesReturnsEmpty() {
        let model = S3BrowserModel()
        model.items = sampleItems

        model.filterText = "nothing"

        #expect(model.sortedItems.isEmpty)
        #expect(model.isFilterActive == true)
    }

    @Test
    func previewKindUsesContentTypeAndExtensionHints() {
        #expect(ObjectPreviewKind.resolve(key: "notes.md", contentType: nil) == .inlineText)
        #expect(ObjectPreviewKind.resolve(key: "photo.raw", contentType: "image/jpeg") == .quickLook)
        #expect(ObjectPreviewKind.resolve(key: "archive.bin", contentType: "application/octet-stream") == .unsupported)
    }

    private var sampleItems: [S3BrowserItem] {
        [
            .folder(key: "photos/archive/"),
            .object(
                key: "photos/zeta.jpg",
                size: 5,
                modifiedAt: Date(timeIntervalSince1970: 1_713_744_000),
                eTag: "\"etag-zeta\"",
                contentType: "image/jpeg"
            ),
            .object(
                key: "photos/alpha.txt",
                size: 20,
                modifiedAt: Date(timeIntervalSince1970: 1_713_657_600),
                eTag: "\"etag-alpha\"",
                contentType: "text/plain"
            ),
        ]
    }
}
