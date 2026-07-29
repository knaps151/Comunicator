import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    var onNotificationOpen: ((UUID) -> Void)?

    private var permissionRequested = false
    /// Last time we posted (or replaced) a banner for a given tab.
    private var lastPostedAt: [UUID: Date] = [:]
    private let minInterval: TimeInterval = 8

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Posts or replaces a per-tab notification. Returns false if throttled.
    @discardableResult
    func postOrReplaceMessageNotification(
        tabId: UUID,
        title: String,
        body: String,
        unreadCount: Int,
        force: Bool = false
    ) -> Bool {
        let now = Date()
        if !force, let last = lastPostedAt[tabId], now.timeIntervalSince(last) < minInterval {
            return false
        }
        lastPostedAt[tabId] = now

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: unreadCount)
        content.threadIdentifier = "tab-\(tabId.uuidString)"
        content.userInfo = [
            "tabId": tabId.uuidString,
            "unread": unreadCount,
        ]

        // Stable identifier per tab so new alerts replace earlier ones instead of stacking.
        let request = UNNotificationRequest(
            identifier: "comunicator-tab-\(tabId.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        return true
    }

    func clearNotification(for tabId: UUID) {
        let id = "comunicator-tab-\(tabId.uuidString)"
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        lastPostedAt.removeValue(forKey: tabId)
    }

    func updateDockBadge(count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Banner even when app is foregrounded so inactive-tab alerts stay visible.
        completionHandler([.banner, .sound, .badge, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        if let tabIdString = info["tabId"] as? String, let tabId = UUID(uuidString: tabIdString) {
            Task { @MainActor in
                self.onNotificationOpen?(tabId)
            }
        }
        completionHandler()
    }
}
