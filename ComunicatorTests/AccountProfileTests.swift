import XCTest
@testable import Comunicator

final class AccountProfileTests: XCTestCase {

    private let testServices: [ServiceDefinition] = [
        ServiceDefinition(
            id: "whatsapp",
            name: "WhatsApp",
            url: "https://web.whatsapp.com",
            symbolName: "phone.fill"
        ),
        ServiceDefinition(
            id: "custom",
            name: "Custom",
            url: "",
            symbolName: "globe"
        ),
    ]

    func testResolvedURLUsesServiceDefault() {
        let profile = AccountProfile(
            serviceId: "whatsapp",
            displayName: "WhatsApp"
        )

        let url = profile.resolvedURL(using: testServices)

        XCTAssertEqual(url?.absoluteString, "https://web.whatsapp.com")
    }

    func testResolvedURLUsesCustomURLWhenProvided() {
        let profile = AccountProfile(
            serviceId: "whatsapp",
            displayName: "Work WhatsApp",
            customURLString: "https://web.whatsapp.com/work"
        )

        let url = profile.resolvedURL(using: testServices)

        XCTAssertEqual(url?.absoluteString, "https://web.whatsapp.com/work")
    }

    func testResolvedURLReturnsNilForCustomWithoutURL() {
        let profile = AccountProfile(
            serviceId: "custom",
            displayName: "Custom Site"
        )

        let url = profile.resolvedURL(using: testServices)

        XCTAssertNil(url)
    }

    func testResolvedURLReturnsCustomURLForCustomService() {
        let profile = AccountProfile(
            serviceId: "custom",
            displayName: "My Site",
            customURLString: "https://example.com"
        )

        let url = profile.resolvedURL(using: testServices)

        XCTAssertEqual(url?.absoluteString, "https://example.com")
    }

    func testResolvedURLReturnsNilForUnknownService() {
        let profile = AccountProfile(
            serviceId: "unknown",
            displayName: "Unknown"
        )

        let url = profile.resolvedURL(using: testServices)

        XCTAssertNil(url)
    }

    func testProfileEquality() {
        let id = UUID()
        let date = Date()
        let profile1 = AccountProfile(
            id: id,
            serviceId: "whatsapp",
            displayName: "WhatsApp",
            createdAt: date
        )
        let profile2 = AccountProfile(
            id: id,
            serviceId: "whatsapp",
            displayName: "WhatsApp",
            createdAt: date
        )

        XCTAssertEqual(profile1, profile2)
    }

    func testProfileCodable() throws {
        let profile = AccountProfile(
            serviceId: "whatsapp",
            displayName: "Test Account",
            customURLString: "https://custom.url"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AccountProfile.self, from: data)

        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.serviceId, profile.serviceId)
        XCTAssertEqual(decoded.displayName, profile.displayName)
        XCTAssertEqual(decoded.customURLString, profile.customURLString)
    }
}
