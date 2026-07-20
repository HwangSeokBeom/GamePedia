import CryptoKit
import Foundation

// MARK: - Sync operation store
//
// Durable, account-scoped persistence for the pending library-sync queue.
//
// Storage layout: one JSON file per (schema version, account) under
// Application Support. The schema version is part of the file name, so an
// app rollback can never mis-parse or destroy a newer schema's data: a
// future v2 writer uses `.v2.` files that a v1 reader never opens.
//
// Privacy contract: the account component of the file name is SHA-256-hashed,
// so the file name never exposes the account ID. The persisted queue body
// does contain the raw account UUID — it is required for account isolation
// (an operation may only ever be submitted by the exact account that created
// it). No credentials, access tokens, refresh tokens, passwords, or
// Authorization headers are ever stored in the queue. The account UUID is
// personal metadata: it must remain protected by the app sandbox and must be
// excluded from logs.
//
// Corruption policy: an unreadable file is quarantined (renamed with a
// `.corrupt` suffix, preserved for diagnosis) and the queue restarts empty —
// corrupted local state degrades safely instead of crashing or looping.

struct SyncStoreLoadResult {
    let operations: [LibrarySyncOperation]
    let recoveredFromCorruption: Bool
}

protocol SyncOperationStoring: Sendable {
    func load(accountID: String) async -> SyncStoreLoadResult
    /// Durably writes the queue, or throws. Callers must not acknowledge an
    /// enqueue (or consider a cleanup applied) unless this returns.
    func persist(_ operations: [LibrarySyncOperation], accountID: String) async throws
    /// Removes every schema version of the account's queue. Used for account
    /// deletion cleanup.
    func purge(accountID: String) async
}

actor FileSyncOperationStore: SyncOperationStoring {

    struct Envelope: Codable {
        let schemaVersion: Int
        let operations: [LibrarySyncOperation]
    }

    static let currentSchemaVersion = 1
    /// Older schema versions this store knows how to read and migrate
    /// forward. Empty at v1; future versions append loaders here so upgrade
    /// paths stay explicit and testable.
    static let migratableVersions: [Int] = []

    private let directoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = base.appendingPathComponent("GamePediaLibrarySync", isDirectory: true)
        }
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load(accountID: String) async -> SyncStoreLoadResult {
        let url = fileURL(accountID: accountID, schemaVersion: Self.currentSchemaVersion)
        guard fileManager.fileExists(atPath: url.path) else {
            return SyncStoreLoadResult(operations: [], recoveredFromCorruption: false)
        }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try decoder.decode(Envelope.self, from: data)
            guard envelope.schemaVersion == Self.currentSchemaVersion else {
                // A version-suffixed file must contain its own version; a
                // mismatch means the file was tampered with or corrupted.
                quarantine(url)
                return SyncStoreLoadResult(operations: [], recoveredFromCorruption: true)
            }
            return SyncStoreLoadResult(
                operations: envelope.operations,
                recoveredFromCorruption: false
            )
        } catch {
            quarantine(url)
            return SyncStoreLoadResult(operations: [], recoveredFromCorruption: true)
        }
    }

    func persist(_ operations: [LibrarySyncOperation], accountID: String) async throws {
        let url = fileURL(accountID: accountID, schemaVersion: Self.currentSchemaVersion)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            if operations.isEmpty {
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
                return
            }
            let envelope = Envelope(
                schemaVersion: Self.currentSchemaVersion,
                operations: operations
            )
            let data = try encoder.encode(envelope)
            // File protection: readable after the first unlock so a
            // background drain can still reach the queue. The OS enforces
            // this on device hardware only; nothing beyond the write
            // succeeding is claimed here.
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            // The caller owns the acknowledgement decision; never report a
            // write that did not happen as durable.
            print("[Sync] store persist failed code=STORE_WRITE_FAILED")
            throw error
        }
    }

    func purge(accountID: String) async {
        let versions = Self.migratableVersions + [Self.currentSchemaVersion]
        for version in versions {
            let url = fileURL(accountID: accountID, schemaVersion: version)
            for candidate in [url, quarantineURL(for: url)] where fileManager.fileExists(atPath: candidate.path) {
                try? fileManager.removeItem(at: candidate)
            }
        }
    }

    // MARK: Private

    private func fileURL(accountID: String, schemaVersion: Int) -> URL {
        directoryURL.appendingPathComponent(
            "library-sync-queue.v\(schemaVersion).\(Self.accountFileComponent(accountID)).json"
        )
    }

    private func quarantineURL(for url: URL) -> URL {
        url.appendingPathExtension("corrupt")
    }

    private func quarantine(_ url: URL) {
        let destination = quarantineURL(for: url)
        try? fileManager.removeItem(at: destination)
        try? fileManager.moveItem(at: url, to: destination)
        print("[Sync] store quarantined code=STORE_CORRUPTED")
    }

    static func accountFileComponent(_ accountID: String) -> String {
        let digest = SHA256.hash(data: Data(accountID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
