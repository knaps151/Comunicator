import XCTest
@testable import Comunicator

final class UnreadParsingTests: XCTestCase {

    func testParseUnreadFromParenthesisFormat() {
        XCTAssertEqual(parseUnread("(5) WhatsApp"), 5)
        XCTAssertEqual(parseUnread("(12) Messages"), 12)
        XCTAssertEqual(parseUnread("(99+) WhatsApp"), 99)
        XCTAssertEqual(parseUnread("(1) Slack | company"), 1)
    }

    func testParseUnreadFromBulletFormat() {
        XCTAssertEqual(parseUnread("3 · Messenger"), 3)
        XCTAssertEqual(parseUnread("15 • Telegram"), 15)
        XCTAssertEqual(parseUnread("7 | Chat"), 7)
    }

    func testParseUnreadFromBracketFormat() {
        XCTAssertEqual(parseUnread("[2] Inbox"), 2)
        XCTAssertEqual(parseUnread("[100] Notifications"), 100)
    }

    func testParseUnreadReturnsZeroForNoMatch() {
        XCTAssertEqual(parseUnread("WhatsApp Web"), 0)
        XCTAssertEqual(parseUnread("Google Messages"), 0)
        XCTAssertEqual(parseUnread("No unread messages"), 0)
        XCTAssertEqual(parseUnread(""), 0)
    }

    func testParseUnreadHandlesNil() {
        XCTAssertEqual(parseUnread(nil), 0)
    }

    private func parseUnread(_ title: String?) -> Int {
        guard let title else { return 0 }

        if let match = title.firstMatch(of: /^\((\d+)\+?\)/) {
            return Int(match.1) ?? 0
        }

        if let match = title.firstMatch(of: /^(\d+)\s*[·•|]\s/) {
            return Int(match.1) ?? 0
        }

        if let match = title.firstMatch(of: /^\[(\d+)\]/) {
            return Int(match.1) ?? 0
        }

        return 0
    }
}
