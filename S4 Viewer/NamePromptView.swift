import SwiftUI

struct NamePromptView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var value: String
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    private let title: String
    private let message: String
    private let actionTitle: String
    private let onSubmit: (String) async -> Void

    init(
        title: String,
        message: String,
        initialValue: String,
        actionTitle: String,
        onSubmit: @escaping (String) async -> Void
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.onSubmit = onSubmit
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
            TextField("Name", text: $value)
                .focused($isFocused)
                .onSubmit {
                    submit()
                }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .disabled(isSubmitting)
                Button(actionTitle) {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSubmitting)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
        .onAppear {
            isFocused = true
        }
    }

    private func submit() {
        guard !isSubmitting else {
            return
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a name."
            return
        }

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            await onSubmit(trimmed)
            dismiss()
        }
    }
}
