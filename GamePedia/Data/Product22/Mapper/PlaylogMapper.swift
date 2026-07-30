import Foundation
import GamePediaProduct22API

// MARK: - PlaylogMapper

enum PlaylogMapper {

    // MARK: Response → domain

    static func session(from dto: Components.Schemas.PlaySession) -> PlaySession? {
        guard let id = PlaySessionID(uuidString: dto.id),
              let gameID = Product22CommonMapper.catalogGameID(dto.catalogGameId),
              let outcome = PlaySessionOutcome(rawValue: dto.outcome.rawValue),
              let visibility = PlaySessionVisibilityOption(rawValue: dto.visibility.rawValue) else {
            return nil
        }
        return PlaySession(
            id: id,
            catalogGameID: gameID,
            regionalReleaseID: dto.regionalReleaseId.flatMap { RegionalReleaseID(uuidString: $0) },
            playedAt: dto.playedAt,
            durationMinutes: dto.durationMinutes,
            progressPercent: dto.progressPercent,
            mood: dto.mood.flatMap { PlaySessionMood(rawValue: $0.rawValue) },
            note: dto.note,
            outcome: outcome,
            visibility: visibility,
            provenance: Product22CommonMapper.provenance(dto.provenance),
            clientMutationID: dto.clientMutationId,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    // MARK: Domain → request

    static func createRequest(
        from draft: PlaySessionDraft
    ) -> Components.Schemas.CreatePlaySessionRequest {
        Components.Schemas.CreatePlaySessionRequest(
            catalogGameId: draft.catalogGameID.wireValue,
            regionalReleaseId: draft.regionalReleaseID?.wireValue,
            playedAt: draft.playedAt,
            durationMinutes: draft.durationMinutes,
            progressPercent: draft.progressPercent,
            mood: draft.mood?.rawValue,
            note: draft.trimmedNote,
            outcome: Components.Schemas.PlaySessionOutcome(rawValue: draft.outcome.rawValue) ?? .CONTINUE,
            visibility: Components.Schemas.CreatePlaySessionRequest.visibilityPayload(
                rawValue: draft.visibility.rawValue
            ),
            // The key the draft was created with, unchanged. A retry of this
            // same submission reuses it and the server returns the original
            // record instead of writing a duplicate.
            clientMutationId: draft.clientMutationID
        )
    }

    static func patch(
        from draft: PlaySessionDraft,
        against existing: PlaySession
    ) -> PlaySessionPatch {
        // Only what actually changed is sent, so an edit cannot quietly
        // rewrite a field the user never touched.
        PlaySessionPatch(
            playedAt: draft.playedAt == existing.playedAt ? nil : draft.playedAt,
            durationMinutes: draft.durationMinutes == existing.durationMinutes ? nil : draft.durationMinutes,
            progressPercent: draft.progressPercent == existing.progressPercent ? nil : draft.progressPercent,
            mood: draft.mood == existing.mood ? nil : draft.mood?.rawValue,
            // An emptied note is sent as "" because the generated body cannot
            // express an explicit null; see PlaySessionPatch.
            note: draft.trimmedNote == existing.note ? nil : (draft.trimmedNote ?? ""),
            outcome: draft.outcome == existing.outcome
                ? nil
                : Components.Schemas.PlaySessionOutcome(rawValue: draft.outcome.rawValue),
            visibility: draft.visibility == existing.visibility
                ? nil
                : PlaySessionVisibility(rawValue: draft.visibility.rawValue),
            clientMutationID: draft.clientMutationID
        )
    }
}

// MARK: - PlayCalendarDeriver
//
// Builds the month grid from typed play sessions.
//
// This exists only because `getPlayCalendar` declares an untyped response body
// (docs/product-2.2-contract-gaps.md). It is the one place in the app that
// computes a calendar boundary itself, and it is deliberately narrow:
//
//   - it buckets by the user's IANA timezone, the same zone that would have
//     been sent to the endpoint, so a session near local midnight lands on the
//     day the user would call it
//   - it never touches a Monthly Replay result. Replay's monthKey, timezone
//     and window come from the server and are rendered verbatim; a DST
//     transition inside the month is the server's to resolve, not ours.

enum PlayCalendarDeriver {

    /// The half-open UTC window covering a local month, which is what the
    /// session list is asked for.
    static func window(
        monthKey: String,
        timeZone: TimeZone
    ) -> (start: Date, end: Date)? {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (1...12).contains(month) else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var startComponents = DateComponents()
        startComponents.year = year
        startComponents.month = month
        startComponents.day = 1
        guard let start = calendar.date(from: startComponents),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return (start, end)
    }

    static func month(
        monthKey: String,
        timeZone: TimeZone,
        sessions: [PlaySession]
    ) -> PlayCalendarMonth {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var buckets: [String: (count: Int, minutes: Int, unknown: Bool)] = [:]
        for session in sessions {
            let key = formatter.string(from: session.playedAt)
            var bucket = buckets[key] ?? (0, 0, false)
            bucket.count += 1
            if let minutes = session.durationMinutes {
                bucket.minutes += minutes
            } else {
                bucket.unknown = true
            }
            buckets[key] = bucket
        }

        let days = buckets
            .map { key, value in
                PlayCalendarDay(
                    dayKey: key,
                    sessionCount: value.count,
                    knownMinutes: value.minutes,
                    hasSessionsWithUnknownDuration: value.unknown
                )
            }
            .sorted { $0.dayKey < $1.dayKey }

        return PlayCalendarMonth(
            monthKey: monthKey,
            timeZoneIdentifier: timeZone.identifier,
            days: days
        )
    }
}
