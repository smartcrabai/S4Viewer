import AppKit
import Foundation

@MainActor
enum FilePanelSupport {
    static func chooseDownloadURL(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedName
        return panel.runModal() == .OK ? panel.url : nil
    }
}
