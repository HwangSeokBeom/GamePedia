import UIKit

// MARK: - SubmissionStateViewController
//
// The status of one quick-add submission, now that `getCatalogSubmission`
// returns a typed body.
//
// Three contract facts shape this screen:
//
//   - `GameSubmissionStatus` has six values and this server writes four. All
//     six are rendered, because the contract lists APPROVED and REJECTED
//     precisely so a value from a future editorial flow decodes rather than
//     failing the response.
//   - `candidateSummary` is stored as JSON and returned without
//     re-validation, so a row written by an earlier revision can be missing
//     any field. "No candidate information was recorded" and "0 candidates
//     were found" are different facts and are shown differently.
//   - `expired` is evaluated against the *server* clock at read time. It is
//     rendered as received rather than re-derived from the device clock,
//     which would disagree across a skew.

final class SubmissionStateViewController: Product22ListViewController {

    private let submissionID: CatalogSubmissionID
    private let repository: any QuickAddRepositing
    private let configStore: ProductConfigStore
    private let onOpenCatalogGame: (CatalogGameID) -> Void

    private var state: CatalogSubmissionState?

    init(
        submissionID: CatalogSubmissionID,
        repository: any QuickAddRepositing,
        configStore: ProductConfigStore,
        onOpenCatalogGame: @escaping (CatalogGameID) -> Void
    ) {
        self.submissionID = submissionID
        self.repository = repository
        self.configStore = configStore
        self.onOpenCatalogGame = onOpenCatalogGame
        super.init(nibName: nil, bundle: nil)
        title = L10n.Product22.Submission.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(submissionID:...)") }

    override func loadContent() async -> Product22ListState {
        guard await configStore.refreshIfNeeded().isEnabled(.aiQuickAdd) else {
            return .disabled(message: L10n.Product22.Section.disabled)
        }
        do {
            let state = try await repository.state(submissionID: submissionID)
            self.state = state
            return .loaded(sections(for: state))
        } catch let error as Product22Error where error == .notFound {
            // Another account's submission is a 404 too, so ids stay
            // unenumerable. The copy does not distinguish the two cases.
            return .empty(message: L10n.Product22.Submission.notFound)
        } catch {
            return Product22ScreenState.failure(from: error, configStore: configStore)
        }
    }

    // MARK: Sections

    private func sections(for state: CatalogSubmissionState) -> [Product22ListSection] {
        var sections: [Product22ListSection] = []

        // Status, plus the expiry the server itself evaluated.
        var statusDetails = [Product22Vocabulary.text(for: state.publicationStatus)]
        if state.isExpired {
            statusDetails.append(L10n.Product22.QuickAdd.expired)
        } else if state.status.isActionable {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            statusDetails.append(
                "\(L10n.Product22.Submission.expiresAt) \(formatter.string(from: state.expiresAt))"
            )
        }
        if state.aiFallbackUsed {
            statusDetails.append(L10n.Product22.QuickAdd.aiFallback)
        }
        sections.append(
            Product22ListSection(
                id: "status",
                title: L10n.Product22.Submission.status,
                rows: [
                    Product22ListRow(
                        id: "status",
                        title: Self.text(for: state.status),
                        details: statusDetails
                    )
                ]
            )
        )

        // The resulting game, when the submission produced one. This is the
        // deep link the untyped contract could not offer.
        if let catalogGameID = state.catalogGameID {
            sections.append(
                Product22ListSection(
                    id: "game",
                    title: L10n.Product22.Submission.resultingGame,
                    rows: [
                        Product22ListRow(
                            id: catalogGameID.wireValue,
                            title: state.draft?.originalTitle ?? catalogGameID.wireValue,
                            actionTitle: L10n.Product22.QuickAdd.openRegisteredGame
                        )
                    ]
                )
            )
        }

        // The draft, or an honest explanation of why it cannot be shown.
        if state.isDraftReadable, let draft = state.draft {
            sections.append(draftSection(draft))
            if !draft.identities.isEmpty {
                sections.append(
                    Product22ListSection(
                        id: "identities",
                        // Explicitly labelled unverified: parsing a store URL
                        // is not verification, and these never occupied a
                        // global provider key.
                        title: L10n.Product22.Submission.claimedIdentities,
                        rows: draft.identities.enumerated().map { index, identity in
                            Product22ListRow(
                                id: "identity-\(index)",
                                title: identity.provider.rawValue,
                                details: [identity.externalID, identity.regionKey]
                            )
                        }
                    )
                )
            }
        } else {
            sections.append(
                Product22ListSection(
                    id: "draft",
                    title: L10n.Product22.Submission.draft,
                    rows: [
                        Product22ListRow(
                            id: "unreadable",
                            title: L10n.Product22.Submission.draftUnreadable
                        )
                    ]
                )
            )
        }

        sections.append(candidateSection(state.candidateSummary))

        if let question = state.clarifyingQuestion {
            sections.append(
                Product22ListSection(
                    id: "question",
                    title: nil,
                    rows: [Product22ListRow(id: "question", title: question)]
                )
            )
        }

        return sections
    }

    private func draftSection(_ draft: CatalogSubmissionDraft) -> Product22ListSection {
        var rows: [Product22ListRow] = []

        var titleDetails: [String] = []
        if draft.requiresTitleConfirmation {
            titleDetails.append(L10n.Product22.QuickAdd.titleRequired)
        }
        if let developer = draft.developerName { titleDetails.append(developer) }
        if let publisher = draft.publisherName { titleDetails.append(publisher) }
        if let released = draft.firstReleaseDate { titleDetails.append(released) }
        titleDetails.append(contentsOf: draft.genres)
        titleDetails.append(contentsOf: draft.platforms)
        rows.append(
            Product22ListRow(
                id: "draft-title",
                // Nil until a structured title exists — the raw input is never
                // used as a fallback, so the placeholder says so.
                title: draft.originalTitle ?? L10n.Product22.QuickAdd.titleRequired,
                details: titleDetails
            )
        )

        for (index, localization) in draft.localizations.enumerated() {
            rows.append(
                Product22ListRow(
                    id: "draft-loc-\(index)",
                    title: localization.title,
                    details: [localization.languageCode, localization.regionCode].compactMap { $0 }
                )
            )
        }
        for (index, release) in draft.regionalReleases.enumerated() {
            rows.append(
                Product22ListRow(
                    id: "draft-region-\(index)",
                    title: release.countryCode,
                    details: [
                        Product22Vocabulary.text(for: release.serviceStatus),
                        release.platform
                    ]
                )
            )
        }
        // Per-field provenance, so an inferred value never reads as confirmed.
        for evidence in draft.fieldProvenance where !evidence.provenance.isVerified {
            rows.append(
                Product22ListRow(
                    id: "draft-prov-\(evidence.fieldPath)",
                    title: evidence.fieldPath,
                    details: [Product22Vocabulary.text(for: evidence.provenance)]
                )
            )
        }

        return Product22ListSection(
            id: "draft", title: L10n.Product22.Submission.draft, rows: rows
        )
    }

    /// "Nothing recorded" and "zero found" are different facts, and a legacy
    /// row that predates the field can only support the first.
    private func candidateSection(
        _ summary: CatalogSubmissionCandidateSummary?
    ) -> Product22ListSection {
        guard let summary, !summary.isEmptyShape else {
            return Product22ListSection(
                id: "candidates",
                title: L10n.Product22.Submission.candidates,
                rows: [
                    Product22ListRow(
                        id: "candidates-unknown",
                        title: L10n.Product22.Submission.candidatesUnknown
                    )
                ]
            )
        }

        var rows: [Product22ListRow] = []
        if let count = summary.candidateCount {
            rows.append(
                Product22ListRow(
                    id: "candidate-count",
                    title: "\(count)",
                    details: summary.reasonCodes
                )
            )
        }
        for id in summary.catalogGameIDs {
            rows.append(
                Product22ListRow(
                    id: id.wireValue,
                    title: id.wireValue,
                    actionTitle: L10n.Common.Button.seeAll
                )
            )
        }
        if rows.isEmpty {
            rows.append(
                Product22ListRow(
                    id: "candidates-unknown",
                    title: L10n.Product22.Submission.candidatesUnknown
                )
            )
        }
        return Product22ListSection(
            id: "candidates", title: L10n.Product22.Submission.candidates, rows: rows
        )
    }

    override func didSelectRow(_ row: Product22ListRow, in section: Product22ListSection) {
        guard section.id == "game" || section.id == "candidates",
              let id = CatalogGameID(uuidString: row.id) else { return }
        onOpenCatalogGame(id)
    }

    // MARK: Status vocabulary

    /// All six contract values, including the two this server does not write.
    static func text(for status: CatalogSubmissionStatus) -> String {
        switch status {
        case .preview: return L10n.Product22.Submission.statusPreview
        case .personalConfirmed: return L10n.Product22.Submission.statusPersonalConfirmed
        case .pendingReview: return L10n.Product22.Submission.statusPendingReview
        case .approved: return L10n.Product22.Submission.statusApproved
        case .rejected: return L10n.Product22.Submission.statusRejected
        case .expired: return L10n.Product22.Submission.statusExpired
        }
    }
}
