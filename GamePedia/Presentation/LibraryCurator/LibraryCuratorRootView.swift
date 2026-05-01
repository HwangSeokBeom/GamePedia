import UIKit

final class LibraryCuratorRootView: UIView {
    private struct AnalyzeButtonPresentation: Equatable {
        let style: LibraryCuratorAnalyzeButtonStyle
        let title: String
        let iconName: String
        let isActionEnabled: Bool
    }

    let queryTextView: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .gpSurface
        textView.textColor = .gpTextPrimary
        textView.font = .systemFont(ofSize: 15)
        textView.tintColor = .gpPrimary
        textView.layer.cornerRadius = 14
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    let modeCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    let analyzeButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.tintColor = .gpOnPrimary
        button.backgroundColor = .gpPrimary
        button.titleLabel?.alpha = 1
        button.imageView?.alpha = 1
        button.layer.cornerRadius = 23
        button.layer.cornerCurve = .continuous
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let retryButton: UIButton = {
        let button = UIButton(configuration: .bordered())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 170
        tableView.isScrollEnabled = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "library_curator_query_placeholder")
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let queryHelperLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let fallbackBannerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let fallbackBannerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurface
        view.layer.cornerRadius = 12
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dailyLimitEmptyCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dailyLimitEmptyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dailyLimitEmptyBodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let summaryTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let summaryBodyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let summaryBulletsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let summaryCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tasteTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "library_curator_taste_profile_title")
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let tasteTagFlowView: TagFlowView = {
        let view = TagFlowView()
        view.maximumRows = 2
        view.maximumChipWidth = 150
        return view
    }()

    private let resultTitleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "library_curator_result_title")
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(icon: "sparkles", message: L10n.tr("Localizable", "library_curator_empty_message"))
        view.isHidden = true
        return view
    }()

    private let errorContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurface
        view.layer.cornerRadius = 14
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .gpTextSecondary
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private let staleLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.tr("Localizable", "ai_recommendation_stale_notice")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var tableHeightConstraint: NSLayoutConstraint?
    private var baseBottomInset: CGFloat = 24
    private var keyboardBottomInset: CGFloat = 0
    private var isApplyingAnalyzeButtonConfiguration = false
    private var analyzeButtonPresentation = AnalyzeButtonPresentation(
        style: .idle,
        title: L10n.tr("Localizable", "library_curator_analyze_button"),
        iconName: "sparkles",
        isActionEnabled: true
    )
#if DEBUG
    private var lastLoggedButtonKey: String?
    private var lastLoggedDailyLimitKey: String?
    private var lastLoggedSectionVisibilityKey: String?
    private var lastLoggedApplyVisibilityKey: String?
#endif

    var onTasteTagTapped: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func render(_ state: LibraryCuratorViewState) {
        if queryTextView.text != state.queryText {
            queryTextView.text = state.queryText
        }
        placeholderLabel.isHidden = !state.queryText.isEmpty

        applyAnalyzeButton(
            style: state.analyzeButtonStyle,
            title: state.analyzeButtonTitle,
            iconName: state.analyzeButtonIcon,
            isActionEnabled: state.canAnalyze
        )

        var retryConfiguration = UIButton.Configuration.bordered()
        retryConfiguration.title = L10n.tr("Localizable", "library_curator_retry_button")
        retryConfiguration.baseForegroundColor = state.isDailyLimitExceeded ? .gpTextTertiary : .gpPrimary
        retryConfiguration.cornerStyle = .capsule
        retryButton.configuration = retryConfiguration
        retryButton.isEnabled = !state.isDailyLimitExceeded
        retryButton.isHidden = state.isDailyLimitExceeded

        if state.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        queryHelperLabel.text = state.selectedPromptChipID == LibraryCuratorMode.overview.promptChipID
            ? L10n.tr("Localizable", "library_curator_overview_helper")
            : nil
        queryHelperLabel.isHidden = queryHelperLabel.text == nil

        let bannerMessage = state.bannerMessage?.nilIfBlankForCuratorUI
        fallbackBannerLabel.text = bannerMessage
        fallbackBannerView.isHidden = bannerMessage == nil
            || !state.shouldShowDailyLimitBanner && state.errorMessage != nil
        staleLabel.isHidden = !state.isStale

        let visibleSummary = state.visibleSummary
        let visibleTasteProfile = state.visibleTasteProfile
        let visibleRecommendations = state.visibleRecommendations

        if let visibleSummary {
            summaryTitleLabel.text = visibleSummary.title
            summaryTitleLabel.isHidden = visibleSummary.title == nil
            summaryBodyLabel.text = visibleSummary.body
            summaryBodyLabel.isHidden = visibleSummary.body == nil
            summaryBulletsLabel.text = visibleSummary.bullets.map { "• \($0)" }.joined(separator: "\n").nilIfBlankForCuratorUI
            summaryBulletsLabel.isHidden = visibleSummary.bullets.isEmpty
        } else {
            resetSummaryCard()
        }

        if !visibleTasteProfile.isEmpty {
            tasteTagFlowView.configure(items: visibleTasteProfile.map {
                let id = LibraryCuratorViewModel.tagID(for: $0, section: "taste")
                return TagFlowItem(
                    id: id,
                    title: $0,
                    isSelected: state.selectedTasteTagIDs.contains(id)
                )
            })
        } else {
            tasteTagFlowView.configure(items: [])
        }

        switch state.dailyLimitPresentation {
        case .none, .banner:
            dailyLimitEmptyCardView.isHidden = true
            dailyLimitEmptyTitleLabel.text = nil
            dailyLimitEmptyBodyLabel.text = nil
        case .empty(let title, let message):
            let title = title.nilIfBlankForCuratorUI
            let message = message.nilIfBlankForCuratorUI
            dailyLimitEmptyTitleLabel.text = title
            dailyLimitEmptyTitleLabel.isHidden = title == nil
            dailyLimitEmptyBodyLabel.text = message
            dailyLimitEmptyBodyLabel.isHidden = message == nil
            dailyLimitEmptyCardView.isHidden = !state.shouldShowDailyLimitEmptyState || (title == nil && message == nil)
        }

        let errorMessage = state.errorMessage?.nilIfBlankForCuratorUI
        errorLabel.text = errorMessage ?? L10n.tr("Localizable", "library_curator_error_message")
        errorContainerView.isHidden = errorMessage == nil || state.isDailyLimitExceeded
        emptyStateView.configure(icon: "sparkles", message: state.emptyState?.message.nilIfBlankForCuratorUI)

        applyVisibility(
            state: state,
            visibleSummary: visibleSummary,
            visibleTasteProfile: visibleTasteProfile,
            visibleRecommendations: visibleRecommendations
        )

#if DEBUG
        logRender(state: state, visibleSummary: visibleSummary, visibleTasteProfile: visibleTasteProfile, visibleRecommendations: visibleRecommendations)
#endif
    }

    func updateTableHeight() {
        tableView.layoutIfNeeded()
        tableHeightConstraint?.constant = tableView.isHidden ? 0 : tableView.contentSize.height
        layoutIfNeeded()
    }

    func setBaseBottomInset(_ bottomInset: CGFloat) {
        baseBottomInset = bottomInset
        updateScrollInsets()
    }

    func setKeyboardBottomInset(_ bottomInset: CGFloat) {
        keyboardBottomInset = bottomInset
        updateScrollInsets()
    }

    private func setup() {
        backgroundColor = .gpBackground
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        queryTextView.addSubview(placeholderLabel)
        tableView.register(LibraryCuratorResultCell.self, forCellReuseIdentifier: LibraryCuratorResultCell.reuseId)
        modeCollectionView.register(LibraryCuratorModeChipCell.self, forCellWithReuseIdentifier: LibraryCuratorModeChipCell.reuseId)
        tasteTagFlowView.onItemTapped = { [weak self] item in
            self?.onTasteTagTapped?(item.id)
        }
        analyzeButton.configurationUpdateHandler = { [weak self] _ in
            self?.applyCurrentAnalyzeButtonConfiguration()
        }

        fallbackBannerView.addSubview(fallbackBannerLabel)

        let dailyLimitEmptyStackView = UIStackView(arrangedSubviews: [
            dailyLimitEmptyTitleLabel,
            dailyLimitEmptyBodyLabel
        ])
        dailyLimitEmptyStackView.axis = .vertical
        dailyLimitEmptyStackView.spacing = 8
        dailyLimitEmptyStackView.alignment = .center
        dailyLimitEmptyStackView.translatesAutoresizingMaskIntoConstraints = false
        dailyLimitEmptyCardView.addSubview(dailyLimitEmptyStackView)

        let summaryStackView = UIStackView(arrangedSubviews: [
            summaryTitleLabel,
            summaryBodyLabel,
            summaryBulletsLabel
        ])
        summaryStackView.axis = .vertical
        summaryStackView.spacing = 8
        summaryStackView.translatesAutoresizingMaskIntoConstraints = false
        summaryCardView.addSubview(summaryStackView)

        let errorStackView = UIStackView(arrangedSubviews: [errorLabel, retryButton])
        errorStackView.axis = .vertical
        errorStackView.spacing = 12
        errorStackView.alignment = .center
        errorStackView.translatesAutoresizingMaskIntoConstraints = false
        errorContainerView.addSubview(errorStackView)

        let contentStackView = UIStackView(arrangedSubviews: [
            queryTextView,
            queryHelperLabel,
            modeCollectionView,
            analyzeButton,
            activityIndicator,
            fallbackBannerView,
            staleLabel,
            summaryCardView,
            tasteTitleLabel,
            tasteTagFlowView,
            errorContainerView,
            dailyLimitEmptyCardView,
            emptyStateView,
            resultTitleLabel,
            tableView
        ])
        contentStackView.axis = .vertical
        contentStackView.spacing = 14
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentStackView)

        let tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        self.tableHeightConstraint = tableHeightConstraint

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            queryTextView.heightAnchor.constraint(equalToConstant: 104),
            placeholderLabel.topAnchor.constraint(equalTo: queryTextView.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: queryTextView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(equalTo: queryTextView.trailingAnchor, constant: -16),
            modeCollectionView.heightAnchor.constraint(equalToConstant: 38),
            analyzeButton.heightAnchor.constraint(equalToConstant: 46),

            fallbackBannerLabel.topAnchor.constraint(equalTo: fallbackBannerView.topAnchor, constant: 12),
            fallbackBannerLabel.leadingAnchor.constraint(equalTo: fallbackBannerView.leadingAnchor, constant: 14),
            fallbackBannerLabel.trailingAnchor.constraint(equalTo: fallbackBannerView.trailingAnchor, constant: -14),
            fallbackBannerLabel.bottomAnchor.constraint(equalTo: fallbackBannerView.bottomAnchor, constant: -12),

            dailyLimitEmptyStackView.topAnchor.constraint(equalTo: dailyLimitEmptyCardView.topAnchor, constant: 18),
            dailyLimitEmptyStackView.leadingAnchor.constraint(equalTo: dailyLimitEmptyCardView.leadingAnchor, constant: 18),
            dailyLimitEmptyStackView.trailingAnchor.constraint(equalTo: dailyLimitEmptyCardView.trailingAnchor, constant: -18),
            dailyLimitEmptyStackView.bottomAnchor.constraint(equalTo: dailyLimitEmptyCardView.bottomAnchor, constant: -18),

            summaryStackView.topAnchor.constraint(equalTo: summaryCardView.topAnchor, constant: 16),
            summaryStackView.leadingAnchor.constraint(equalTo: summaryCardView.leadingAnchor, constant: 16),
            summaryStackView.trailingAnchor.constraint(equalTo: summaryCardView.trailingAnchor, constant: -16),
            summaryStackView.bottomAnchor.constraint(equalTo: summaryCardView.bottomAnchor, constant: -16),

            errorStackView.topAnchor.constraint(equalTo: errorContainerView.topAnchor, constant: 18),
            errorStackView.leadingAnchor.constraint(equalTo: errorContainerView.leadingAnchor, constant: 16),
            errorStackView.trailingAnchor.constraint(equalTo: errorContainerView.trailingAnchor, constant: -16),
            errorStackView.bottomAnchor.constraint(equalTo: errorContainerView.bottomAnchor, constant: -18),
            retryButton.heightAnchor.constraint(equalToConstant: 34),
            tableHeightConstraint
        ])

        applyInitialEmptyRenderingState()
        applyCurrentAnalyzeButtonConfiguration()
    }

    private func applyInitialEmptyRenderingState() {
        queryHelperLabel.isHidden = true
        fallbackBannerView.isHidden = true
        dailyLimitEmptyCardView.isHidden = true
        resetSummaryCard()
        tasteTitleLabel.isHidden = true
        tasteTagFlowView.isHidden = true
        errorContainerView.isHidden = true
        emptyStateView.configure(icon: "sparkles", message: nil)
        emptyStateView.isHidden = true
        resultTitleLabel.isHidden = true
        tableView.isHidden = true
        tableHeightConstraint?.constant = 0
        activityIndicator.stopAnimating()
    }

    private func resetSummaryCard() {
        summaryTitleLabel.text = nil
        summaryTitleLabel.isHidden = true
        summaryBodyLabel.text = nil
        summaryBodyLabel.isHidden = true
        summaryBulletsLabel.text = nil
        summaryBulletsLabel.isHidden = true
        summaryCardView.isHidden = true
    }

    private func applyAnalyzeButton(
        style: LibraryCuratorAnalyzeButtonStyle,
        title: String,
        iconName: String,
        isActionEnabled: Bool
    ) {
        analyzeButtonPresentation = AnalyzeButtonPresentation(
            style: style,
            title: title.nilIfBlankForCuratorUI ?? L10n.tr("Localizable", "library_curator_analyze_button"),
            iconName: iconName.nilIfBlankForCuratorUI ?? "sparkles",
            isActionEnabled: isActionEnabled
        )
        applyCurrentAnalyzeButtonConfiguration()
    }

    private func applyCurrentAnalyzeButtonConfiguration() {
        guard !isApplyingAnalyzeButtonConfiguration else { return }
        isApplyingAnalyzeButtonConfiguration = true
        defer { isApplyingAnalyzeButtonConfiguration = false }

        let colors = analyzeButtonColors(for: analyzeButtonPresentation.style)
        var configuration = UIButton.Configuration.filled()
        var attributedTitle = AttributedString(analyzeButtonPresentation.title)
        attributedTitle.font = .systemFont(ofSize: 17, weight: .semibold)
        attributedTitle.foregroundColor = colors.foreground
        configuration.attributedTitle = attributedTitle
        configuration.image = UIImage(systemName: analyzeButtonPresentation.iconName)?
            .withTintColor(colors.foreground, renderingMode: .alwaysOriginal)
        configuration.imagePadding = 8
        configuration.imagePlacement = .leading
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18)
        configuration.baseBackgroundColor = colors.background
        configuration.baseForegroundColor = colors.foreground
        configuration.cornerStyle = .capsule
        configuration.background.backgroundColor = colors.background
        configuration.background.strokeColor = .clear
        configuration.background.backgroundColorTransformer = UIConfigurationColorTransformer { _ in
            colors.background
        }
        configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in
            colors.foreground
        }

        analyzeButton.configuration = configuration
        analyzeButton.backgroundColor = colors.background
        analyzeButton.tintColor = colors.foreground
        analyzeButton.isEnabled = analyzeButtonPresentation.isActionEnabled
        analyzeButton.isUserInteractionEnabled = analyzeButtonPresentation.isActionEnabled
        analyzeButton.alpha = 1
        analyzeButton.titleLabel?.alpha = 1
        analyzeButton.imageView?.alpha = 1
        analyzeButton.accessibilityLabel = analyzeButtonPresentation.title
        analyzeButton.accessibilityTraits = analyzeButtonPresentation.isActionEnabled ? [.button] : [.button, .notEnabled]
    }

    private func applyVisibility(
        state: LibraryCuratorViewState,
        visibleSummary: LibraryCuratorSummaryViewState?,
        visibleTasteProfile: [String],
        visibleRecommendations: [LibraryCuratorSectionViewState]
    ) {
        let showsSummary = visibleSummary != nil
        let showsTaste = !visibleTasteProfile.isEmpty
        let showsRecommendations = !visibleRecommendations.isEmpty && state.errorMessage == nil

        summaryCardView.isHidden = !showsSummary
        tasteTitleLabel.isHidden = !showsTaste
        tasteTagFlowView.isHidden = !showsTaste
        resultTitleLabel.isHidden = !showsRecommendations
        tableView.isHidden = !showsRecommendations
        emptyStateView.isHidden = !state.shouldShowEmptyState

        if !showsRecommendations {
            tableHeightConstraint?.constant = 0
        }
    }

    private func analyzeButtonColors(
        for style: LibraryCuratorAnalyzeButtonStyle
    ) -> (background: UIColor, foreground: UIColor, backgroundLogName: String, foregroundLogName: String) {
        switch style {
        case .idle:
            return (.gpPrimary, .gpOnPrimary, "accentPurple", "white")
        case .loading:
            return (UIColor.gpPrimary.withAlphaComponent(0.82), UIColor.gpOnPrimary.withAlphaComponent(0.92), "accentPurpleAlpha", "white")
        case .dailyLimitExceeded:
            return (.gpSurface, UIColor.gpTextSecondary.withAlphaComponent(0.82), "disabledDark", "secondary")
        case .disabled:
            return (.gpSurface, UIColor.gpTextSecondary.withAlphaComponent(0.82), "disabledDark", "secondary")
        case .retryableError:
            return (.gpPrimary, .gpOnPrimary, "accentPurple", "white")
        }
    }

    private func updateScrollInsets() {
        let bottomInset = max(baseBottomInset, keyboardBottomInset, 24) + 12
        scrollView.contentInset.bottom = bottomInset
        scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
    }

#if DEBUG
    private func logRender(
        state: LibraryCuratorViewState,
        visibleSummary: LibraryCuratorSummaryViewState?,
        visibleTasteProfile: [String],
        visibleRecommendations: [LibraryCuratorSectionViewState]
    ) {
        let buttonState: String
        switch state.analyzeButtonStyle {
        case .idle:
            buttonState = "normal"
        case .loading:
            buttonState = "loading"
        case .dailyLimitExceeded:
            buttonState = "dailyLimitExceeded"
        case .disabled:
            buttonState = "disabled"
        case .retryableError:
            buttonState = "retryableError"
        }
        let colors = analyzeButtonColors(for: state.analyzeButtonStyle)
        let buttonKey = "\(buttonState)|\(state.analyzeButtonTitle)|\(colors.backgroundLogName)|\(colors.foregroundLogName)|\(state.canAnalyze)"
        if buttonKey != lastLoggedButtonKey {
            lastLoggedButtonKey = buttonKey
            print(
                "[LibraryCuratorButton] apply " +
                "state=\(buttonState) " +
                "title=\(state.analyzeButtonTitle) " +
                "bg=\(colors.backgroundLogName) " +
                "fg=\(colors.foregroundLogName) " +
                "enabled=\(state.canAnalyze)"
            )
        }

        let hasCachedResult = state.hasDisplayableResult
        let dailyLimitKey = "\(state.dailyLimitPresentation.logName)|\(hasCachedResult)"
        if dailyLimitKey != lastLoggedDailyLimitKey {
            lastLoggedDailyLimitKey = dailyLimitKey
            print("[LibraryCuratorUI] renderDailyLimit presentation=\(state.dailyLimitPresentation.logName) hasCachedResult=\(hasCachedResult)")
        }

        let reason: String
        if state.isDailyLimitExceeded && hasCachedResult {
            reason = "cachedResultDailyLimit"
        } else if state.isDailyLimitExceeded {
            reason = "noResultDailyLimit"
        } else {
            reason = "normal"
        }
        let sectionKey = "\(visibleSummary != nil)|\(!visibleTasteProfile.isEmpty)|\(!visibleRecommendations.isEmpty)|\(reason)"
        if sectionKey != lastLoggedSectionVisibilityKey {
            lastLoggedSectionVisibilityKey = sectionKey
            print(
                "[LibraryCuratorUI] sectionVisibility " +
                "summary=\(visibleSummary != nil) " +
                "taste=\(!visibleTasteProfile.isEmpty) " +
                "recommendations=\(!visibleRecommendations.isEmpty) " +
                "reason=\(reason)"
            )
        }

        let applyVisibilityKey = [
            "\(state.shouldShowSummarySection)",
            "\(state.shouldShowTasteProfileSection)",
            "\(state.shouldShowRecommendationSection)",
            "\(state.shouldShowEmptyState)",
            "\(state.shouldShowDailyLimitBanner)"
        ].joined(separator: "|")
        if applyVisibilityKey != lastLoggedApplyVisibilityKey {
            lastLoggedApplyVisibilityKey = applyVisibilityKey
            print(
                "[LibraryCuratorUI] applyVisibility " +
                "summary=\(state.shouldShowSummarySection) " +
                "taste=\(state.shouldShowTasteProfileSection) " +
                "recommendations=\(state.shouldShowRecommendationSection) " +
                "empty=\(state.shouldShowEmptyState) " +
                "banner=\(state.shouldShowDailyLimitBanner)"
            )
            if !state.shouldShowSummarySection {
                print("[LibraryCuratorUI] skipCard name=summary reason=noMeaningfulContent")
            }
            if !state.shouldShowTasteProfileSection {
                print("[LibraryCuratorUI] skipSection name=taste reason=noTags")
            }
            if !state.shouldShowRecommendationSection {
                print("[LibraryCuratorUI] skipSection name=recommendations reason=noItems")
            }
        }
    }
#endif
}

private extension Optional where Wrapped == String {
    var nilIfBlankForCuratorUI: String? {
        guard let value = self?.nilIfBlankForCuratorUI else { return nil }
        return value
    }
}

private extension String {
    var nilIfBlankForCuratorUI: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
