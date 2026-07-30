import Foundation
import GamePediaProduct22API
import OpenAPIRuntime

// MARK: - TodayFeedMapper
//
// Converts the generated Today response into `TodayFeed`.
//
// The generator recognised the sections' `key` const as a oneOf discriminator,
// so a section always decodes as the case its key names. Within a section, the
// ok variant (`case1`) and the disabled/unavailable variant (`case2`) are
// distinguished by whether `data` is null.
//
// Sections are re-ordered to match `meta.sectionOrder`. That ordering is the
// server's editorial decision about what matters today, and the app has no
// business overriding it.

enum TodayFeedMapper {

    static func map(_ dto: Components.Schemas.TodayFeed) -> TodayFeed {
        let mapped = dto.sections.compactMap(section(from:))
        return TodayFeed(
            generatedAt: dto.generatedAt,
            timezone: dto.timezone,
            locale: dto.locale,
            sections: ordered(mapped, by: dto.meta.sectionOrder),
            partialFailure: dto.meta.partialFailure
        )
    }

    /// Server order first, then anything the server sent but did not list, in
    /// arrival order. A section is never dropped just because `sectionOrder`
    /// forgot it.
    private static func ordered(
        _ sections: [TodaySection],
        by order: [String]
    ) -> [TodaySection] {
        var remaining = sections
        var result: [TodaySection] = []
        for key in order {
            guard let index = remaining.firstIndex(where: { $0.key.rawValue == key }) else { continue }
            result.append(remaining.remove(at: index))
        }
        result.append(contentsOf: remaining)
        return result
    }

    // MARK: Section dispatch

    private static func section(
        from dto: Components.Schemas.TodaySection
    ) -> TodaySection? {
        switch dto {
        case .playCompass(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(key: .playCompass, state: .content(.playCompass(playCompass(ok.data))))
            case .case2(let degraded):
                return degradedSection(.playCompass, status: degraded.status.rawValue, reason: degraded.reasonCode)
            }

        case .gameDNA(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(key: .gameDNA, state: .content(.gameDNA(gameDNA(ok.data))))
            case .case2(let degraded):
                return degradedSection(.gameDNA, status: degraded.status.rawValue, reason: degraded.reasonCode)
            }

        case .editorialCuration(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(
                    key: .editorialCuration,
                    state: .content(.editorialCuration(
                        articles: ok.data.articles.compactMap(ArticleMapper.card(from:)),
                        emptyReason: ok.data.emptyReason
                    ))
                )
            case .case2(let degraded):
                return degradedSection(.editorialCuration, status: degraded.status.rawValue, reason: degraded.reasonCode)
            }

        case .monthlyReplay(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(key: .monthlyReplay, state: .content(.monthlyReplay(replay(ok.data))))
            case .case2(let degraded):
                return degradedSection(.monthlyReplay, status: degraded.status.rawValue, reason: degraded.reasonCode)
            }

        // The remaining four declare `status` as a single-value const, which
        // the generator types as an opaque container rather than an enum.
        case .gameBriefing(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(
                    key: .gameBriefing,
                    state: .content(.gameBriefing(
                        items: ok.data.items.compactMap(briefingItem(from:)),
                        emptyReason: ok.data.emptyReason
                    ))
                )
            case .case2(let degraded):
                return degradedSection(
                    .gameBriefing,
                    status: Product22CommonMapper.constString(degraded.status),
                    reason: degraded.reasonCode
                )
            }

        case .backlogRescue(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(
                    key: .backlogRescue,
                    state: .content(.backlogRescue(
                        items: ok.data.items.compactMap(backlogItem(from:)),
                        emptyReason: ok.data.emptyReason
                    ))
                )
            case .case2(let degraded):
                return degradedSection(
                    .backlogRescue,
                    status: Product22CommonMapper.constString(degraded.status),
                    reason: degraded.reasonCode
                )
            }

        case .spoilerFreeStartGuide(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(
                    key: .spoilerFreeStartGuide,
                    state: .content(.spoilerFreeStartGuide(
                        items: ok.data.items.compactMap(startGuideItem(from:)),
                        emptyReason: ok.data.emptyReason
                    ))
                )
            case .case2(let degraded):
                return degradedSection(
                    .spoilerFreeStartGuide,
                    status: Product22CommonMapper.constString(degraded.status),
                    reason: degraded.reasonCode
                )
            }

        case .friendActivity(let value):
            switch value {
            case .case1(let ok):
                return TodaySection(
                    key: .friendActivity,
                    state: .content(.friendActivity(
                        items: ok.data.items.compactMap(friendActivityItem(from:)),
                        emptyReason: ok.data.emptyReason
                    ))
                )
            case .case2(let degraded):
                return degradedSection(
                    .friendActivity,
                    status: Product22CommonMapper.constString(degraded.status),
                    reason: degraded.reasonCode
                )
            }
        }
    }

    /// `disabled` and `unavailable` mean different things to the user — one is
    /// "this feature is off", the other is "this failed, try again" — so an
    /// unrecognised status is treated as unavailable, which is the state that
    /// offers a retry rather than the state that hides the section.
    private static func degradedSection(
        _ key: TodaySectionKey,
        status: String?,
        reason: String
    ) -> TodaySection {
        if status == "disabled" {
            return TodaySection(key: key, state: .disabled(reasonCode: reason))
        }
        return TodaySection(key: key, state: .unavailable(reasonCode: reason))
    }

    // MARK: Payloads

    private static func playCompass(
        _ data: Components.Schemas.TodayPlayCompassData
    ) -> TodayPlayCompassSummary {
        TodayPlayCompassSummary(
            recommendations: data.recommendations.compactMap(PlayCompassMapper.recommendation(from:)),
            confidence: Product22CommonMapper.confidence(data.confidence.rawValue),
            freshness: PlayCompassMapper.freshness(data.dataFreshness),
            emptyReason: data.emptyReason.flatMap { PlayCompassEmptyReason(rawValue: $0.rawValue) },
            ownedOnly: (data.ownedOnly.value as? Bool) ?? true
        )
    }

    private static func gameDNA(
        _ data: Components.Schemas.TodayGameDnaData
    ) -> TodayGameDNASummary {
        TodayGameDNASummary(
            signalCount: data.signalCount,
            confidence: Product22CommonMapper.confidence(data.confidence.rawValue),
            generatedAt: data.generatedAt,
            topGenres: data.topGenres.map {
                GameDNAGenreWeight(genre: $0.genre, weight: $0.weight, share: $0.share)
            },
            sessionLength: GameDNASessionLength(rawValue: data.sessionLengthLabel.rawValue) ?? .unknown,
            social: GameDNASocialLeaning(rawValue: data.socialLabel.rawValue) ?? .balanced,
            tone: GameDNATone(rawValue: data.toneLabel.rawValue) ?? .balanced,
            missingSignals: data.missingSignals,
            reasonCodes: data.reasonCodes
        )
    }

    private static func briefingItem(
        from dto: Components.Schemas.TodayGameBriefingData.itemsPayloadPayload
    ) -> TodayBriefingItem? {
        guard let id = Product22CommonMapper.catalogGameID(dto.catalogGameId) else { return nil }
        return TodayBriefingItem(
            catalogGameID: id,
            title: dto.title,
            updatedAt: dto.updatedAt,
            noteworthyReleases: dto.noteworthyReleases.compactMap { release in
                guard let status = Product22CommonMapper.serviceStatus(release.serviceStatus) else { return nil }
                return TodayBriefingItem.NoteworthyRelease(
                    countryCode: release.countryCode,
                    platform: release.platform,
                    serviceStatus: status,
                    shutdownDate: release.shutdownDate,
                    provenance: Product22CommonMapper.provenance(release.provenance)
                )
            }
        )
    }

    private static func backlogItem(
        from dto: Components.Schemas.TodayBacklogRescueData.itemsPayloadPayload
    ) -> TodayBacklogItem? {
        guard let id = Product22CommonMapper.catalogGameID(dto.catalogGameId) else { return nil }
        return TodayBacklogItem(
            catalogGameID: id,
            title: dto.title,
            addedAt: dto.addedAt,
            ownershipProvenance: Product22CommonMapper.provenance(dto.ownershipProvenance)
        )
    }

    private static func startGuideItem(
        from dto: Components.Schemas.TodaySpoilerFreeStartGuideData.itemsPayloadPayload
    ) -> TodayStartGuideItem? {
        guard let id = Product22CommonMapper.catalogGameID(dto.catalogGameId),
              let status = OwnedLibraryStatus(rawValue: dto.libraryStatus.rawValue) else { return nil }
        return TodayStartGuideItem(
            catalogGameID: id,
            title: dto.title,
            libraryStatus: status,
            genres: dto.genres,
            platforms: dto.platforms,
            estimatedFirstSessionMinutes: dto.estimatedFirstSessionMinutes,
            soloFriendly: dto.soloFriendly,
            partyFriendly: dto.partyFriendly
        )
    }

    private static func replay(
        _ data: Components.Schemas.TodayMonthlyReplayData
    ) -> TodayReplaySummary {
        TodayReplaySummary(
            monthKey: data.monthKey,
            timezone: data.timezone,
            isEmpty: data.isEmpty,
            playedDayCount: data.playedDayCount,
            totalMinutes: data.totalMinutes,
            mostPlayedGame: data.mostPlayedGame.flatMap { most in
                guard let id = Product22CommonMapper.catalogGameID(most.catalogGameId) else { return nil }
                return TodayReplaySummary.Highlight(
                    catalogGameID: id,
                    title: most.title,
                    totalMinutes: most.totalMinutes,
                    sessionCount: most.sessionCount,
                    minutesKnown: most.minutesKnown
                )
            },
            surpriseGame: data.surpriseGame.flatMap { surprise in
                guard let id = Product22CommonMapper.catalogGameID(surprise.catalogGameId) else { return nil }
                return TodayReplaySummary.Highlight(
                    catalogGameID: id,
                    title: surprise.title,
                    totalMinutes: surprise.totalMinutes,
                    sessionCount: surprise.sessionCount,
                    // A first-play-this-month highlight carries no
                    // minutes-known flag; the count is what it reports on.
                    minutesKnown: true
                )
            },
            missingData: data.missingData.map {
                MonthlyReplayGap(
                    code: $0.code,
                    affectedSessionCount: $0.affectedSessionCount,
                    affectedGameCount: $0.affectedGameCount,
                    effect: $0.effect
                )
            }
        )
    }

    private static func friendActivityItem(
        from dto: Components.Schemas.TodayFriendActivityData.itemsPayloadPayload
    ) -> TodayFriendActivityItem? {
        guard let activityID = UUID(uuidString: dto.activityId),
              let actorID = UUID(uuidString: dto.actorUserId),
              let kind = TodayFriendActivityItem.Kind(rawValue: dto.activityType.rawValue) else {
            return nil
        }
        return TodayFriendActivityItem(
            activityID: activityID,
            actorUserID: actorID,
            kind: kind,
            catalogGameID: dto.catalogGameId.flatMap(Product22CommonMapper.catalogGameID),
            legacyIdentity: LegacyGameIdentity(
                source: dto.legacyIdentity.gameSource.flatMap {
                    LegacyGameIdentity.Source(rawValue: $0.rawValue)
                },
                externalGameID: dto.legacyIdentity.externalGameId,
                igdbGameID: dto.legacyIdentity.igdbGameId
            ),
            createdAt: dto.createdAt
        )
    }
}
