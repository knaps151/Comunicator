import SwiftUI

struct RenameAccountSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let profileId: UUID

    @State private var displayName = ""
    @FocusState private var nameFocused: Bool

    private var profile: AccountProfile? {
        model.profile(for: profileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename")
                .font(.title2.weight(.semibold))

            TextField("Name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
                .onSubmit { submit() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .onAppear {
            displayName = profile?.displayName ?? ""
            nameFocused = true
        }
    }

    private func submit() {
        model.renameProfile(profileId, displayName: displayName)
        dismiss()
    }
}
