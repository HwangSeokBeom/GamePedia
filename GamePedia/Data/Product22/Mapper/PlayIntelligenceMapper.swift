import Foundation
import GamePediaProduct22API
import OpenAPIRuntime

// MARK: - GameDNA (full profile)

struct GameDNAProfile: Equatable, Sendable {
    let signalCount: Int
    let confidence: PlayIntelligenceConfidence
    let generatedAt: Date
    let missingSignals: [String]
    let reasonCodes: [String]
    /// The contract pins this to true: Game DNA is always computed
    /// deterministically. Any AI narration is optional and additive, and the
    /// endpoint works with AI disabled — so the UI must never describe this
    /// profile as something an AI analysed.
    let isDeterministic: Bool
    let includesAINarration: Bool

    var hasEnoughSignal: Bool { confidence != .low && signalCount > 0 }
}

// MARK: - MonthlyReplay (full)

struct MonthlyReplay: Equatable, Sendable {
    /// The server's month key. Rendered as given.
    let monthKey: String
    /// The server's IANA zone. The client does not re-derive boundaries from it.
    let timezone: String
    /// The half-open UTC window the server resolved for this local month. A
    /// DST transition inside the month is already accounted for here.
    let window: Window
    let generatedAt: Date
    let isEmpty: Bool
    let emptyReason: String?
    /// `yyyy-MM-dd` local days on which something was played.
    let playedDates: [String]
    let mostPlayedGame: TodayReplaySummary.Highlight?
    let surpriseGame: TodayReplaySummary.Highlight?
    /// Everything the response could not account for. Shown, never hidden.
    let missingData: [MonthlyReplayGap]

    struct Window: Equatable, Sendable {
        let startUTC: Date
        let endUTC: Date
        let localDayCount: Int
    }

    var hasGaps: Bool { !missingData.isEmpty }
}

// MARK: - PlayIntelligenceMapper

enum PlayIntelligenceMapper {

    static func gameDNA(from dto: Components.Schemas.GameDna) -> GameDNAProfile {
        GameDNAProfile(
            signalCount: dto.signalCount,
            confidence: Product22CommonMapper.confidence(dto.confidence.rawValue),
            generatedAt: dto.generatedAt,
            missingSignals: dto.missingSignals,
            reasonCodes: dto.reasonCodes,
            isDeterministic: (dto.computation.deterministic.value as? Bool) ?? true,
            includesAINarration: dto.computation.aiNarrationIncluded ?? false
        )
    }

    static func monthlyReplay(from dto: Components.Schemas.MonthlyReplay) -> MonthlyReplay {
        MonthlyReplay(
            monthKey: dto.monthKey,
            timezone: dto.timezone,
            window: MonthlyReplay.Window(
                startUTC: dto.window.startUtc,
                endUTC: dto.window.endUtc,
                localDayCount: dto.window.localDayCount
            ),
            generatedAt: dto.generatedAt,
            isEmpty: dto.isEmpty,
            emptyReason: dto.emptyReason,
            playedDates: dto.playedDates,
            mostPlayedGame: nil,
            surpriseGame: nil,
            missingData: dto.missingData.map {
                MonthlyReplayGap(
                    code: $0.code,
                    affectedSessionCount: $0.affectedSessionCount,
                    affectedGameCount: $0.affectedGameCount,
                    effect: $0.effect ?? ""
                )
            }
        )
    }
}
