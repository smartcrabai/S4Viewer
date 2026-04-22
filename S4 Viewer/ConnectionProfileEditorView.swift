import SwiftUI

struct ConnectionProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ConnectionProfileDraft
    @State private var validationMessage: String?
    @FocusState private var focusedField: Field?

    private let title: String
    private let actionTitle: String
    private let onSave: (ValidatedConnectionProfile) throws -> Void

    private enum Field: Hashable {
        case name
        case endpoint
        case region
        case bucket
        case accessKey
        case secretKey
    }

    init(
        title: String,
        actionTitle: String,
        draft: ConnectionProfileDraft,
        onSave: @escaping (ValidatedConnectionProfile) throws -> Void
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
            Form {
                TextField("Profile name", text: $draft.name)
                    .focused($focusedField, equals: .name)
                TextField("Endpoint URL", text: $draft.endpoint)
                    .focused($focusedField, equals: .endpoint)
                TextField("Region", text: $draft.region)
                    .focused($focusedField, equals: .region)
                TextField("Bucket", text: $draft.bucket)
                    .focused($focusedField, equals: .bucket)
                TextField("Access key", text: $draft.accessKey)
                    .focused($focusedField, equals: .accessKey)
                SecureField("Secret key", text: $draft.secretKey)
                    .focused($focusedField, equals: .secretKey)
                Toggle("Use path-style requests", isOn: $draft.usePathStyle)
            }
            .formStyle(.grouped)

            if let validationMessage {
                Text(validationMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button(actionTitle) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 360)
        .onAppear {
            focusedField = .name
        }
    }

    private func save() {
        do {
            let validated = try draft.validated()
            try onSave(validated)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
