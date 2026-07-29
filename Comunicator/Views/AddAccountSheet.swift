import SwiftUI

enum AddAccountMode {
    case namedAccount(serviceId: String)
    case customURL
}

struct AddAccountSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let mode: AddAccountMode

    @State private var displayName = ""
    @State private var urlString = ""

    private var service: ServiceDefinition? {
        switch mode {
        case .namedAccount(let serviceId):
            return model.services.first(where: { $0.id == serviceId })
        case .customURL:
            return model.services.first(where: { $0.isCustom })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))

            TextField("Account name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            if showsURLField {
                TextField("https://…", text: $urlString)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            if displayName.isEmpty, let service, case .namedAccount = mode {
                let count = model.profiles(forService: service.id).count
                displayName = count == 0 ? service.name : "\(service.name) \(count + 1)"
            }
        }
    }

    private var title: String {
        switch mode {
        case .namedAccount:
            return "Add \(service?.name ?? "Account")"
        case .customURL:
            return "Add Custom URL"
        }
    }

    private var showsURLField: Bool {
        switch mode {
        case .namedAccount: return false
        case .customURL: return true
        }
    }

    private var canSubmit: Bool {
        let nameOK = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch mode {
        case .namedAccount:
            return nameOK
        case .customURL:
            return nameOK && !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func submit() {
        switch mode {
        case .namedAccount(let serviceId):
            model.addAccount(serviceId: serviceId, displayName: displayName, customURL: nil)
        case .customURL:
            model.addCustomURL(displayName: displayName, urlString: urlString)
        }
        dismiss()
    }
}
