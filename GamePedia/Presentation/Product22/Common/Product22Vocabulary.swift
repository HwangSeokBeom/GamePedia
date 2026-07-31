import Foundation

// MARK: - Product22Vocabulary
//
// Maps contract enums to reader-facing copy, in one place.
//
// Two rules run through all of it:
//
//   1. A server token is never shown raw. `SUNSET_ANNOUNCED` means nothing to
//      a reader; "서비스 종료 예정" does.
//   2. Provenance tiers stay visually and verbally distinct. `AI_INFERRED` and
//      `PROVIDER_VERIFIED` must never read the same, because one is a guess
//      and the other is a fact established by a provider response.

enum Product22Vocabulary {

    // MARK: Provenance

    static func text(for provenance: CatalogProvenance) -> String {
        switch provenance.tier {
        case .verified: return L10n.Product22.Provenance.verified
        case .asserted: return L10n.Product22.Provenance.asserted
        case .unconfirmed: return L10n.Product22.Provenance.unconfirmed
        }
    }

    // MARK: Catalog lifecycle

    static func text(for status: CatalogServiceStatus) -> String {
        switch status {
        case .announced: return L10n.Product22.Service.announced
        case .preRegistration: return L10n.Product22.Service.preRegistration
        case .live: return L10n.Product22.Service.live
        case .maintenance: return L10n.Product22.Service.maintenance
        case .sunsetAnnounced: return L10n.Product22.Service.sunsetAnnounced
        case .shutdown: return L10n.Product22.Service.shutdown
        }
    }

    static func text(for status: CatalogPublicationStatus) -> String {
        switch status {
        case .privateEntry: return L10n.Product22.Publication.private
        case .pendingReview: return L10n.Product22.Publication.pendingReview
        case .published: return L10n.Product22.Publication.published
        case .rejected: return L10n.Product22.Publication.rejected
        }
    }

    // MARK: Playlog

    static func text(for outcome: PlaySessionOutcome) -> String {
        switch outcome {
        case .resume: return L10n.Product22.Outcome.continue
        case .paused: return L10n.Product22.Outcome.paused
        case .dropped: return L10n.Product22.Outcome.dropped
        case .completed: return L10n.Product22.Outcome.completed
        }
    }

    static func text(for mood: PlaySessionMood) -> String {
        switch mood {
        case .relaxed: return L10n.Product22.Mood.relaxed
        case .focused: return L10n.Product22.Mood.focused
        case .excited: return L10n.Product22.Mood.excited
        case .bored: return L10n.Product22.Mood.bored
        case .frustrated: return L10n.Product22.Mood.frustrated
        case .nostalgic: return L10n.Product22.Mood.nostalgic
        }
    }

    static func text(for visibility: PlaySessionVisibilityOption) -> String {
        switch visibility {
        case .privateOnly: return L10n.Product22.Visibility.private
        case .friends: return L10n.Product22.Visibility.friends
        case .everyone: return L10n.Product22.Visibility.public
        }
    }

    // MARK: Quick Add match reasons
    //
    // The one distinction that matters to a user choosing between candidates:
    // an exact provider identity means a verified row already exists, while an
    // unverified one means only that a store URL parsed. Parsing is not
    // verification, and the copy says so.

    static func text(for reason: QuickAddCandidate.MatchReason) -> String? {
        switch reason {
        case .providerIdentityExact:
            return L10n.Product22.QuickAdd.matchExact
        case .providerIdentityUnverified:
            return L10n.Product22.QuickAdd.matchUnverified
        case .localeAliasExact, .normalizedTitleExact, .compactTitleExact,
             .fuzzyTitleSimilar, .developerMatch, .platformMatch, .regionMatch:
            // Title/metadata similarity is not an identity claim, so it gets no
            // confidence-implying copy of its own.
            return nil
        }
    }
}
