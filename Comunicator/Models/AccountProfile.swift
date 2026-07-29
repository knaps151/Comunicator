import Foundation

struct AccountProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var serviceId: String
    var displayName: String
    var customURLString: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        serviceId: String,
        displayName: String,
        customURLString: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.serviceId = serviceId
        self.displayName = displayName
        self.customURLString = customURLString
        self.createdAt = createdAt
    }

    var dataStoreDirectoryName: String {
        "profile-\(id.uuidString)"
    }

    func resolvedURL(using services: [ServiceDefinition]) -> URL? {
        if let custom = customURLString, let url = URL(string: custom), !custom.isEmpty {
            return url
        }
        return services.first(where: { $0.id == serviceId })?.defaultURL
    }
}
