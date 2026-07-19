import Foundation

// MARK: - Operation breadcrumbs (incident-safe diagnostics)
//
// A bounded, in-memory ring buffer of privacy-safe operational events:
// session transitions, availability changes, activity-center load
// outcomes, dedup suppressions. Breadcrumbs give an incident responder
// the "what happened just before" timeline without ever persisting or
// exposing user content.
//
// Privacy contract (enforced, not advisory): every code, metadata key,
// and metadata value is validated against a strict identifier alphabet
// before storage. Anything that could smuggle free-form content — spaces,
// '@' (emails), '+', '=', '/' (base64/JWT segments), values longer than
// 64 characters — is replaced with "<redacted>" at record time. Tokens,
// emails, titles, and message bodies are structurally unable to survive.
// The buffer lives in process memory only and is surfaced exclusively
// through the DEBUG diagnostics screen.

enum BreadcrumbCategory: String, Sendable, CaseIterable {
    case session
    case availability
    case activityCenter
    case push
    case realtime
    case sync
}

struct OperationBreadcrumb: Equatable, Sendable {
    let occurredAt: Date
    let category: BreadcrumbCategory
    let code: String
    let metadata: [String: String]
}

final class OperationBreadcrumbRecorder: @unchecked Sendable {

    static let shared = OperationBreadcrumbRecorder()

    static let redactedPlaceholder = "<redacted>"

    private let lock = NSLock()
    private var buffer: [OperationBreadcrumb] = []
    private let capacity: Int
    private let dateProvider: () -> Date

    init(capacity: Int = 200, dateProvider: @escaping () -> Date = Date.init) {
        self.capacity = max(1, capacity)
        self.dateProvider = dateProvider
    }

    func record(_ category: BreadcrumbCategory, code: String, metadata: [String: String] = [:]) {
        var safeMetadata: [String: String] = [:]
        for (key, value) in metadata {
            safeMetadata[Self.sanitized(key)] = Self.sanitized(value)
        }
        let breadcrumb = OperationBreadcrumb(
            occurredAt: dateProvider(),
            category: category,
            code: Self.sanitized(code),
            metadata: safeMetadata
        )

        lock.lock()
        buffer.append(breadcrumb)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
        lock.unlock()
    }

    /// Oldest-first snapshot.
    func snapshot() -> [OperationBreadcrumb] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    func clear() {
        lock.lock()
        buffer.removeAll()
        lock.unlock()
    }

    /// A value survives only when it is a short machine identifier:
    /// letters, digits, '_', '-', '.', ':' — max 64 characters, no '@'.
    static func sanitized(_ value: String) -> String {
        guard value.isEmpty == false, value.count <= 64 else {
            return redactedPlaceholder
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.:")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return redactedPlaceholder
        }
        return value
    }
}
