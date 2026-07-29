import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            VStack(spacing: 0) {
                if model.tooManyOpenTabs {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Many tabs are open — each keeps a live browser session in memory.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                }

                if !model.openTabs.isEmpty {
                    TabBarView()
                    Divider()
                }
                WebHostView()
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        model.reloadActiveTab()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.activeTab == nil)
                    .help("Reload")

                    if let tab = model.activeTab {
                        Button {
                            model.toggleMute(tabId: tab.id)
                        } label: {
                            Label(
                                tab.notificationsMuted ? "Unmute" : "Mute",
                                systemImage: tab.notificationsMuted ? "bell.slash" : "bell"
                            )
                        }
                        .help(tab.notificationsMuted ? "Unmute notifications" : "Mute notifications")
                    }
                }
            }
        }
        .sheet(isPresented: $model.showingAddAccount) {
            AddAccountSheet(mode: .namedAccount(serviceId: model.addAccountServiceId ?? "whatsapp"))
        }
        .sheet(isPresented: $model.showingCustomURL) {
            AddAccountSheet(mode: .customURL)
        }
        .sheet(isPresented: Binding(
            get: { model.renamingProfileId != nil },
            set: { if !$0 { model.renamingProfileId = nil } }
        )) {
            if let profileId = model.renamingProfileId {
                RenameAccountSheet(profileId: profileId)
            }
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { model.pendingConfirmation != nil },
                set: { if !$0 { model.cancelPendingAction() } }
            ),
            titleVisibility: .visible
        ) {
            switch model.pendingConfirmation {
            case .clearSession:
                Button("Clear Session", role: .destructive) {
                    model.confirmPendingAction()
                }
            case .deleteAccount:
                Button("Delete Account", role: .destructive) {
                    model.confirmPendingAction()
                }
            case .none:
                EmptyView()
            }
            Button("Cancel", role: .cancel) {
                model.cancelPendingAction()
            }
        } message: {
            Text(confirmationMessage)
        }
    }

    private var confirmationTitle: String {
        switch model.pendingConfirmation {
        case .clearSession(_, let name):
            return "Clear session for \(name)?"
        case .deleteAccount(_, let name):
            return "Delete \(name)?"
        case .none:
            return "Confirm"
        }
    }

    private var confirmationMessage: String {
        switch model.pendingConfirmation {
        case .clearSession:
            return "This signs you out of this account in Comunicator by wiping cookies and site data."
        case .deleteAccount:
            return "Removes the account, its open tab, and stored login data. This cannot be undone."
        case .none:
            return ""
        }
    }
}

struct WebHostView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let tab = model.activeTab, let controller = model.controllers[tab.id] {
            WebViewRepresentable(controller: controller)
                .id(tab.id)
                .help(tab.pageTitle ?? model.displayTitle(for: tab))
        } else {
            ContentUnavailableView {
                Label("Comunicator", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Pick a service from the sidebar to open a tab.")
            }
        }
    }
}
