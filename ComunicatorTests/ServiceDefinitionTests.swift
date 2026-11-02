import XCTest
@testable import Comunicator

final class ServiceDefinitionTests: XCTestCase {

    func testDefaultUserAgentIsSafari() {
        let service = ServiceDefinition(
            id: "test",
            name: "Test",
            url: "https://test.com",
            symbolName: "globe"
        )

        XCTAssertEqual(service.preferredUserAgent, UserAgents.safariMac)
    }

    func testChromeUserAgentOverride() {
        let service = ServiceDefinition(
            id: "whatsapp",
            name: "WhatsApp",
            url: "https://web.whatsapp.com",
            symbolName: "phone.fill",
            userAgent: "chrome"
        )

        XCTAssertEqual(service.preferredUserAgent, UserAgents.chromeMac)
    }

    func testCustomUserAgentString() {
        let customUA = "Mozilla/5.0 Custom Agent"
        let service = ServiceDefinition(
            id: "custom",
            name: "Custom",
            url: "https://custom.com",
            symbolName: "globe",
            userAgent: customUA
        )

        XCTAssertEqual(service.preferredUserAgent, customUA)
    }

    func testAllowedHostsSet() {
        let service = ServiceDefinition(
            id: "slack",
            name: "Slack",
            url: "https://app.slack.com",
            symbolName: "number",
            allowedHosts: ["slack.com", "slack-edge.com", "accounts.google.com"]
        )

        XCTAssertEqual(service.allowedHostsSet.count, 3)
        XCTAssertTrue(service.allowedHostsSet.contains("slack.com"))
        XCTAssertTrue(service.allowedHostsSet.contains("accounts.google.com"))
    }

    func testAllowedHostsSetEmptyWhenNil() {
        let service = ServiceDefinition(
            id: "custom",
            name: "Custom",
            url: "",
            symbolName: "globe"
        )

        XCTAssertTrue(service.allowedHostsSet.isEmpty)
    }

    func testIsCustom() {
        let customService = ServiceDefinition(
            id: "custom",
            name: "Custom",
            url: "",
            symbolName: "globe"
        )
        let regularService = ServiceDefinition(
            id: "whatsapp",
            name: "WhatsApp",
            url: "https://web.whatsapp.com",
            symbolName: "phone.fill"
        )

        XCTAssertTrue(customService.isCustom)
        XCTAssertFalse(regularService.isCustom)
    }

    func testDefaultURL() {
        let service = ServiceDefinition(
            id: "whatsapp",
            name: "WhatsApp",
            url: "https://web.whatsapp.com",
            symbolName: "phone.fill"
        )

        XCTAssertEqual(service.defaultURL?.absoluteString, "https://web.whatsapp.com")
    }

    func testDefaultURLNilForEmpty() {
        let service = ServiceDefinition(
            id: "custom",
            name: "Custom",
            url: "",
            symbolName: "globe"
        )

        XCTAssertNil(service.defaultURL)
    }

    func testServiceDefinitionCodable() throws {
        let service = ServiceDefinition(
            id: "test",
            name: "Test Service",
            url: "https://test.com",
            symbolName: "star",
            userAgent: "chrome",
            allowedHosts: ["test.com", "auth.test.com"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(service)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ServiceDefinition.self, from: data)

        XCTAssertEqual(decoded.id, service.id)
        XCTAssertEqual(decoded.name, service.name)
        XCTAssertEqual(decoded.url, service.url)
        XCTAssertEqual(decoded.symbolName, service.symbolName)
        XCTAssertEqual(decoded.userAgent, service.userAgent)
        XCTAssertEqual(decoded.allowedHosts, service.allowedHosts)
    }

    func testFallbackPresetsExist() {
        let presets = ServiceDefinition.fallbackPresets

        XCTAssertFalse(presets.isEmpty)
        XCTAssertTrue(presets.contains(where: { $0.id == "whatsapp" }))
        XCTAssertTrue(presets.contains(where: { $0.id == "custom" }))
    }
}
