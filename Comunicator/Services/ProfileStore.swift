import Foundation
import WebKit

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

    var supportDirectory: URL {
        fileURL.deletingLastPathComponent()
    }

    func load() -> AppStateSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppStateSnapshot.self, from: data)
        } catch {
            print("ProfileStore load error: \(error)")
            return nil
        }
    }

    func save(_ snapshot: AppStateSnapshot) {
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("ProfileStore save error: \(error)")
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
        WKWebsiteDataStore.remove(forIdentifier: profileId) { _ in
            DispatchQueue.main.async { completion?() }
        }
    }
}
