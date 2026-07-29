import Foundation

@MainActor
final class UnreadAggregator {
    private var counts: [UUID: Int] = [:]

    func setUnread(tabId: UUID, count: Int) {
        counts[tabId] = max(0, count)
    }

    func remove(tabId: UUID) {
        counts.removeValue(forKey: tabId)
    }

    var total: Int {
        counts.values.reduce(0, +)
    }

    func applyDockBadge() {
        NotificationService.shared.updateDockBadge(count: total)
    }
}
