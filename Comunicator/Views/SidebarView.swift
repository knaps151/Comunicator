import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section("Services") {
                ForEach(model.services.filter { !$0.isCustom }) { service in
                    ServiceRow(service: service)
                }

                Button {
                    model.showingCustomURL = true
                } label: {
                    Label("Custom URL…", systemImage: "globe")
                }
            }

            if !model.profiles.isEmpty {
                Section("Accounts") {
                    ForEach(model.profiles) { profile in
                        AccountRow(profile: profile)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Comunicator")
    }
}

private struct ServiceRow: View {
    @Environment(AppModel.self) private var model
    let service: ServiceDefinition

    var body: some View {
        HStack {
            Button {
                model.openOrCreateDefaultAccount(serviceId: service.id)
            } label: {
                Label(service.name, systemImage: service.symbolName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Open") {
                    model.openOrCreateDefaultAccount(serviceId: service.id)
                }
                Button("Add Account…") {
                    model.beginAddAccount(serviceId: service.id)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .contextMenu {
            Button("Open") {
                model.openOrCreateDefaultAccount(serviceId: service.id)
            }
            Button("Add Account…") {
                model.beginAddAccount(serviceId: service.id)
            }
        }
    }
}

private struct AccountRow: View {
    @Environment(AppModel.self) private var model
    let profile: AccountProfile

    var body: some View {
        let service = model.service(for: profile)
        Button {
            model.openTab(for: profile)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                    if let service {
                        Text(service.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: service?.symbolName ?? "person.crop.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open") {
                model.openTab(for: profile)
            }
            Button("Rename…") {
                model.beginRename(profileId: profile.id)
            }
            Button("Clear Session…") {
                model.requestClearSession(for: profile.id)
            }
            Divider()
            Button("Delete Account", role: .destructive) {
                model.requestDeleteAccount(for: profile.id)
            }
        }
    }
}
