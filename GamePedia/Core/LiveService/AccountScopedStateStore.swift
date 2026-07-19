import CryptoKit
import Foundation

// MARK: - Account-scoped state store
//
// Generic durable persistence for small account-scoped live-service state
// (activity read state, last-known activity snapshots). Follows the
// storage contract proven by `FileSyncOperationStore` in 2.2:
//
// - one JSON file per (schema version, account) under Application Support;
// - the schema version is part of the file name, so an app rollback can
//   never mis-parse a newer schema's data;
// - the account component of the file name is SHA-256-hashed, so file
//   names never expose account IDs;
// - an unreadable file is quarantined (`.corrupt` suffix, preserved for
//   diagnosis) and the caller restarts empty — corrupted local state
//   degrades safely instead of crashing;
// - `purge(accountID:)` removes every schema version plus quarantined
//   copies, for account-deletion cleanup.
//
// Payloads must contain no credentials, tokens, or Authorization values.

struct AccountScopedStateLoadResult<Payload> {
    let payload: Payload?
    let recoveredFromCorruption: Bool
}

actor AccountScopedStateStore<Payload: Codable & Sendable> {

    struct Envelope: Codable {
        let schemaVersion: Int
        let payload: Payload
    }

    private let directoryURL: URL
    private let filePrefix: String
    private let schemaVersion: Int
    /// Older schema versions this store may need to purge. Extend when the
    /// schema version is bumped so account deletion keeps removing old files.
    private let retiredSchemaVersions: [Int]
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        filePrefix: String,
        schemaVersion: Int = 1,
        retiredSchemaVersions: [Int] = [],
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.filePrefix = filePrefix
        self.schemaVersion = schemaVersion
        self.retiredSchemaVersions = retiredSchemaVersions
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = base.appendingPathComponent("GamePediaLiveService", isDirectory: true)
        }
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(accountID: String) -> AccountScopedStateLoadResult<Payload> {
        let url = fileURL(accountID: accountID, schemaVersion: schemaVersion)
        guard fileManager.fileExists(atPath: url.path) else {
            return AccountScopedStateLoadResult(payload: nil, recoveredFromCorruption: false)
        }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.schemaVersion == schemaVersion else {
                quarantine(url)
                return AccountScopedStateLoadResult(payload: nil, recoveredFromCorruption: true)
            }
            return AccountScopedStateLoadResult(payload: envelope.payload, recoveredFromCorruption: false)
        } catch {
            quarantine(url)
            return AccountScopedStateLoadResult(payload: nil, recoveredFromCorruption: true)
        }
    }

    func persist(_ payload: Payload, accountID: String) {
        let url = fileURL(accountID: accountID, schemaVersion: schemaVersion)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let envelope = Envelope(schemaVersion: schemaVersion, payload: payload)
            let data = try encoder.encode(envelope)
            // File protection: readable after the first unlock (matches the
            // sync queue). Enforced by the OS on device hardware only.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // Persistence failure must never crash or drop in-memory state;
            // the state only loses restart durability until the next write.
            print("[LiveService] store persist failed code=STORE_WRITE_FAILED prefix=\(filePrefix)")
        }
    }

    func removeState(accountID: String) {
        let url = fileURL(accountID: accountID, schemaVersion: schemaVersion)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// Removes every schema version of the account's state, including
    /// quarantined copies. Used for account deletion cleanup.
    func purge(accountID: String) {
        for version in retiredSchemaVersions + [schemaVersion] {
            let url = fileURL(accountID: accountID, schemaVersion: version)
            for candidate in [url, quarantineURL(for: url)] where fileManager.fileExists(atPath: candidate.path) {
                try? fileManager.removeItem(at: candidate)
            }
        }
    }

    // MARK: Private

    private func fileURL(accountID: String, schemaVersion: Int) -> URL {
        directoryURL.appendingPathComponent(
            "\(filePrefix).v\(schemaVersion).\(Self.accountFileComponent(accountID)).json"
        )
    }

    private func quarantineURL(for url: URL) -> URL {
        url.appendingPathExtension("corrupt")
    }

    private func quarantine(_ url: URL) {
        let destination = quarantineURL(for: url)
        try? fileManager.removeItem(at: destination)
        try? fileManager.moveItem(at: url, to: destination)
        print("[LiveService] store quarantined code=STORE_CORRUPTED prefix=\(filePrefix)")
    }

    static func accountFileComponent(_ accountID: String) -> String {
        let digest = SHA256.hash(data: Data(accountID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
