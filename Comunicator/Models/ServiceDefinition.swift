import Foundation
import os

private let logger = Logger(subsystem: "com.comunicator.app", category: "ServiceDefinition")

enum UserAgents {
    /// Safari/WebKit UA - default for honest identification.
    static let safariMac =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"

    /// Chrome UA - use only where the service explicitly requires it.
    static let chromeMac =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
}

struct ServiceDefinition: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let url: String
    let symbolName: String
    let userAgent: String?
    let allowedHosts: [String]?

    var isCustom: Bool { id == "custom" }

    var defaultURL: URL? {
        guard !url.isEmpty else { return nil }
        return URL(string: url)
    }

    var allowedHostsSet: Set<String> {
        Set(allowedHosts ?? [])
    }

    var preferredUserAgent: String {
        if let userAgent, !userAgent.isEmpty {
            return userAgent == "chrome" ? UserAgents.chromeMac : userAgent
        }
        return UserAgents.safariMac
    }

    init(
        id: String,
        name: String,
        url: String,
        symbolName: String,
        userAgent: String? = nil,
        allowedHosts: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.symbolName = symbolName
        self.userAgent = userAgent
        self.allowedHosts = allowedHosts
    }

    static func loadPresets() -> [ServiceDefinition] {
        guard let url = Bundle.main.url(forResource: "Services", withExtension: "json") else {
            logger.warning("Services.json missing from bundle; using fallback presets")
            return Self.fallbackPresets
        }
        do {
            let data = try Data(contentsOf: url)
            let services = try JSONDecoder().decode([ServiceDefinition].self, from: data)
            guard !services.isEmpty else {
                logger.warning("Services.json decoded empty; using fallback presets")
                return Self.fallbackPresets
            }
            return services
        } catch {
            logger.error("Services.json decode failed: \(error.localizedDescription); using fallback presets")
            return Self.fallbackPresets
        }
    }

    static let fallbackPresets: [ServiceDefinition] = [
        ServiceDefinition(
            id: "whatsapp",
            name: "WhatsApp",
            url: "https://web.whatsapp.com",
            symbolName: "phone.fill",
            userAgent: "chrome",
            allowedHosts: ["whatsapp.com", "whatsapp.net"]
        ),
        ServiceDefinition(
            id: "messages",
            name: "Google Messages",
            url: "https://messages.google.com/web",
            symbolName: "message.fill",
            userAgent: "chrome",
            allowedHosts: ["google.com", "googleapis.com", "gstatic.com", "accounts.google.com"]
        ),
        ServiceDefinition(
            id: "slack",
            name: "Slack",
            url: "https://app.slack.com/client",
            symbolName: "number",
            userAgent: "chrome",
            allowedHosts: ["slack.com", "slack-edge.com", "accounts.google.com", "login.microsoftonline.com"]
        ),
        ServiceDefinition(
            id: "messenger",
            name: "Messenger",
            url: "https://www.messenger.com",
            symbolName: "bubble.left.and.bubble.right.fill",
            userAgent: "chrome",
            allowedHosts: ["messenger.com", "facebook.com", "fbcdn.net"]
        ),
        ServiceDefinition(
            id: "telegram",
            name: "Telegram",
            url: "https://web.telegram.org/k/",
            symbolName: "paperplane.fill",
            userAgent: "chrome",
            allowedHosts: ["telegram.org", "t.me"]
        ),
        ServiceDefinition(
            id: "custom",
            name: "Custom",
            url: "",
            symbolName: "globe"
        ),
    ]
}
