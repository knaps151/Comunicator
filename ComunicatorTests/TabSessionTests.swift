import XCTest
@testable import Comunicator

final class TabSessionTests: XCTestCase {

    func testTabSessionDefaultValues() {
        let profileId = UUID()
        let tab = TabSession(profileId: profileId)

        XCTAssertEqual(tab.profileId, profileId)
        XCTAssertNil(tab.pageTitle)
        XCTAssertEqual(tab.unreadCount, 0)
        XCTAssertFalse(tab.notificationsMuted)
        XCTAssertTrue(tab.isOpen)
    }

    func testTabSessionWithAllValues() {
        let id = UUID()
        let profileId = UUID()
        let tab = TabSession(
            id: id,
            profileId: profileId,
            pageTitle: "Test Page",
            unreadCount: 5,
            notificationsMuted: true,
            isOpen: false
        )

        XCTAssertEqual(tab.id, id)
        XCTAssertEqual(tab.profileId, profileId)
        XCTAssertEqual(tab.pageTitle, "Test Page")
        XCTAssertEqual(tab.unreadCount, 5)
        XCTAssertTrue(tab.notificationsMuted)
        XCTAssertFalse(tab.isOpen)
    }

    func testTabSessionCodable() throws {
        let tab = TabSession(
            profileId: UUID(),
            pageTitle: "Encoded Page",
            unreadCount: 10,
            notificationsMuted: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(tab)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TabSession.self, from: data)

        XCTAssertEqual(decoded.id, tab.id)
        XCTAssertEqual(decoded.profileId, tab.profileId)
        XCTAssertEqual(decoded.pageTitle, tab.pageTitle)
        XCTAssertEqual(decoded.unreadCount, tab.unreadCount)
        XCTAssertEqual(decoded.notificationsMuted, tab.notificationsMuted)
        XCTAssertEqual(decoded.isOpen, tab.isOpen)
    }

    func testTabSessionEquality() {
        let id = UUID()
        let profileId = UUID()
        let tab1 = TabSession(id: id, profileId: profileId)
        let tab2 = TabSession(id: id, profileId: profileId)

        XCTAssertEqual(tab1, tab2)
    }
}

final class AppStateSnapshotTests: XCTestCase {

    func testAppStateSnapshotCodable() throws {
        let profile = AccountProfile(
            serviceId: "whatsapp",
            displayName: "WhatsApp"
        )
        let tab = TabSession(profileId: profile.id)
        let snapshot = AppStateSnapshot(
            profiles: [profile],
            tabs: [tab],
            activeTabId: tab.id
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AppStateSnapshot.self, from: data)

        XCTAssertEqual(decoded.profiles.count, 1)
        XCTAssertEqual(decoded.tabs.count, 1)
        XCTAssertEqual(decoded.activeTabId, tab.id)
        XCTAssertEqual(decoded.profiles.first?.id, profile.id)
    }

    func testAppStateSnapshotWithNilActiveTab() throws {
        let snapshot = AppStateSnapshot(
            profiles: [],
            tabs: [],
            activeTabId: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppStateSnapshot.self, from: data)

        XCTAssertNil(decoded.activeTabId)
        XCTAssertTrue(decoded.profiles.isEmpty)
        XCTAssertTrue(decoded.tabs.isEmpty)
    }
}
