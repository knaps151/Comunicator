import AppKit
import Foundation
import Observation
import SwiftUI

enum PendingConfirmation: Identifiable, Equatable {
    case clearSession(profileId: UUID, name: String)
    case deleteAccount(profileId: UUID, name: String)

    var id: String {
        switch self {
        case .clearSession(let id, _): return "clear-\(id)"
        case .deleteAccount(let id, _): return "delete-\(id)"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    let services: [ServiceDefinition]
    private let store = ProfileStore()
    private let unreadAggregator = UnreadAggregator()

    var profiles: [AccountProfile] = []
    var tabs: [TabSession] = []
    var activeTabId: UUID?
    var controllers: [UUID: WebViewController] = [:]

    var showingAddAccount = false
    var addAccountServiceId: String?
    var showingCustomURL = false
    var pendingConfirmation: PendingConfirmation?
    var renamingProfileId: UUID?

    /// Soft guidance when many live WebViews are open (F7).
    private let openTabWarningThreshold = 8

    private var persistTask: Task<Void, Never>?

    init() {
        self.services = ServiceDefinition.loadPresets()
        restore()
        NotificationService.shared.requestPermissionIfNeeded()
        NotificationService.shared.onNotificationOpen = { [weak self] tabId in
            self?.activateTab(tabId)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var openTabs: [TabSession] {
        tabs.filter(\.isOpen)
    }

    var activeTab: TabSession? {
        guard let activeTabId else { return openTabs.first }
        return tabs.first(where: { $0.id == activeTabId && $0.isOpen })
    }

    var activeController: WebViewController? {
        guard let id = activeTab?.id else { return nil }
        return controllers[id]
    }

    var tooManyOpenTabs: Bool {
        openTabs.count >= openTabWarningThreshold
    }

    func profile(for id: UUID) -> AccountProfile? {
        profiles.first(where: { $0.id == id })
    }

    func service(for profile: AccountProfile) -> ServiceDefinition? {
        services.first(where: { $0.id == profile.serviceId })
    }

    func profiles(forService serviceId: String) -> [AccountProfile] {
        profiles.filter { $0.serviceId == serviceId }
    }

    /// Tab chips use the stable account name; raw page titles stay for notifications.
    func displayTitle(for tab: TabSession) -> String {
        if let profile = profile(for: tab.profileId) {
            return profile.displayName
        }
        return "Tab"
    }

    // MARK: - Profiles / tabs

    func openOrCreateDefaultAccount(serviceId: String) {
        if serviceId == "custom" {
            showingCustomURL = true
            return
        }
        let existing = profiles(forService: serviceId)
        if let first = existing.first {
            openTab(for: first)
            return
        }
        guard let service = services.first(where: { $0.id == serviceId }) else { return }
        let profile = AccountProfile(serviceId: serviceId, displayName: service.name)
        profiles.append(profile)
        schedulePersist(immediate: true)
        openTab(for: profile)
    }

    func beginAddAccount(serviceId: String) {
        addAccountServiceId = serviceId
        showingAddAccount = true
    }

    func addAccount(serviceId: String, displayName: String, customURL: String?) {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var urlString = customURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = urlString, !raw.isEmpty, !raw.contains("://") {
            urlString = "https://\(raw)"
        }
        let profile = AccountProfile(
            serviceId: serviceId,
            displayName: name,
            customURLString: (urlString?.isEmpty == false) ? urlString : nil
        )
        profiles.append(profile)
        schedulePersist(immediate: true)
        openTab(for: profile)
    }

    func addCustomURL(displayName: String, urlString: String) {
        addAccount(serviceId: "custom", displayName: displayName, customURL: urlString)
    }

    func beginRename(profileId: UUID) {
        guard profiles.contains(where: { $0.id == profileId }) else { return }
        renamingProfileId = profileId
    }

    func beginRename(tabId: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabId }) else { return }
        beginRename(profileId: tab.profileId)
    }

    func renameProfile(_ profileId: UUID, displayName: String) {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let idx = profiles.firstIndex(where: { $0.id == profileId }) else { return }
        profiles[idx].displayName = name
        renamingProfileId = nil
        schedulePersist(immediate: true)
    }

    func openTab(for profile: AccountProfile) {
        if let existing = tabs.first(where: { $0.profileId == profile.id && $0.isOpen }) {
            activateTab(existing.id)
            return
        }

        if let closedIndex = tabs.firstIndex(where: { $0.profileId == profile.id && !$0.isOpen }) {
            tabs[closedIndex].isOpen = true
            tabs[closedIndex].unreadCount = 0
            ensureController(for: tabs[closedIndex], profile: profile)
            activateTab(tabs[closedIndex].id)
            schedulePersist(immediate: true)
            return
        }

        let tab = TabSession(profileId: profile.id)
        tabs.append(tab)
        ensureController(for: tab, profile: profile)
        activateTab(tab.id)
        schedulePersist(immediate: true)
    }

    func activateTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id && $0.isOpen }) else { return }
        activeTabId = id
        if let idx = tabs.firstIndex(where: { $0.id == id }) {
            tabs[idx].unreadCount = 0
            unreadAggregator.setUnread(tabId: id, count: 0)
            unreadAggregator.applyDockBadge()
            NotificationService.shared.clearNotification(for: id)
        }
        schedulePersist(immediate: true)
    }

    func closeTab(_ id: UUID) {
        controllers[id]?.teardown()
        controllers[id] = nil
        unreadAggregator.remove(tabId: id)
        unreadAggregator.applyDockBadge()
        NotificationService.shared.clearNotification(for: id)

        tabs.removeAll { $0.id == id }

        if activeTabId == id {
            activeTabId = openTabs.first?.id
        }
        schedulePersist(immediate: true)
    }

    func reloadActiveTab() {
        activeController?.reload()
    }

    /// Selects an open tab by 0-based index (used for ⌘1…⌘9).
    func selectTab(at index: Int) {
        let open = openTabs
        guard index >= 0, index < open.count else { return }
        activateTab(open[index].id)
    }

    func toggleMute(tabId: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].notificationsMuted.toggle()
        if tabs[idx].notificationsMuted {
            NotificationService.shared.clearNotification(for: tabId)
            unreadAggregator.setUnread(tabId: tabId, count: 0)
            unreadAggregator.applyDockBadge()
        }
        schedulePersist(immediate: true)
    }

    func requestClearSession(for profileId: UUID) {
        let name = profile(for: profileId)?.displayName ?? "this account"
        pendingConfirmation = .clearSession(profileId: profileId, name: name)
    }

    func requestDeleteAccount(for profileId: UUID) {
        let name = profile(for: profileId)?.displayName ?? "this account"
        pendingConfirmation = .deleteAccount(profileId: profileId, name: name)
    }

    func confirmPendingAction() {
        guard let pending = pendingConfirmation else { return }
        pendingConfirmation = nil
        switch pending {
        case .clearSession(let profileId, _):
            clearSession(for: profileId)
        case .deleteAccount(let profileId, _):
            deleteProfile(profileId)
        }
    }

    func cancelPendingAction() {
        pendingConfirmation = nil
    }

    func clearSession(for profileId: UUID) {
        guard profile(for: profileId) != nil else { return }
        let relatedTabs = tabs.filter { $0.profileId == profileId }

        let finishReload: () -> Void = { [weak self] in
            guard let self else { return }
            guard let p = self.profile(for: profileId),
                  let url = p.resolvedURL(using: self.services) else { return }
            for tab in self.tabs where tab.profileId == profileId && tab.isOpen {
                self.controllers[tab.id]?.load(url: url)
            }
        }

        if let openTab = relatedTabs.first(where: { $0.isOpen }),
           let controller = controllers[openTab.id] {
            controller.clearWebsiteData {
                Task { @MainActor in
                    // Also clear via store API in case other closed-associated data remains.
                    self.store.clearWebsiteData(for: profileId) {
                        Task { @MainActor in finishReload() }
                    }
                }
            }
        } else {
            store.clearWebsiteData(for: profileId) {
                Task { @MainActor in finishReload() }
            }
        }
    }

    func deleteProfile(_ profileId: UUID) {
        let related = tabs.filter { $0.profileId == profileId }
        for tab in related {
            controllers[tab.id]?.teardown()
            controllers[tab.id] = nil
            unreadAggregator.remove(tabId: tab.id)
            NotificationService.shared.clearNotification(for: tab.id)
        }
        tabs.removeAll { $0.profileId == profileId }
        profiles.removeAll { $0.id == profileId }
        if activeTabId == nil || !openTabs.contains(where: { $0.id == activeTabId }) {
            activeTabId = openTabs.first?.id
        }
        unreadAggregator.applyDockBadge()
        store.removeDataStore(for: profileId)
        schedulePersist(immediate: true)
    }

    // MARK: - Private

    private func ensureController(for tab: TabSession, profile: AccountProfile) {
        if controllers[tab.id] != nil { return }
        let service = service(for: profile)
        let controller = WebViewController(tabId: tab.id, profile: profile, service: service)
        controller.delegate = self
        controllers[tab.id] = controller
        if let url = profile.resolvedURL(using: services) {
            controller.load(url: url)
        }
    }

    private func restore() {
        guard let snapshot = store.load() else { return }
        profiles = snapshot.profiles
        // Drop closed tabs from older builds that soft-closed them.
        tabs = snapshot.tabs.filter(\.isOpen)
        activeTabId = snapshot.activeTabId

        for tab in openTabs {
            guard let profile = profile(for: tab.profileId) else { continue }
            ensureController(for: tab, profile: profile)
            unreadAggregator.setUnread(tabId: tab.id, count: tab.notificationsMuted ? 0 : tab.unreadCount)
        }
        unreadAggregator.applyDockBadge()

        if activeTabId == nil || !(openTabs.contains(where: { $0.id == activeTabId })) {
            activeTabId = openTabs.first?.id
        }
    }

    private func schedulePersist(immediate: Bool = false) {
        persistTask?.cancel()
        if immediate {
            persistNow()
            return
        }
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            persistNow()
        }
    }

    private func persistNow() {
        let snapshot = AppStateSnapshot(
            profiles: profiles,
            tabs: tabs.filter(\.isOpen),
            activeTabId: activeTabId
        )
        store.save(snapshot)
    }
}

extension AppModel: WebViewControllerDelegate {
    func webViewController(_ controller: WebViewController, didUpdateTitle title: String?) {
        guard let idx = tabs.firstIndex(where: { $0.id == controller.tabId }) else { return }
        if tabs[idx].pageTitle == title { return }
        tabs[idx].pageTitle = title
        schedulePersist(immediate: false)
    }

    func webViewController(_ controller: WebViewController, didReportUnread count: Int, title: String?) {
        guard let idx = tabs.firstIndex(where: { $0.id == controller.tabId }) else { return }
        let previous = tabs[idx].unreadCount
        tabs[idx].unreadCount = count
        if let title, tabs[idx].pageTitle != title {
            tabs[idx].pageTitle = title
            schedulePersist(immediate: false)
        }

        let isActive = activeTabId == controller.tabId && NSApp.isActive
        let muted = tabs[idx].notificationsMuted
        let badgeCount = muted ? 0 : (isActive ? 0 : count)
        unreadAggregator.setUnread(tabId: controller.tabId, count: badgeCount)
        unreadAggregator.applyDockBadge()

        // Keep unread in memory only; persist is debounced from title changes / user actions.
        guard !muted, !isActive else {
            if isActive {
                NotificationService.shared.clearNotification(for: controller.tabId)
            }
            return
        }

        // Better notifications: alert on rising unread (0→N or increase), coalesced + throttled.
        let shouldNotify = count > 0 && count >= previous && (previous == 0 || count > previous)
        guard shouldNotify else { return }

        let profileName = profile(for: tabs[idx].profileId)?.displayName ?? "Comunicator"
        let page = tabs[idx].pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String
        if count == 1 {
            body = page.flatMap { $0.isEmpty ? nil : $0 } ?? "1 unread message"
        } else {
            let base = "\(count) unread messages"
            if let page, !page.isEmpty, page != profileName {
                body = "\(base) — \(page)"
            } else {
                body = base
            }
        }

        NotificationService.shared.postOrReplaceMessageNotification(
            tabId: controller.tabId,
            title: profileName,
            body: body,
            unreadCount: unreadAggregator.total
        )
    }
}
