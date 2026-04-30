import UIKit

final class AISearchAssistView: UIView {
    let assistButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    let retryButton: UIButton = {
        let button = UIButton(configuration: .bordered())
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    var onSuggestedQueryTapped: ((String) -> Void)?
    var onItemTapped: ((Int) -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "AI 검색 보조"
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .gpTextPrimary
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 2
        return label
    }()

    private let fallbackLabel: UILabel = {
        let label = UILabel()
        label.text = "AI 응답 대신 기본 검색 기준으로 정렬했어요."
        label.font = .systemFont(ofSize: 12)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let noSearchResultsNoticeLabel: UILabel = {
        let label = UILabel()
        label.text = "일반 검색 결과는 없지만, AI가 추천한 게임이에요."
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpPrimaryLight
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let resultSummaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 1
        label.isHidden = true
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    private let disclaimerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .gpTextTertiary
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .gpTextSecondary
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let intentStackView = UIStackView()
    private let suggestedStackView = UIStackView()
    private let resultStackView = UIStackView()
    private let contentStackView = UIStackView()
    private var itemViewsByGameId: [Int: AISearchAssistResultCell] = [:]

    private enum Layout {
        static let cardContentHorizontalPadding: CGFloat = 16
        static let cardContentVerticalPadding: CGFloat = 18
        static let chipHeight: CGFloat = 34
        static let chipTrailingSpace: CGFloat = 12
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func render(_ state: AISearchAssistState) {
        isHidden = !state.shouldShowSection
        subtitleLabel.text = state.subtitleText
        fallbackLabel.isHidden = !state.fallbackUsed
        disclaimerLabel.text = state.disclaimer
        disclaimerLabel.isHidden = state.disclaimer?.isEmpty ?? true

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = state.isLoading ? "분석 중..." : "AI로 의도 분석하기"
        buttonConfiguration.image = UIImage(systemName: "sparkles")
        buttonConfiguration.imagePadding = 6
        buttonConfiguration.baseBackgroundColor = state.shouldShowCTA ? .gpPrimary : .gpSurface
        buttonConfiguration.baseForegroundColor = state.shouldShowCTA ? .gpOnPrimary : .gpTextTertiary
        buttonConfiguration.cornerStyle = .capsule
        assistButton.configuration = buttonConfiguration
        assistButton.isHidden = state.isLoading || !state.shouldShowCTA
        assistButton.isEnabled = state.shouldShowCTA

        var retryConfiguration = UIButton.Configuration.bordered()
        retryConfiguration.title = state.status == .unauthorized ? "로그인하기" : "다시 시도"
        retryConfiguration.baseForegroundColor = .gpPrimary
        retryConfiguration.cornerStyle = .capsule
        retryButton.configuration = retryConfiguration
        retryButton.isHidden = ![.error, .dailyLimitExceeded, .unauthorized, .empty].contains(state.status)

        if state.isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        renderStatus(state)
        configureChips(state.intentChips, in: intentStackView, style: .plain)
        configureChips(state.suggestedQueries, in: suggestedStackView, style: .suggested)
        configureItems(state.items)
    }

    func setShowsNoSearchResultsNotice(_ shouldShow: Bool) {
        noSearchResultsNoticeLabel.isHidden = !shouldShow
    }

    private func setup() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        [intentStackView, suggestedStackView, resultStackView, contentStackView].forEach {
            $0.axis = .vertical
            $0.spacing = 8
        }
        resultStackView.spacing = 24
        resultStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.spacing = 12
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        let headerStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        headerStackView.axis = .vertical
        headerStackView.spacing = 3

        let bodyView = UIView()
        bodyView.backgroundColor = .gpSurface.withAlphaComponent(0.72)
        bodyView.layer.cornerRadius = 12
        bodyView.clipsToBounds = true
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.addSubview(contentStackView)

        let controlsRow = UIStackView(arrangedSubviews: [assistButton, activityIndicator])
        controlsRow.axis = .horizontal
        controlsRow.spacing = 10
        controlsRow.alignment = .center

        contentStackView.addArrangedSubview(headerStackView)
        contentStackView.addArrangedSubview(noSearchResultsNoticeLabel)
        contentStackView.addArrangedSubview(controlsRow)
        contentStackView.addArrangedSubview(intentStackView)
        contentStackView.addArrangedSubview(suggestedStackView)
        contentStackView.addArrangedSubview(fallbackLabel)
        contentStackView.addArrangedSubview(statusLabel)
        contentStackView.addArrangedSubview(retryButton)
        contentStackView.addArrangedSubview(resultSummaryLabel)
        contentStackView.addArrangedSubview(resultStackView)
        contentStackView.addArrangedSubview(disclaimerLabel)

        addSubview(bodyView)

        let contentTopConstraint = contentStackView.topAnchor.constraint(equalTo: bodyView.topAnchor, constant: Layout.cardContentVerticalPadding)
        let contentBottomConstraint = contentStackView.bottomAnchor.constraint(equalTo: bodyView.bottomAnchor, constant: -Layout.cardContentVerticalPadding)
        contentTopConstraint.priority = UILayoutPriority(999)
        contentBottomConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            bodyView.topAnchor.constraint(equalTo: topAnchor),
            bodyView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bodyView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bodyView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentTopConstraint,
            contentStackView.leadingAnchor.constraint(equalTo: bodyView.leadingAnchor, constant: Layout.cardContentHorizontalPadding),
            contentStackView.trailingAnchor.constraint(equalTo: bodyView.trailingAnchor, constant: -Layout.cardContentHorizontalPadding),
            contentBottomConstraint,

            assistButton.heightAnchor.constraint(equalToConstant: 38),
            retryButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func renderStatus(_ state: AISearchAssistState) {
        switch state.status {
        case .loading:
            statusLabel.text = nil
            statusLabel.isHidden = true
        case .empty:
            statusLabel.text = state.errorMessage ?? "조건에 맞는 게임을 찾지 못했어요. 검색어를 조금 바꿔보세요."
            statusLabel.isHidden = false
        case .error, .dailyLimitExceeded, .unauthorized:
            if state.status == .unauthorized {
                statusLabel.text = "로그인이 필요해요. 로그인 후 AI 검색 보조를 사용할 수 있어요."
            } else if state.status == .error, !state.items.isEmpty {
                statusLabel.text = "새 AI 결과를 불러오지 못했어요. 이전 결과를 유지합니다."
            } else {
                statusLabel.text = state.errorMessage
            }
            statusLabel.isHidden = false
        default:
            statusLabel.text = nil
            statusLabel.isHidden = true
        }
    }

    private func configureChips(_ titles: [String], in stackView: UIStackView, style: AISearchAssistChipView.Style) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let maximumVisibleChipCount = style == .plain ? 5 : 3
        let visibleTitles = deduplicatedChipTitles(titles)
            .prefix(maximumVisibleChipCount)
            .map { $0 }

        guard !visibleTitles.isEmpty else {
            stackView.isHidden = true
            return
        }

        stackView.isHidden = false
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = true
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.spacing = 8
        rowStackView.alignment = .center
        rowStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(rowStackView)

        visibleTitles.forEach { title in
            let chip = AISearchAssistChipView(title: title, style: style)
            if style == .suggested {
                chip.addAction(UIAction { [weak self] _ in
                    self?.onSuggestedQueryTapped?(title)
                }, for: .touchUpInside)
            } else {
                chip.isUserInteractionEnabled = false
            }
            rowStackView.addArrangedSubview(chip)
        }

        let trailingSpacerView = UIView()
        trailingSpacerView.translatesAutoresizingMaskIntoConstraints = false
        trailingSpacerView.widthAnchor.constraint(equalToConstant: Layout.chipTrailingSpace).isActive = true
        rowStackView.addArrangedSubview(trailingSpacerView)

        stackView.addArrangedSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(equalToConstant: Layout.chipHeight),
            scrollView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            rowStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            rowStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            rowStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            rowStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            rowStackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    private func deduplicatedChipTitles(_ titles: [String]) -> [String] {
        var seen = Set<String>()
        return titles.compactMap { title in
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { return nil }

            let normalizedTitle = trimmedTitle.lowercased()
            guard seen.insert(normalizedTitle).inserted else { return nil }
            return trimmedTitle
        }
    }

    private func configureItems(_ items: [AISearchAssistItemViewState]) {
        itemViewsByGameId.values.forEach { $0.prepareForReuse() }
        resultStackView.arrangedSubviews.forEach {
            resultStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        itemViewsByGameId = [:]

        guard !items.isEmpty else {
            resultSummaryLabel.isHidden = true
            resultStackView.isHidden = true
            return
        }

        resultSummaryLabel.text = "AI 추천 \(items.count)개를 보여드려요."
        resultSummaryLabel.isHidden = false
        resultStackView.isHidden = false
        items.forEach { item in
            let itemView = AISearchAssistResultCell()
            itemView.configure(with: item)
            itemView.addAction(UIAction { [weak self] _ in
                self?.onItemTapped?(item.gameId)
            }, for: .touchUpInside)
            resultStackView.addArrangedSubview(itemView)
            itemViewsByGameId[item.gameId] = itemView
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }
}
