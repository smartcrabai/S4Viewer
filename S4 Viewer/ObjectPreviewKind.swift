import Foundation

nonisolated enum ObjectPreviewKind: Equatable, Sendable {
    case inlineText
    case quickLook
    case unsupported

    static func resolve(key: String, contentType: String?) -> ObjectPreviewKind {
        let fileExtension = URL(fileURLWithPath: key).pathExtension.lowercased()
        let normalizedContentType = contentType?.lowercased()

        if isInlineText(extension: fileExtension, contentType: normalizedContentType) {
            return .inlineText
        }

        if isQuickLookPreviewable(extension: fileExtension, contentType: normalizedContentType) {
            return .quickLook
        }

        return .unsupported
    }

    private static func isInlineText(extension fileExtension: String, contentType: String?) -> Bool {
        if let contentType, contentType.hasPrefix("text/") {
            return true
        }

        return [
            "txt", "md", "markdown", "json", "xml", "yaml", "yml", "csv", "log", "swift", "js", "ts", "html", "css",
        ].contains(fileExtension)
    }

    private static func isQuickLookPreviewable(extension fileExtension: String, contentType: String?) -> Bool {
        if let contentType {
            if contentType.hasPrefix("image/") || contentType.hasPrefix("audio/") || contentType.hasPrefix("video/") {
                return true
            }

            if [
                "application/pdf",
                "application/zip",
                "application/x-zip-compressed",
                "application/vnd.ms-powerpoint",
                "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                "application/msword",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ].contains(contentType) {
                return true
            }
        }

        return [
            "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "webp",
            "pdf",
            "mp3", "wav", "m4a", "aac",
            "mp4", "mov", "m4v",
            "zip",
            "doc", "docx", "ppt", "pptx",
        ].contains(fileExtension)
    }
}
