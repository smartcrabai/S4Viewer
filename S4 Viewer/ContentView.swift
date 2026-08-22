import SwiftData
import SwiftUI
import UniformTypeIdentifiers

nonisolated private enum ItemFormatter {
    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static func size(_ bytes: Int64) -> String {
        byteCount.string(fromByteCount: bytes)
    }

    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ConnectionProfile.name)]) private var profiles: [ConnectionProfile]

    @State private var browser = S3BrowserModel.makeDefault()
    @State private var selectedProfileID: UUID?
    @State private var profileEditor: ProfileEditorSession?
    @State private var namePrompt: NamePromptSession?
    @State private var isShowingUploadImporter = false
    @State private var isConfirmingProfileDeletion = false
    @State private var isConfirmingItemDeletion = false

    private var selectedProfile: ConnectionProfile? {
        profiles.first(where: { $0.id == selectedProfileID })
    }

    var body: some View {
        NavigationSplitView {
            ConnectionSidebarView(
                profiles: profiles,
                selectedProfileID: $selectedProfileID,
                onAddProfile: openCreateProfile,
                onEditProfile: openEditProfile,
                onDeleteProfile: { isConfirmingProfileDeletion = true }
            )
        } content: {
            BrowserColumnView(
                browser: browser,
                profile: selectedProfile,
                onUpload: beginUpload,
                onDownload: beginDownload,
                onCreateFolder: openCreateFolderPrompt,
                onRename: openRenamePrompt,
                onDelete: { isConfirmingItemDeletion = true }
            )
        } detail: {
            PreviewColumnView(browser: browser)
        }
        .navigationTitle("S4 Viewer")
        .sheet(item: $profileEditor) { session in
            ConnectionProfileEditorView(
                title: session.title,
                actionTitle: session.actionTitle,
                draft: session.draft
            ) { validated in
                try saveProfile(validated, existingProfileID: session.existingProfileID)
            }
        }
        .sheet(item: $namePrompt) { prompt in
            NamePromptView(
                title: prompt.title,
                message: prompt.message,
                initialValue: prompt.initialValue,
                actionTitle: prompt.actionTitle
            ) { value in
                await prompt.submit(value)
            }
        }
        .fileImporter(
            isPresented: $isShowingUploadImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard let selectedProfile else {
                return
            }

            switch result {
            case let .success(urls):
                Task {
                    await SecurityScopedAccess.withAccess(to: urls) { accessibleURLs in
                        await browser.uploadFiles(accessibleURLs, using: selectedProfile)
                    }
                }
            case let .failure(error):
                browser.reportError(error.localizedDescription)
            }
        }
        .confirmationDialog(
            "Delete profile?",
            isPresented: $isConfirmingProfileDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: deleteSelectedProfile)
                .accessibilityIdentifier(A11y.Confirm.deleteProfile)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The selected connection profile will be removed from the app.")
        }
        .confirmationDialog(
            "Delete item?",
            isPresented: $isConfirmingItemDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let selectedProfile else {
                    return
                }
                Task {
                    await browser.deleteSelection(using: selectedProfile)
                }
            }
            .accessibilityIdentifier(A11y.Confirm.deleteItem)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The selected S3 item will be deleted.")
        }
        .alert(
            "Operation failed",
            isPresented: Binding(
                get: { browser.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        browser.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier(A11y.ErrorAlert.dismiss)
        } message: {
            Text(browser.errorMessage ?? "")
                .accessibilityIdentifier(A11y.ErrorAlert.message)
        }
        .onChange(of: profiles.map(\.id), initial: true) { _, ids in
            synchronizeProfileSelection(with: ids)
        }
        .task(id: selectedProfile?.id) {
#if DEBUG
            if DemoMode.isEnabled {
                // Publish before connecting so testing-only intents drive this live model.
                DemoAutomationContext.shared.attach(browser: browser, profile: selectedProfile)
            }
#endif
            await browser.connect(to: selectedProfile)
        }
#if DEBUG
        .onDisappear {
            if DemoMode.isEnabled {
                DemoAutomationContext.shared.detach(browser: browser)
            }
        }
#endif
    }

    private func openCreateProfile() {
        profileEditor = ProfileEditorSession(
            title: "Add Connection",
            actionTitle: "Save",
            existingProfileID: nil,
            draft: ConnectionProfileDraft()
        )
    }

    private func openEditProfile() {
        guard let selectedProfile else {
            return
        }
        let credentials: S3Credentials?
        do {
            credentials = try ConnectionCredentialStore.shared.load(for: selectedProfile.id)
        } catch ConnectionCredentialStoreError.missingCredentials {
            credentials = nil
        } catch {
            browser.reportError(error.localizedDescription)
            return
        }
        profileEditor = ProfileEditorSession(
            title: "Edit Connection",
            actionTitle: "Save",
            existingProfileID: selectedProfile.id,
            draft: ConnectionProfileDraft(profile: selectedProfile, credentials: credentials)
        )
    }

    private func openCreateFolderPrompt() {
        guard let selectedProfile else {
            return
        }
        namePrompt = NamePromptSession(
            title: "New Folder",
            message: "Enter the folder name.",
            initialValue: "",
            actionTitle: "Create"
        ) { value in
            await browser.createFolder(named: value, using: selectedProfile)
        }
    }

    private func openRenamePrompt() {
        guard let selectedProfile, let selectedItem = browser.selectedItem else {
            return
        }
        namePrompt = NamePromptSession(
            title: "Rename Item",
            message: "Enter the new name for \(selectedItem.name).",
            initialValue: selectedItem.name,
            actionTitle: "Rename"
        ) { value in
            await browser.renameSelection(to: value, using: selectedProfile)
        }
    }

    @MainActor
    private func beginUpload() {
#if DEBUG
        // Demo mode uploads fixtures instead of opening the importer, which a UI test
        // cannot drive.
        if DemoMode.isEnabled {
            guard let selectedProfile else {
                return
            }
            Task {
                do {
                    let urls = try DemoMode.makeUploadFixtures()
                    await browser.uploadFiles(urls, using: selectedProfile)
                } catch {
                    browser.reportError(error.localizedDescription)
                }
            }
            return
        }
#endif
        isShowingUploadImporter = true
    }

    @MainActor
    private func beginDownload() {
        guard
            let selectedProfile,
            let selectedItem = browser.selectedItem,
            let destinationURL = FilePanelSupport.chooseDownloadURL(suggestedName: selectedItem.name)
        else {
            return
        }

        Task {
            await SecurityScopedAccess.withAccess(to: destinationURL) { accessibleURL in
                await browser.downloadSelection(to: accessibleURL, using: selectedProfile)
            }
        }
    }

    private func saveProfile(_ validated: ValidatedConnectionProfile, existingProfileID: UUID?) throws {
        let profile: ConnectionProfile
        if let existingProfileID, let existing = profiles.first(where: { $0.id == existingProfileID }) {
            existing.apply(validated)
            profile = existing
        } else {
            profile = ConnectionProfile(validated: validated)
            modelContext.insert(profile)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        // Written only after the profile is committed, so a failed save never leaves
        // a secret in the Keychain that no profile references.
        try ConnectionCredentialStore.shared.save(validated.credentials, for: profile.id)
        selectedProfileID = profile.id
    }

    private func deleteSelectedProfile() {
        guard let selectedProfile else {
            return
        }

        let profileID = selectedProfile.id
        do {
            modelContext.delete(selectedProfile)
            try modelContext.save()
            try ConnectionCredentialStore.shared.delete(for: profileID)
        } catch {
            browser.reportError(error.localizedDescription)
        }
    }

    private func synchronizeProfileSelection(with ids: [UUID]) {
        if let selectedProfileID, ids.contains(selectedProfileID) {
            return
        }
        selectedProfileID = ids.first
    }
}

private struct ProfileEditorSession: Identifiable {
    let id = UUID()
    let title: String
    let actionTitle: String
    let existingProfileID: UUID?
    let draft: ConnectionProfileDraft
}

private struct NamePromptSession: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let initialValue: String
    let actionTitle: String
    let submit: (String) async -> Void
}

private struct ConnectionSidebarView: View {
    let profiles: [ConnectionProfile]
    @Binding var selectedProfileID: UUID?
    let onAddProfile: () -> Void
    let onEditProfile: () -> Void
    let onDeleteProfile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedProfileID) {
                ForEach(profiles) { profile in
                    ConnectionSidebarRow(profile: profile)
                        .tag(profile.id)
                }
            }
            .overlay {
                if profiles.isEmpty {
                    ContentUnavailableView(
                        "No Connections",
                        systemImage: "externaldrive",
                        description: Text("Add an S3 or S3-compatible connection to begin browsing.")
                    )
                    .accessibilityIdentifier(A11y.Sidebar.empty)
                }
            }

            Divider()

            HStack {
                IconToolbarButton(
                    title: "Add",
                    systemImage: "plus",
                    identifier: A11y.Sidebar.add,
                    action: onAddProfile
                )
                IconToolbarButton(
                    title: "Edit",
                    systemImage: "pencil",
                    identifier: A11y.Sidebar.edit,
                    action: onEditProfile
                )
                .disabled(selectedProfileID == nil)
                IconToolbarButton(
                    title: "Delete",
                    systemImage: "trash",
                    identifier: A11y.Sidebar.delete,
                    action: onDeleteProfile
                )
                .disabled(selectedProfileID == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
    }
}

private struct ConnectionSidebarRow: View {
    let profile: ConnectionProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.headline)
            Text("\(profile.bucket) / \(profile.region)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier(A11y.Sidebar.row(profile.name))
        .padding(.vertical, 4)
    }
}

private struct BrowserColumnView: View {
    @Bindable var browser: S3BrowserModel

    let profile: ConnectionProfile?
    let onUpload: () -> Void
    let onDownload: () -> Void
    let onCreateFolder: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if let profile {
            VStack(spacing: 0) {
                BrowserActionBar(
                    browser: browser,
                    onRefresh: {
                        Task {
                            await browser.refresh(using: profile)
                        }
                    },
                    onOpen: {
                        Task {
                            await browser.openSelectedFolder(using: profile)
                        }
                    },
                    onUp: {
                        Task {
                            await browser.navigateUp(using: profile)
                        }
                    },
                    onUpload: onUpload,
                    onDownload: onDownload,
                    onCreateFolder: onCreateFolder,
                    onRename: onRename,
                    onDelete: onDelete
                )

                Divider()

                Group {
                    if browser.isLoading && browser.items.isEmpty {
                        ProgressView("Loading objects...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if browser.sortedItems.isEmpty {
                        if browser.isFilterActive {
                            ContentUnavailableView(
                                "No Matches",
                                systemImage: "magnifyingglass",
                                description: Text("No items match \"\(browser.filterText)\" in this location.")
                            )
                            .accessibilityIdentifier(A11y.Browser.emptyMatches)
                        } else {
                            ContentUnavailableView(
                                "No Objects",
                                systemImage: "tray",
                                description: Text("Upload files or create folders in the current location.")
                            )
                            .accessibilityIdentifier(A11y.Browser.emptyObjects)
                        }
                    } else {
                        BrowserTableView(browser: browser, profile: profile)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !browser.transfers.isEmpty {
                    Divider()
                    TransferListView(transfers: browser.transfers)
                }
            }
        } else {
            ContentUnavailableView(
                "Select a Connection",
                systemImage: "externaldrive.badge.icloud",
                description: Text("Choose a saved connection profile to browse an S3 bucket.")
            )
            .accessibilityIdentifier(A11y.Browser.noConnection)
        }
    }
}

private struct BrowserActionBar: View {
    @Bindable var browser: S3BrowserModel

    let onRefresh: () -> Void
    let onOpen: () -> Void
    let onUp: () -> Void
    let onUpload: () -> Void
    let onDownload: () -> Void
    let onCreateFolder: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    private var selectedItem: S3BrowserItem? {
        browser.selectedItem
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(browser.currentLocationTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .accessibilityIdentifier(A11y.Browser.locationTitle)

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    IconToolbarButton(
                        title: "Refresh",
                        systemImage: "arrow.clockwise",
                        identifier: A11y.Browser.refresh,
                        action: onRefresh
                    )
                    IconToolbarButton(
                        title: "Open",
                        systemImage: "arrow.right.circle",
                        identifier: A11y.Browser.open,
                        action: onOpen
                    )
                    .disabled(selectedItem?.kind != .folder)
                    IconToolbarButton(
                        title: "Up",
                        systemImage: "arrow.up",
                        identifier: A11y.Browser.up,
                        action: onUp
                    )
                    .disabled(!browser.canNavigateUp)
                    Divider().frame(height: 20)
                    IconToolbarButton(
                        title: "Upload",
                        systemImage: "square.and.arrow.up",
                        identifier: A11y.Browser.upload,
                        action: onUpload
                    )
                    IconToolbarButton(
                        title: "Download",
                        systemImage: "square.and.arrow.down",
                        identifier: A11y.Browser.download,
                        action: onDownload
                    )
                    .disabled(selectedItem?.kind != .object)
                    IconToolbarButton(
                        title: "New Folder",
                        systemImage: "folder.badge.plus",
                        identifier: A11y.Browser.newFolder,
                        action: onCreateFolder
                    )
                    IconToolbarButton(
                        title: "Rename",
                        systemImage: "pencil",
                        identifier: A11y.Browser.rename,
                        action: onRename
                    )
                    .disabled(selectedItem == nil)
                    IconToolbarButton(
                        title: "Delete",
                        systemImage: "trash",
                        identifier: A11y.Browser.delete,
                        action: onDelete
                    )
                    .disabled(selectedItem == nil)
                }
                .fixedSize()
                Spacer(minLength: 8)
                FilterField(text: $browser.filterText)
                Picker("Sort", selection: $browser.sortMode) {
                    ForEach(S3BrowserSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
                .accessibilityIdentifier(A11y.Browser.sortPicker)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct BrowserTableView: View {
    @Bindable var browser: S3BrowserModel
    let profile: ConnectionProfile

    var body: some View {
        Table(browser.sortedItems, selection: selectionBinding) {
            TableColumn("Name") { item in
                Label(item.name, systemImage: item.kind.systemImageName)
                    .accessibilityIdentifier(A11y.Browser.row(item.key))
            }
            TableColumn("Kind") { item in
                Text(item.kind.label)
                    .foregroundStyle(.secondary)
            }
            TableColumn("Size") { item in
                Text(item.size.map(ItemFormatter.size) ?? "-")
                    .monospacedDigit()
            }
            TableColumn("Modified") { item in
                Text(item.modifiedAt.map(ItemFormatter.date) ?? "-")
            }
        }
        .accessibilityIdentifier(A11y.Browser.table)
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: S3BrowserItem.ID.self) { _ in
        } primaryAction: { selection in
            activatePrimaryAction(for: selection)
        }
    }

    private func activatePrimaryAction(for selection: Set<S3BrowserItem.ID>) {
        guard
            let key = selection.first,
            let item = browser.items.first(where: { $0.key == key }),
            item.kind == .folder
        else {
            return
        }
        Task {
            await browser.openFolder(withKey: key, using: profile)
        }
    }

    private var selectionBinding: Binding<String?> {
        Binding(
            get: { browser.selectedItemKey },
            set: { newValue in
                Task {
                    await browser.selectItem(withKey: newValue, using: profile)
                }
            }
        )
    }
}

private struct PreviewColumnView: View {
    let browser: S3BrowserModel

    var body: some View {
        switch browser.previewState {
        case let .empty(message):
            ContentUnavailableView(
                "No Preview",
                systemImage: "eye.slash",
                description: Text(message)
            )
            .accessibilityIdentifier(A11y.Preview.empty)
        case .loading:
            VStack {
                Spacer()
                ProgressView("Loading preview...")
                Spacer()
            }
            .accessibilityIdentifier(A11y.Preview.loading)
        case let .failed(message):
            ContentUnavailableView(
                "Preview Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .accessibilityIdentifier(A11y.Preview.failed)
        case let .ready(preview):
            PreviewContentView(preview: preview)
        }
    }
}

private struct PreviewContentView: View {
    let preview: BrowserPreviewContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                previewHeader
                switch preview.kind {
                case .inlineText:
                    Text(preview.text ?? "")
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier(A11y.Preview.inlineText)
                case .quickLook:
                    QuickLookPreviewView(url: preview.localURL)
                        .frame(minHeight: 420)
                        .accessibilityIdentifier(A11y.Preview.quickLook)
                case .unsupported:
                    Text("Preview is not available for this file type.")
                }
            }
            .padding(20)
        }
    }

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preview.item.name)
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier(A11y.Preview.name)
            Text(preview.item.key)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .accessibilityIdentifier(A11y.Preview.key)
            HStack {
                Text(preview.item.kind.label)
                if let size = preview.item.size {
                    Text(ItemFormatter.size(size))
                }
                if let modifiedAt = preview.item.modifiedAt {
                    Text(ItemFormatter.date(modifiedAt))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

private struct FilterField: View {
    @Binding var text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filter", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .frame(minWidth: 120, maxWidth: 180)
                .accessibilityIdentifier(A11y.Browser.filterField)
            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear filter")
                .accessibilityIdentifier(A11y.Browser.filterClear)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct IconToolbarButton: View {
    let title: String
    let systemImage: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .help(title)
            .accessibilityIdentifier(identifier)
    }
}

private struct TransferListView: View {
    let transfers: [TransferActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfers")
                .font(.headline)
            ForEach(transfers) { transfer in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transfer.name)
                        Spacer()
                        Text(transfer.kind.rawValue.capitalized)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: transfer.progress)
                    Text(transfer.message ?? transfer.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(transfer.status == .failed ? .red : .secondary)
                        .accessibilityIdentifier(A11y.Transfers.status(transfer.name))
                }
            }
        }
        .padding(16)
    }
}
