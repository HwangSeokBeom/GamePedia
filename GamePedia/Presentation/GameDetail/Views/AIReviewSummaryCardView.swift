import UIKit

final class AIReviewSummaryCardView: UIView {
    var onRetryTapped: (() -> Void)?
    var onExpandTapped: (() -> Void)?

    private let headerIconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let generatedAtLabel = UILabel()
    private let activityIndicatorView = UIActivityIndicatorView(style: .medium)
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let summaryLabel = UILabel()
    private let keywordFlowView = ChipFlowView()
    private let prosSectionView = BulletSectionView()
    private let consSectionView = BulletSectionView()
    private let recommendedSectionView = BulletSectionView()
    private let notRecommendedSectionView = BulletSectionView()
    private let disclaimerLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let bodyStackView = UIStackView()
    private let statusStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
    }

    func render(_ state: AIReviewSummarySectionState) {
        switch state {
        case .idle:
            isHidden = true
        case .loading:
            isHidden = false
            renderLoading()
        case .loaded(let viewState):
            isHidden = false
            renderLoaded(viewState)
        case .unavailable(let message):
            isHidden = false
            renderStatus(message: message, showsRetry: false)
        case .error(let message):
            isHidden = false
            renderStatus(message: message, showsRetry: true)
        }
    }

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.gpBorder.resolvedCGColor(with: traitCollection)
        translatesAutoresizingMaskIntoConstraints = false

        headerIconView.image = UIImage(
            systemName: "sparkles",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        )
        headerIconView.tintColor = .gpPrimary
        headerIconView.contentMode = .scaleAspectFit
        headerIconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .gpTextPrimary

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = .gpTextSecondary
        subtitleLabel.numberOfLines = 1

        generatedAtLabel.font = .systemFont(ofSize: 12, weight: .medium)
        generatedAtLabel.textColor = .gpTextSecondary
        generatedAtLabel.numberOfLines = 1

        activityIndicatorView.color = .gpPrimary
        activityIndicatorView.hidesWhenStopped = true

        summaryLabel.font = .systemFont(ofSize: 14)
        summaryLabel.textColor = .gpTextPrimary
        summaryLabel.numberOfLines = 3

        disclaimerLabel.font = .systemFont(ofSize: 11)
        disclaimerLabel.textColor = .gpTextTertiary
        disclaimerLabel.numberOfLines = 0

        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .gpTextSecondary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        var retryConfiguration = UIButton.Configuration.plain()
        retryConfiguration.title = "다시 시도"
        retryConfiguration.image = UIImage(systemName: "arrow.clockwise")
        retryConfiguration.imagePadding = 6
        retryConfiguration.baseForegroundColor = .gpPrimary
        retryButton.configuration = retryConfiguration
        retryButton.addTarget(self, action: #selector(didTapRetry), for: .touchUpInside)

        var expandConfiguration = UIButton.Configuration.plain()
        expandConfiguration.contentInsets = .zero
        expandConfiguration.baseForegroundColor = .gpPrimary
        expandButton.configuration = expandConfiguration
        expandButton.contentHorizontalAlignment = .leading
        expandButton.addTarget(self, action: #selector(didTapExpand), for: .touchUpInside)

        bodyStackView.axis = .vertical
        bodyStackView.spacing = 14
        bodyStackView.addArrangedSubview(summaryLabel)
        bodyStackView.addArrangedSubview(keywordFlowView)
        bodyStackView.addArrangedSubview(prosSectionView)
        bodyStackView.addArrangedSubview(consSectionView)
        bodyStackView.addArrangedSubview(recommendedSectionView)
        bodyStackView.addArrangedSubview(notRecommendedSectionView)
        bodyStackView.addArrangedSubview(disclaimerLabel)
        bodyStackView.addArrangedSubview(expandButton)

        statusStackView.axis = .vertical
        statusStackView.alignment = .center
        statusStackView.spacing = 8
        statusStackView.addArrangedSubview(statusLabel)
        statusStackView.addArrangedSubview(retryButton)

        let titleStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, generatedAtLabel])
        titleStackView.axis = .vertical
        titleStackView.spacing = 3

        let headerStackView = UIStackView(arrangedSubviews: [
            headerIconView,
            titleStackView,
            UIView(),
            activityIndicatorView
        ])
        headerStackView.axis = .horizontal
        headerStackView.alignment = .top
        headerStackView.spacing = 10

        let contentStackView = UIStackView(arrangedSubviews: [headerStackView, bodyStackView, statusStackView])
        contentStackView.axis = .vertical
        contentStackView.spacing = 14
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentStackView)
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),

            headerIconView.widthAnchor.constraint(equalToConstant: 20),
            headerIconView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func renderLoading() {
        titleLabel.text = "AI 리뷰 요약"
        subtitleLabel.text = "리뷰를 분석하는 중"
        generatedAtLabel.isHidden = true
        bodyStackView.isHidden = true
        statusStackView.isHidden = false
        statusLabel.text = "AI가 사용자 리뷰를 분석하고 있어요."
        retryButton.isHidden = true
        activityIndicatorView.startAnimating()
        accessibilityLabel = "AI 리뷰 요약, 리뷰를 분석하는 중"
    }

    private func renderLoaded(_ state: AIReviewSummaryViewState) {
        titleLabel.text = state.title
        subtitleLabel.text = state.subtitle
        generatedAtLabel.text = state.generatedAtText
        generatedAtLabel.isHidden = state.generatedAtText == nil
        bodyStackView.isHidden = false
        statusStackView.isHidden = true
        activityIndicatorView.stopAnimating()

        summaryLabel.text = state.summary
        summaryLabel.numberOfLines = state.isExpanded ? 0 : 3
        keywordFlowView.configure(keywords: state.visibleKeywords)
        keywordFlowView.isHidden = state.visibleKeywords.isEmpty
        prosSectionView.configure(title: "장점", items: state.visiblePros)
        consSectionView.configure(title: "단점", items: state.visibleCons)
        recommendedSectionView.configure(title: "추천 대상", items: state.visibleRecommendedFor)
        notRecommendedSectionView.configure(title: "주의 대상", items: state.visibleNotRecommendedFor)
        disclaimerLabel.text = state.disclaimer

        var expandConfiguration = expandButton.configuration
        expandConfiguration?.title = state.isExpanded ? "접기" : "더보기"
        expandButton.configuration = expandConfiguration
        expandButton.isHidden = !state.isExpandable
        expandButton.accessibilityLabel = state.isExpanded ? "AI 리뷰 요약 접기" : "AI 리뷰 요약 더보기"

        titleLabel.accessibilityLabel = state.title
        summaryLabel.accessibilityLabel = "요약, \(state.summary)"
        prosSectionView.accessibilityLabel = "장점, \(state.pros.joined(separator: ", "))"
        consSectionView.accessibilityLabel = "단점, \(state.cons.joined(separator: ", "))"
        accessibilityLabel = [
            state.title,
            state.subtitle,
            state.summary,
            state.pros.joined(separator: ", "),
            state.cons.joined(separator: ", ")
        ].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func renderStatus(message: String, showsRetry: Bool) {
        titleLabel.text = "AI 리뷰 요약"
        subtitleLabel.text = "리뷰 분석"
        generatedAtLabel.isHidden = true
        bodyStackView.isHidden = true
        statusStackView.isHidden = false
        statusLabel.text = message
        retryButton.isHidden = !showsRetry
        activityIndicatorView.stopAnimating()
        retryButton.accessibilityLabel = "AI 리뷰 요약 다시 시도"
        accessibilityLabel = "AI 리뷰 요약, \(message)"
    }

    @objc private func didTapRetry() {
        onRetryTapped?()
    }

    @objc private func didTapExpand() {
        onExpandTapped?()
    }
}

private final class BulletSectionView: UIView {
    private let titleLabel = UILabel()
    private let itemStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(title: String, items: [String]) {
        titleLabel.text = title
        itemStackView.removeAllArrangedSubviews()
        isHidden = items.isEmpty

        items.forEach { item in
            let label = UILabel()
            label.font = .systemFont(ofSize: 13)
            label.textColor = .gpTextSecondary
            label.numberOfLines = 0
            label.text = "• \(item)"
            itemStackView.addArrangedSubview(label)
        }

        accessibilityLabel = "\(title), \(items.joined(separator: ", "))"
    }

    private func setup() {
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .gpTextPrimary

        itemStackView.axis = .vertical
        itemStackView.spacing = 6

        let stackView = UIStackView(arrangedSubviews: [titleLabel, itemStackView])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private final class ChipFlowView: UIView {
    private var chipLabels: [KeywordChipLabel] = []

    func configure(keywords: [String]) {
        chipLabels.forEach { $0.removeFromSuperview() }
        chipLabels = keywords.map { keyword in
            let label = KeywordChipLabel()
            label.text = keyword
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.textColor = .gpPrimary
            label.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.12)
            label.layer.cornerRadius = 12
            label.layer.cornerCurve = .continuous
            label.layer.masksToBounds = true
            label.accessibilityLabel = keyword
            addSubview(label)
            return label
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutChips(width: bounds.width, shouldApplyFrames: true)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: layoutChips(width: resolvedLayoutWidth, shouldApplyFrames: false))
    }

    private var resolvedLayoutWidth: CGFloat {
        bounds.width > 0 ? bounds.width : max(1, UIScreen.main.bounds.width - 72)
    }

    private func layoutChips(width: CGFloat, shouldApplyFrames: Bool) -> CGFloat {
        let availableWidth = max(width, 1)
        let horizontalSpacing: CGFloat = 6
        let verticalSpacing: CGFloat = 6
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for label in chipLabels {
            let fittingSize = label.intrinsicContentSize
            let chipWidth = min(fittingSize.width, availableWidth)
            let chipHeight = fittingSize.height

            if x > 0, x + chipWidth > availableWidth {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            if shouldApplyFrames {
                label.frame = CGRect(x: x, y: y, width: chipWidth, height: chipHeight)
            }

            x += chipWidth + horizontalSpacing
            rowHeight = max(rowHeight, chipHeight)
        }

        return chipLabels.isEmpty ? 0 : y + rowHeight
    }
}

private final class KeywordChipLabel: UILabel {
    private let textInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }
}

private extension UIStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { view in
            removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}
