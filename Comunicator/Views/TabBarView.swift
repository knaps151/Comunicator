import SwiftUI

struct TabBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(model.openTabs) { tab in
                    TabChip(tab: tab)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 36)
        .background(.bar)
    }
}

private struct TabChip: View {
    @Environment(AppModel.self) private var model
    let tab: TabSession

    private var isActive: Bool {
        model.activeTabId == tab.id
    }

    var body: some View {
        HStack(spacing: 6) {
            if tab.notificationsMuted {
                Image(systemName: "bell.slash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(model.displayTitle(for: tab))
                .lineLimit(1)
                .font(.callout)
                .help(tab.pageTitle ?? model.displayTitle(for: tab))

            if tab.unreadCount > 0 && !isActive {
                Text("\(tab.unreadCount)")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor.opacity(0.85)))
                    .foregroundStyle(.white)
            }

            Button {
                model.closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.primary.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? Color.primary.opacity(0.12) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            model.beginRename(tabId: tab.id)
        }
        .onTapGesture(count: 1) {
            model.activateTab(tab.id)
        }
        .contextMenu {
            Button("Rename…") {
                model.beginRename(tabId: tab.id)
            }
            Button(tab.notificationsMuted ? "Unmute" : "Mute") {
                model.toggleMute(tabId: tab.id)
            }
            Button("Reload") {
                model.activateTab(tab.id)
                model.reloadActiveTab()
            }
            Divider()
            Button("Close") {
                model.closeTab(tab.id)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}
