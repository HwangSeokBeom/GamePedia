import UIKit

// MARK: - PlaySessionFormViewController
//
// Create or edit one play session.
//
// The idempotency key is created once, when the form opens, and reused for
// every save attempt from that form. A failed save can therefore be retried
// without writing a duplicate, while a second, genuinely new session opened
// later gets its own key.
//
// The note and mood never leave this screen except in the mutation itself:
// they are not logged, not put in a breadcrumb, and not emitted as a Product
// Event property. Nothing here persists a draft to disk, so an unsaved note
// exists only in memory and disappears with the screen.

final class PlaySessionFormViewController: UIViewController {

    // MARK: Input

    private let catalogGameID: CatalogGameID
    private let gameTitle: String?
    private let existing: PlaySession?
    private let repository: any PlaylogRepositing

    /// Created once per form. Reused by every retry of this same submission.
    private var draft: PlaySessionDraft

    var onSaved: (() -> Void)?

    private var saveTask: Task<Void, Never>?

    // MARK: Views

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let datePicker = UIDatePicker()
    private let durationField = UITextField()
    private let progressField = UITextField()
    private let moodControl = UISegmentedControl(items: [])
    private let outcomeControl = UISegmentedControl(items: [])
    private let visibilityControl = UISegmentedControl(items: [])
    private let noteView = UITextView()
    private let privacyLabel = UILabel()
    private let errorLabel = UILabel()
    private lazy var saveButton = UIBarButtonItem(
        title: L10n.Product22.Playlog.save,
        primaryAction: UIAction { [weak self] _ in self?.save() }
    )

    // MARK: Init

    init(
        catalogGameID: CatalogGameID,
        gameTitle: String?,
        existing: PlaySession?,
        repository: any PlaylogRepositing
    ) {
        self.catalogGameID = catalogGameID
        self.gameTitle = gameTitle
        self.existing = existing
        self.repository = repository

        if let existing {
            // Editing reuses the record's own key, so a retried edit is the
            // same mutation rather than a new one.
            draft = PlaySessionDraft(
                catalogGameID: existing.catalogGameID,
                regionalReleaseID: existing.regionalReleaseID,
                playedAt: existing.playedAt,
                durationMinutes: existing.durationMinutes,
                progressPercent: existing.progressPercent,
                mood: existing.mood,
                note: existing.note,
                outcome: existing.outcome,
                visibility: existing.visibility,
                clientMutationID: existing.clientMutationID
            )
        } else {
            draft = PlaySessionDraft(catalogGameID: catalogGameID)
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(catalogGameID:...)") }

    deinit { saveTask?.cancel() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpBackground
        title = existing == nil ? L10n.Product22.Playlog.add : L10n.Product22.Playlog.edit
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpTextSecondary)
        navigationItem.rightBarButtonItem = saveButton
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        setupViews()
        applyDraft()
        observeKeyboard()
    }

    private func setupViews() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.maximumDate = Date()
        datePicker.addTarget(self, action: #selector(fieldsChanged), for: .valueChanged)

        configure(durationField, keyboard: .numberPad)
        configure(progressField, keyboard: .numberPad)

        for mood in PlaySessionMood.allCases {
            moodControl.insertSegment(
                withTitle: Product22Vocabulary.text(for: mood),
                at: moodControl.numberOfSegments, animated: false
            )
        }
        moodControl.addTarget(self, action: #selector(fieldsChanged), for: .valueChanged)

        for outcome in PlaySessionOutcome.allCases {
            outcomeControl.insertSegment(
                withTitle: Product22Vocabulary.text(for: outcome),
                at: outcomeControl.numberOfSegments, animated: false
            )
        }
        outcomeControl.addTarget(self, action: #selector(fieldsChanged), for: .valueChanged)

        for visibility in PlaySessionVisibilityOption.allCases {
            visibilityControl.insertSegment(
                withTitle: Product22Vocabulary.text(for: visibility),
                at: visibilityControl.numberOfSegments, animated: false
            )
        }
        visibilityControl.addTarget(self, action: #selector(fieldsChanged), for: .valueChanged)

        noteView.font = .preferredFont(forTextStyle: .body)
        noteView.adjustsFontForContentSizeCategory = true
        noteView.backgroundColor = .gpInputBackground
        noteView.textColor = .gpTextPrimary
        noteView.layer.cornerRadius = 10
        noteView.delegate = self
        noteView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        noteView.accessibilityLabel = L10n.Product22.Playlog.note

        privacyLabel.font = .preferredFont(forTextStyle: .footnote)
        privacyLabel.adjustsFontForContentSizeCategory = true
        privacyLabel.textColor = .gpTextSecondary
        privacyLabel.numberOfLines = 0
        privacyLabel.text = L10n.Product22.Playlog.notePrivate

        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textColor = .gpRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        if let gameTitle {
            stack.addArrangedSubview(makeLabel(gameTitle, style: .headline, color: .gpTextPrimary))
        }
        stack.addArrangedSubview(makeFieldLabel(L10n.Product22.Playlog.playedAt))
        stack.addArrangedSubview(datePicker)
        stack.addArrangedSubview(makeFieldLabel(L10n.Product22.Playlog.duration))
        stack.addArrangedSubview(durationField)
        stack.addArrangedSubview(makeFieldLabel(L10n.Product22.Playlog.progress))
        stack.addArrangedSubview(progressField)
        stack.addArrangedSubview(makeFieldLabel(L10n.Product22.Playlog.outcome))
        stack.addArrangedSubview(outcomeControl)
        stack.addArrangedSubview(makeFieldLabel(L10n.Product22.Playlog.mood))
        stack.addArrangedSubview(moodControl)
        stack.addArrangedSubview(makeFieldLabel(L10n.Product22.Playlog.visibility))
        stack.addArrangedSubview(visibilityControl)
        stack.addArrangedSubview(makeFieldLabel(L10n.Product22.Playlog.note))
        stack.addArrangedSubview(noteView)
        stack.addArrangedSubview(privacyLabel)
        stack.addArrangedSubview(errorLabel)

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

    private func configure(_ field: UITextField, keyboard: UIKeyboardType) {
        field.borderStyle = .roundedRect
        field.keyboardType = keyboard
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.backgroundColor = .gpInputBackground
        field.textColor = .gpTextPrimary
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        field.addTarget(self, action: #selector(fieldsChanged), for: .editingChanged)
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        makeLabel(text, style: .subheadline, color: .gpTextSecondary)
    }

    private func makeLabel(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        label.text = text
        return label
    }

    // MARK: Keyboard avoidance

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardHidden),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardChanged(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }

    @objc private func keyboardHidden() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: Draft

    private func applyDraft() {
        datePicker.date = draft.playedAt
        durationField.text = draft.durationMinutes.map(String.init)
        progressField.text = draft.progressPercent.map(String.init)
        noteView.text = draft.note

        outcomeControl.selectedSegmentIndex =
            PlaySessionOutcome.allCases.firstIndex(of: draft.outcome) ?? 0
        // PRIVATE is the default for a new session, and the contract's own
        // default too.
        visibilityControl.selectedSegmentIndex =
            PlaySessionVisibilityOption.allCases.firstIndex(of: draft.visibility) ?? 0
        moodControl.selectedSegmentIndex = draft.mood
            .flatMap { PlaySessionMood.allCases.firstIndex(of: $0) } ?? UISegmentedControl.noSegment
    }

    @objc private func fieldsChanged() {
        draft.playedAt = datePicker.date
        // Values outside the contract's bounds are refused here rather than
        // sent and rejected by the server.
        draft.durationMinutes = Self.boundedInt(
            durationField.text,
            min: PlaySession.minimumDurationMinutes,
            max: PlaySession.maximumDurationMinutes
        )
        draft.progressPercent = Self.boundedInt(progressField.text, min: 0, max: 100)
        draft.outcome = PlaySessionOutcome.allCases[
            max(0, min(outcomeControl.selectedSegmentIndex, PlaySessionOutcome.allCases.count - 1))
        ]
        draft.visibility = PlaySessionVisibilityOption.allCases[
            max(0, min(visibilityControl.selectedSegmentIndex, PlaySessionVisibilityOption.allCases.count - 1))
        ]
        draft.mood = moodControl.selectedSegmentIndex == UISegmentedControl.noSegment
            ? nil
            : PlaySessionMood.allCases[moodControl.selectedSegmentIndex]
        errorLabel.isHidden = true
    }

    static func boundedInt(_ text: String?, min lower: Int, max upper: Int) -> Int? {
        guard let text, !text.isEmpty, let value = Int(text) else { return nil }
        return Swift.max(lower, Swift.min(upper, value))
    }

    /// Test seam: the draft as the form would submit it.
    var currentDraft: PlaySessionDraft { draft }

    // MARK: Saving

    private func save() {
        fieldsChanged()
        draft.note = noteView.text
        saveButton.isEnabled = false
        errorLabel.isHidden = true

        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let existing {
                    _ = try await repository.update(draft, existing: existing)
                } else {
                    _ = try await repository.create(draft)
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.onSaved?()
                    self.dismiss(animated: true)
                }
            } catch {
                guard !Task.isCancelled else { return }
                let mapped = Product22ErrorMapper.map(error)
                guard !mapped.isCancellation else { return }
                await MainActor.run {
                    self.saveButton.isEnabled = true
                    self.errorLabel.isHidden = false
                    // The draft keeps its key, so the user retrying this same
                    // save cannot create a duplicate — and the copy says so.
                    self.errorLabel.text = L10n.Product22.Playlog.saveFailed
                }
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension PlaySessionFormViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        // Held in memory only. Nothing writes this to disk, a log, a
        // breadcrumb or an analytics property.
        draft.note = textView.text
    }
}
