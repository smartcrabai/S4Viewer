/// Stable accessibility identifiers for every element the UI tests drive. The test target
/// cannot import the app module, so `S4 ViewerUITests/Screen.swift` repeats these strings:
/// change one side and the corresponding UI test fails loudly rather than silently.
nonisolated enum A11y {
    enum Sidebar {
        static let empty = "sidebar.empty"
        static let add = "sidebar.add"
        static let edit = "sidebar.edit"
        static let delete = "sidebar.delete"

        static func row(_ profileName: String) -> String {
            "sidebar.row.\(profileName)"
        }
    }

    enum Browser {
        static let locationTitle = "browser.locationTitle"
        static let refresh = "browser.refresh"
        static let open = "browser.open"
        static let up = "browser.up"
        static let upload = "browser.upload"
        static let download = "browser.download"
        static let newFolder = "browser.newFolder"
        static let rename = "browser.rename"
        static let delete = "browser.delete"
        static let filterField = "browser.filterField"
        static let filterClear = "browser.filterClear"
        static let sortPicker = "browser.sortPicker"
        static let table = "browser.table"
        static let emptyObjects = "browser.emptyObjects"
        static let emptyMatches = "browser.emptyMatches"
        static let noConnection = "browser.noConnection"

        static func row(_ key: String) -> String {
            "browser.row.\(key)"
        }
    }

    enum Transfers {
        static func status(_ name: String) -> String {
            "transfers.status.\(name)"
        }
    }

    enum Preview {
        static let empty = "preview.empty"
        static let failed = "preview.failed"
        static let loading = "preview.loading"
        static let name = "preview.name"
        static let key = "preview.key"
        static let inlineText = "preview.inlineText"
        static let quickLook = "preview.quickLook"
    }

    enum ProfileEditor {
        static let name = "profileEditor.name"
        static let endpoint = "profileEditor.endpoint"
        static let region = "profileEditor.region"
        static let bucket = "profileEditor.bucket"
        static let accessKey = "profileEditor.accessKey"
        static let secretKey = "profileEditor.secretKey"
        static let save = "profileEditor.save"
        static let cancel = "profileEditor.cancel"
        static let validationMessage = "profileEditor.validationMessage"
    }

    enum NamePrompt {
        static let field = "namePrompt.field"
        static let submit = "namePrompt.submit"
    }

    enum Confirm {
        static let deleteProfile = "confirm.deleteProfile"
        static let deleteItem = "confirm.deleteItem"
    }

    enum ErrorAlert {
        static let message = "errorAlert.message"
        static let dismiss = "errorAlert.dismiss"
    }
}
