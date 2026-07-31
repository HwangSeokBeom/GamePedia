import UIKit

// MARK: - QuickAddViewController
//
// The AI-assisted quick add flow: input → preview → confirm.
//
// Trust rules this screen exists to hold:
//
//   - the raw natural-language input lives in memory only. It is not written
//     to UserDefaults, a file, a log, a breadcrumb, a crash report or the
//     search history, and it is discarded when the app leaves the foreground
//     or the flow ends.
//   - existing candidates and the new draft are separated visually, and
//     linking an existing game is the more prominent action.
//   - an inferred value is labelled as needing confirmation. AI_INFERRED and
//     USER_CONFIRMED never render alike.
//   - personal registration (PRIVATE) and a public listing request
//     (PENDING_REVIEW) are different buttons with different copy, and nothing
//     ever claims a submission was published.
//   - an identity conflict is reported, never auto-merged.

final class QuickAddViewController: UIViewController {

    // MARK: Dependencies

    private let repository: any QuickAddRepositing
    private let configStore: ProductConfigStore
    private let onFindInCatalog: (String?) -> Void
    /// Deep link to the game the confirmation resolved to. Available now that
    /// `confirmCatalogSubmission` returns a typed `catalogGameId`.
    private let onOpenCatalogGame: (CatalogGameID) -> Void
    private let onOpenSubmissionState: (CatalogSubmissionID) -> Void

    // MARK: State

    /// Raw user input. Memory only — see the type comment.
    private var rawInput: String
    private var regionCode: String
    private var platformHint: String?
    private var preview: QuickAddPreview?
    private var selectedCandidate: QuickAddCandidate?
    private var confirmedTitle: String?
    private var task: Task<Void, Never>?

    // MARK: Views

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let inputField = UITextField()
    private let regionField = UITextField()
    private let platformField = UITextField()
    private let previewButton = UIButton(type: .system)
    private let resultsStack = UIStackView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: Init

    init(
        initialQuery: String?,
        repository: any QuickAddRepositing,
        configStore: ProductConfigStore,
        onFindInCatalog: @escaping (String?) -> Void,
        onOpenCatalogGame: @escaping (CatalogGameID) -> Void = { _ in },
        onOpenSubmissionState: @escaping (CatalogSubmissionID) -> Void = { _ in }
    ) {
        self.rawInput = initialQuery ?? ""
        self.repository = repository
        self.configStore = configStore
        self.onFindInCatalog = onFindInCatalog
        self.onOpenCatalogGame = onOpenCatalogGame
        self.onOpenSubmissionState = onOpenSubmissionState
        // Suggested from the device region, and editable — the user may be
        // registering a game for a different market than they live in.
        self.regionCode = (Locale.current.region?.identifier ?? "US").uppercased()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(initialQuery:...)") }

    deinit { task?.cancel() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpBackground
        title = L10n.Product22.QuickAdd.title
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        setupViews()

        // Anything unfinished is dropped when the app backgrounds, so a raw
        // sentence never survives in memory across a session boundary.
        NotificationCenter.default.addObserver(
            self, selector: #selector(discardUnfinishedInput),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
    }

    /// Discards the raw input and any preview built from it.
    @objc func discardUnfinishedInput() {
        rawInput = ""
        inputField.text = ""
        preview = nil
        selectedCandidate = nil
        confirmedTitle = nil
        renderResults()
    }

    /// Test seam: whether any raw input is still held.
    var holdsRawInput: Bool { !rawInput.isEmpty }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        inputField.text = rawInput
        inputField.placeholder = L10n.Product22.QuickAdd.inputPlaceholder
        inputField.borderStyle = .roundedRect
        inputField.backgroundColor = .gpInputBackground
        inputField.textColor = .gpTextPrimary
        inputField.font = .preferredFont(forTextStyle: .body)
        inputField.adjustsFontForContentSizeCategory = true
        inputField.autocorrectionType = .no
        // Never offered to the keyboard's learning store, so a private title
        // does not end up in the user's predictive text.
        inputField.spellCheckingType = .no
        inputField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        inputField.addTarget(self, action: #selector(inputChanged), for: .editingChanged)

        regionField.text = regionCode
        regionField.borderStyle = .roundedRect
        regionField.backgroundColor = .gpInputBackground
        regionField.textColor = .gpTextPrimary
        regionField.autocapitalizationType = .allCharacters
        regionField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        regionField.addTarget(self, action: #selector(inputChanged), for: .editingChanged)

        platformField.placeholder = L10n.Product22.QuickAdd.platformHint
        platformField.borderStyle = .roundedRect
        platformField.backgroundColor = .gpInputBackground
        platformField.textColor = .gpTextPrimary
        platformField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        platformField.addTarget(self, action: #selector(inputChanged), for: .editingChanged)

        previewButton.setTitle(L10n.Product22.QuickAdd.preview, for: .normal)
        previewButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        previewButton.titleLabel?.adjustsFontForContentSizeCategory = true
        previewButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        previewButton.addTarget(self, action: #selector(requestPreview), for: .touchUpInside)

        resultsStack.axis = .vertical
        resultsStack.spacing = 12

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .gpRed
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true

        activityIndicator.hidesWhenStopped = true

        stack.addArrangedSubview(label(L10n.Product22.QuickAdd.inputPrompt, .subheadline, .gpTextSecondary))
        stack.addArrangedSubview(inputField)
        stack.addArrangedSubview(label(L10n.Product22.QuickAdd.inputNotStored, .caption1, .gpTextTertiary))
        stack.addArrangedSubview(label(L10n.Product22.QuickAdd.region, .subheadline, .gpTextSecondary))
        stack.addArrangedSubview(regionField)
        stack.addArrangedSubview(platformField)
        stack.addArrangedSubview(previewButton)
        stack.addArrangedSubview(activityIndicator)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(resultsStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    private func label(_ text: String, _ style: UIFont.TextStyle, _ color: UIColor) -> UILabel {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: style)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = color
        view.numberOfLines = 0
        view.text = text
        return view
    }

    @objc private func inputChanged() {
        rawInput = inputField.text ?? ""
        regionCode = (regionField.text ?? "").uppercased()
        let platform = platformField.text ?? ""
        platformHint = platform.isEmpty ? nil : platform
        statusLabel.isHidden = true
    }

    // MARK: Input kind
    //
    // Decided from the shape of what was typed, so the user does not have to
    // classify their own input. Parsing a URL is only a routing decision — it
    // is emphatically not verification, and nothing downstream treats it as
    // one.

    static func inferKind(from raw: String) -> QuickAddInput.Kind {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return .url
        }
        // An App Store numeric id or a Google Play package name.
        if trimmed.allSatisfy(\.isNumber) && trimmed.count >= 6 { return .providerID }
        if trimmed.contains("."), !trimmed.contains(" "),
           trimmed.split(separator: ".").count >= 3 {
            return .providerID
        }
        return .text
    }

    // MARK: Preview

    @objc private func requestPreview() {
        inputChanged()
        let input = QuickAddInput(
            kind: Self.inferKind(from: rawInput),
            rawInput: rawInput,
            locale: Locale.current.language.languageCode?.identifier ?? "en",
            regionCode: regionCode,
            platformHint: platformHint
        )
        guard input.isSendable else {
            show(error: L10n.Product22.QuickAdd.invalidInput)
            return
        }

        task?.cancel()
        activityIndicator.startAnimating()
        statusLabel.isHidden = true

        task = Task { [weak self] in
            guard let self else { return }
            guard await configStore.refreshIfNeeded().isEnabled(.aiQuickAdd) else {
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.show(error: L10n.Product22.Section.disabled)
                }
                return
            }
            do {
                let preview = try await repository.preview(input)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.preview = preview
                    self.renderResults()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.show(error: self.message(for: error))
                }
            }
        }
    }

    /// Maps a failure to copy the user can act on. The server's own validation
    /// text is never shown — it leaks internals like "unpaired surrogate".
    private func message(for error: any Error) -> String {
        switch Product22ErrorMapper.map(error) {
        case .rateLimited:
            return L10n.Product22.QuickAdd.quotaExceeded
        case .conflict(let code, _):
            return code == Product22ErrorCode.identityConflict
                ? L10n.Product22.QuickAdd.identityConflict
                : L10n.Product22.QuickAdd.expired
        case .validation(let failure):
            if failure.code == Product22ErrorCode.submissionTitleRequired {
                return L10n.Product22.QuickAdd.titleRequired
            }
            return L10n.Product22.QuickAdd.invalidInput
        case .notFound:
            return L10n.Product22.QuickAdd.expired
        case .featureUnavailable:
            return L10n.Product22.Section.disabled
        case .unauthorized, .accountChanged:
            return L10n.Common.Error.unauthorized
        default:
            return L10n.Common.Error.network
        }
    }

    private func show(error: String) {
        statusLabel.text = error
        statusLabel.isHidden = false
    }

    // MARK: Results

    private func renderResults() {
        resultsStack.arrangedSubviews.forEach {
            resultsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        guard let preview else { return }

        if preview.isExpired(at: Date()) {
            resultsStack.addArrangedSubview(
                label(L10n.Product22.QuickAdd.expired, .subheadline, .gpRed)
            )
            return
        }

        // Existing candidates first, and visually separated: linking what
        // already exists should always be easier than creating a duplicate.
        if !preview.existingCandidates.isEmpty {
            resultsStack.addArrangedSubview(
                label(L10n.Product22.QuickAdd.existingCandidates, .headline, .gpTextPrimary)
            )
            for candidate in preview.existingCandidates {
                resultsStack.addArrangedSubview(makeCandidateView(candidate))
            }
        }

        resultsStack.addArrangedSubview(
            label(L10n.Product22.QuickAdd.newDraft, .headline, .gpTextPrimary)
        )

        if preview.resolution.aiFallbackUsed {
            // Automatic lookup failed; the user must still be able to proceed
            // by confirming fields themselves.
            resultsStack.addArrangedSubview(
                label(L10n.Product22.QuickAdd.aiFallback, .footnote, .gpOrange)
            )
        } else if preview.resolution.aiUsed {
            resultsStack.addArrangedSubview(
                label(L10n.Product22.QuickAdd.aiInferred, .footnote, .gpOrange)
            )
        }

        let titleField = UITextField()
        titleField.borderStyle = .roundedRect
        titleField.backgroundColor = .gpInputBackground
        titleField.textColor = .gpTextPrimary
        titleField.font = .preferredFont(forTextStyle: .body)
        titleField.adjustsFontForContentSizeCategory = true
        titleField.text = preview.newGameDraft.originalTitle
        titleField.placeholder = L10n.Product22.Catalog.originalTitle
        titleField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        titleField.addTarget(self, action: #selector(titleChanged(_:)), for: .editingChanged)
        confirmedTitle = preview.newGameDraft.originalTitle
        resultsStack.addArrangedSubview(titleField)

        if preview.newGameDraft.requiresTitleConfirmation {
            // No structured title could be derived; the raw sentence is never
            // used as a fallback, so the user has to supply one.
            resultsStack.addArrangedSubview(
                label(L10n.Product22.QuickAdd.titleRequired, .footnote, .gpOrange)
            )
        }
        if let question = preview.clarifyingQuestion {
            resultsStack.addArrangedSubview(label(question, .footnote, .gpTextSecondary))
        }

        // Per-field provenance, so an inferred value is visibly not confirmed.
        for evidence in preview.fieldProvenance where !evidence.provenance.isVerified {
            resultsStack.addArrangedSubview(
                label(
                    "\(evidence.fieldPath) — \(Product22Vocabulary.text(for: evidence.provenance))",
                    .caption1, .gpTextTertiary
                )
            )
        }

        resultsStack.addArrangedSubview(
            label(L10n.Product22.QuickAdd.confirmFields, .footnote, .gpTextSecondary)
        )

        // The two outcomes are separate buttons with distinct copy. Nothing
        // here implies a public listing is immediate.
        resultsStack.addArrangedSubview(
            makeActionButton(L10n.Product22.QuickAdd.registerPrivate) { [weak self] in
                self?.confirm(requestPublicReview: false)
            }
        )
        resultsStack.addArrangedSubview(
            makeActionButton(L10n.Product22.QuickAdd.requestPublicReview) { [weak self] in
                self?.confirm(requestPublicReview: true)
            }
        )
        resultsStack.addArrangedSubview(
            label(L10n.Product22.QuickAdd.publicReviewNote, .caption1, .gpTextTertiary)
        )
    }

    @objc private func titleChanged(_ field: UITextField) {
        confirmedTitle = field.text
    }

    private func makeCandidateView(_ candidate: QuickAddCandidate) -> UIView {
        var details = candidate.matchReasons.compactMap(Product22Vocabulary.text(for:))
        details.append(Product22Vocabulary.text(for: candidate.game.publicationStatus))
        if let developer = candidate.game.developerName { details.append(developer) }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 3
        stack.addArrangedSubview(label(candidate.game.originalTitle, .subheadline, .gpTextPrimary))
        for detail in details {
            stack.addArrangedSubview(label(detail, .caption1, .gpTextTertiary))
        }
        stack.addArrangedSubview(
            makeActionButton(L10n.Product22.QuickAdd.linkExisting) { [weak self] in
                self?.selectedCandidate = candidate
                self?.confirm(requestPublicReview: false)
            }
        )
        return stack
    }

    private func makeActionButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    // MARK: Confirm

    private func confirm(requestPublicReview: Bool) {
        guard let preview else { return }
        guard !preview.isExpired(at: Date()) else {
            show(error: L10n.Product22.QuickAdd.expired)
            return
        }

        // The two confirmation shapes are mutually exclusive, which the domain
        // type enforces: there is no way to send both.
        let confirmation: QuickAddConfirmation
        if let candidate = selectedCandidate {
            confirmation = .linkExisting(candidate.game.id, requestPublicReview: requestPublicReview)
        } else {
            let title = confirmedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            if preview.newGameDraft.requiresTitleConfirmation, (title ?? "").isEmpty {
                show(error: L10n.Product22.QuickAdd.titleRequired)
                return
            }
            confirmation = .confirmNewGame(
                fields: QuickAddConfirmedFields(
                    originalTitle: (title ?? "").isEmpty ? nil : title,
                    developerName: nil,     // never confirmed here, so never sent
                    publisherName: nil,
                    platforms: platformHint.map { [$0] } ?? []
                ),
                requestPublicReview: requestPublicReview
            )
        }

        task?.cancel()
        activityIndicator.startAnimating()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await repository.confirm(
                    submissionID: preview.submissionID, selection: confirmation
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.showCompletion(result: result)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.activityIndicator.stopAnimating()
                    self.show(error: self.message(for: error))
                }
            }
        }
    }

    /// Reports the outcome and offers the game it resolved to.
    ///
    /// `confirmCatalogSubmission` now returns a typed `catalogGameId`, so the
    /// flow deep-links to the game that was created or linked instead of
    /// falling back to a catalog search. All three paths return the same
    /// fields, so this reads `createdNewGame` and `isIdempotentReplay` rather
    /// than branching on the status code.
    ///
    /// An identity conflict takes priority over the resolved game: if a
    /// verified identity already exists elsewhere, that existing game is the
    /// honest destination, and nothing was merged to get there.
    private func showCompletion(result: SubmissionConfirmResult) {
        var message: String
        switch result.publicationStatus {
        case .pendingReview:
            message = L10n.Product22.QuickAdd.donePendingReview
        case .privateEntry, .published, .rejected:
            message = result.createdNewGame
                ? L10n.Product22.QuickAdd.doneRegistered
                : L10n.Product22.QuickAdd.doneLinked
        }
        if result.isIdempotentReplay {
            message += "\n\n" + L10n.Product22.QuickAdd.replayed
        }
        if result.identityConflict != nil {
            message += "\n\n" + L10n.Product22.QuickAdd.conflictExistingGame
        }

        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        if let target = result.deepLinkTarget {
            let title = result.identityConflict != nil
                ? L10n.Product22.QuickAdd.openConflictingGame
                : L10n.Product22.QuickAdd.openRegisteredGame
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.discardUnfinishedInput()
                self?.dismiss(animated: true) { self?.onOpenCatalogGame(target) }
            })
        }

        alert.addAction(
            UIAlertAction(title: L10n.Product22.Submission.title, style: .default) { [weak self] _ in
                let id = result.submissionID
                self?.discardUnfinishedInput()
                self?.dismiss(animated: true) { self?.onOpenSubmissionState(id) }
            }
        )
        alert.addAction(UIAlertAction(title: L10n.Common.Button.confirm, style: .cancel) { [weak self] _ in
            self?.discardUnfinishedInput()
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
