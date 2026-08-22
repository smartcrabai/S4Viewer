import AppKit
import Foundation

@MainActor
enum FilePanelSupport {
    static func chooseDownloadURL(suggestedName: String) -> URL? {
#if DEBUG
        // Demo mode replaces the panel: a UI test cannot drive a system panel, and the
        // download path is worth covering.
        if DemoMode.isEnabled {
            return DemoMode.downloadDestination(suggestedName: suggestedName)
        }
#endif
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedName
        return panel.runModal() == .OK ? panel.url : nil
    }
}
