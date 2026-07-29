import Foundation

struct TabSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var profileId: UUID
    var pageTitle: String?
    var unreadCount: Int
    var notificationsMuted: Bool
    var isOpen: Bool

    init(
        id: UUID = UUID(),
        profileId: UUID,
        pageTitle: String? = nil,
        unreadCount: Int = 0,
        notificationsMuted: Bool = false,
        isOpen: Bool = true
    ) {
        self.id = id
        self.profileId = profileId
        self.pageTitle = pageTitle
        self.unreadCount = unreadCount
        self.notificationsMuted = notificationsMuted
        self.isOpen = isOpen
    }
}

struct AppStateSnapshot: Codable, Sendable {
    var profiles: [AccountProfile]
    var tabs: [TabSession]
    var activeTabId: UUID?
}
