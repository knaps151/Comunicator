import Foundation

enum UserAgents {
    /// Modern Chrome on macOS — preferred by WhatsApp Web, Google Messages, etc.
    static let chromeMac =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Safari-like WebKit UA for services that prefer native Safari identification.
    static let safariMac =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.2 Safari/605.1.15"
}

struct ServiceDefinition: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let url: String
    let symbolName: String

    var isCustom: Bool { id == "custom" }

    var defaultURL: URL? {
        guard !url.isEmpty else { return nil }
        return URL(string: url)
    }

    /// Per-service UA: Chrome for messaging PWAs that reject older Safari UAs.
    var preferredUserAgent: String {
        switch id {
        case "whatsapp", "messages", "messenger", "telegram", "slack":
            return UserAgents.chromeMac
        case "custom":
            return UserAgents.chromeMac
        default:
            return UserAgents.chromeMac
        }
    }

    static func loadPresets() -> [ServiceDefinition] {
        guard let url = Bundle.main.url(forResource: "Services", withExtension: "json") else {
            print("Services.json missing from bundle; using fallback presets")
            return Self.fallbackPresets
        }
        do {
            let data = try Data(contentsOf: url)
            let services = try JSONDecoder().decode([ServiceDefinition].self, from: data)
            guard !services.isEmpty else {
                print("Services.json decoded empty; using fallback presets")
                return Self.fallbackPresets
            }
            return services
        } catch {
            print("Services.json decode failed: \(error); using fallback presets")
            return Self.fallbackPresets
        }
    }

    static let fallbackPresets: [ServiceDefinition] = [
        ServiceDefinition(id: "whatsapp", name: "WhatsApp", url: "https://web.whatsapp.com", symbolName: "phone.fill"),
        ServiceDefinition(id: "messages", name: "Google Messages", url: "https://messages.google.com/web", symbolName: "message.fill"),
        ServiceDefinition(id: "slack", name: "Slack", url: "https://app.slack.com/client", symbolName: "number"),
        ServiceDefinition(id: "messenger", name: "Messenger", url: "https://www.messenger.com", symbolName: "bubble.left.and.bubble.right.fill"),
        ServiceDefinition(id: "telegram", name: "Telegram", url: "https://web.telegram.org/k/", symbolName: "paperplane.fill"),
        ServiceDefinition(id: "custom", name: "Custom", url: "", symbolName: "globe"),
    ]
}
