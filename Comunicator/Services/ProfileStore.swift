import Foundation
import os
import WebKit

private let logger = Logger(subsystem: "com.comunicator.app", category: "ProfileStore")

@MainActor
final class ProfileStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Comunicator", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("state.json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> AppStateSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppStateSnapshot.self, from: data)
        } catch {
            logger.error("Load error: \(error.localizedDescription)")
            return nil
        }
    }

    func save(_ snapshot: AppStateSnapshot) {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            logger.error("Save error: \(error.localizedDescription)")
        }
    }

    /// Clears cookies/storage for a profile's isolated WebKit data store.
    func clearWebsiteData(for profileId: UUID, completion: (@Sendable () -> Void)? = nil) {
        let store = WKWebsiteDataStore(forIdentifier: profileId)
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) {
                DispatchQueue.main.async { completion?() }
            }
        }
    }

    /// Fully removes the on-disk WebKit data store for this profile UUID.
    func removeDataStore(for profileId: UUID, completion: (@Sendable () -> Void)? = nil) {
        WKWebsiteDataStore.remove(forIdentifier: profileId) { error in
            if let error {
                logger.error("Failed to remove data store for profile \(profileId): \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completion?() }
        }
    }
}
