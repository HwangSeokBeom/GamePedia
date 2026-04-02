import UIKit

final class LibraryRootView: UIView {
    private struct LibrarySummaryMetrics {
        let primaryTitle: String
        let totalPlaytimeText: String
        let averageRatingText: String
        let gameCountText: String
        let rawReviewsCount: Int
        let rawAverageRating: Double?
        let sourceDescription: String
    }

    var onPrimaryTabSelected: ((Int) -> Void)?
    var onFilterSelected: ((Int) -> Void)?
    var onSteamPrimaryActionTapped: (() -> Void)?
    var onSteamSecondaryActionTapped: (() -> Void)?
    var onOwnedSummaryTapped: (() -> Void)?
    var onPlayingSummaryTapped: (() -> Void)?
    var onRecommendationSummaryTapped: (() -> Void)?

    private let topContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let primaryTabContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.26).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let primaryTabStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let summaryStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let totalPlaySummaryView = LibrarySummaryMetricView()
    private let averageRatingSummaryView = LibrarySummaryMetricView()
    private let gameCountSummaryView = LibrarySummaryMetricView()

    private let steamCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.26).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let steamCardTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 1
        return label
    }()

    private let steamLastSyncLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 1
        return label
    }()

    private let steamConnectionIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(
            systemName: "link.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        )
        imageView.tintColor = .gpPrimaryLight
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let steamStatusDotView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 4
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let steamStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .gpTextPrimary
        label.numberOfLines = 1
        return label
    }()

    private let steamCardMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        return label
    }()

    private let steamStatusContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.03)
        view.layer.cornerRadius = 12
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.2).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let steamPrimaryButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let steamSecondaryButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .gpTextSecondary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let steamTextStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let steamButtonRowView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let steamTopRowStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let steamConnectionTitleStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let steamStatusStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 6
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let steamContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let miniFilterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    let collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let loadingIndicatorView: UIActivityIndicatorView = {
        let indicatorView = UIActivityIndicatorView(style: .large)
        indicatorView.color = .gpPrimary
        indicatorView.hidesWhenStopped = true
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        return indicatorView
    }()

    private var primaryTabButtons: [LibraryPillButton] = []
    private var filterButtons: [LibraryPillButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupLayout()
    }

    func setCollectionViewLayout(_ layout: UICollectionViewLayout) {
        collectionView.setCollectionViewLayout(layout, animated: false)
    }

    func render(_ state: LibraryState) {
        setSelectedPrimaryTab(tab: state.selectedTab)
        let summaryMetrics = summaryMetrics(for: state)

        print(
            "[LibrarySummaryUI] " +
            "selectedTab=\(state.selectedTab) " +
            "gameCount=\(summaryMetrics.gameCountText) " +
            "totalPlaytimeHours=\(summaryMetrics.totalPlaytimeText) " +
            "source=\(summaryMetrics.sourceDescription)"
        )

        totalPlaySummaryView.configure(
            value: summaryMetrics.totalPlaytimeText,
            title: summaryMetrics.primaryTitle,
            valueColor: .gpTeal
        )
        averageRatingSummaryView.configure(
            value: summaryMetrics.averageRatingText,
            title: "평균 평점",
            valueColor: .gpPrimaryLight
        )
        gameCountSummaryView.configure(
            value: summaryMetrics.gameCountText,
            title: "게임 수",
            valueColor: .gpCoral
        )

        setSelectedHighlightChip(chip: state.selectedHighlightChip)
        configureSteamCard(with: state)
        loadingIndicatorView.stopAnimating()
        logSummaryMetrics(summaryMetrics, for: state)
    }

    private func setSelectedPrimaryTab(tab: LibraryTab) {
        primaryTabButtons.enumerated().forEach { index, button in
            button.applyPrimaryTabStyle(isSelected: index == tab.rawValue)
        }
    }

    private func setSelectedHighlightChip(chip: LibraryHighlightChip) {
        filterButtons.enumerated().forEach { index, button in
            button.applySecondaryChipStyle(isSelected: index == chip.rawValue)
        }
    }

    private func setupView() {
        backgroundColor = .gpBackground

        [totalPlaySummaryView, averageRatingSummaryView, gameCountSummaryView].forEach {
            $0.isUserInteractionEnabled = false
            summaryStackView.addArrangedSubview($0)
        }

        [steamCardTitleLabel, steamLastSyncLabel].forEach { steamConnectionTitleStackView.addArrangedSubview($0) }
        [steamStatusDotView, steamStatusLabel].forEach { steamStatusStackView.addArrangedSubview($0) }
        steamStatusContainerView.addSubview(steamStatusStackView)
        [steamConnectionIconView, steamConnectionTitleStackView, UIView(), steamStatusContainerView].forEach {
            steamTopRowStackView.addArrangedSubview($0)
        }

        [UIView(), steamPrimaryButton, steamSecondaryButton].forEach { steamButtonRowView.addArrangedSubview($0) }
        [steamTopRowStackView, steamCardMessageLabel, steamButtonRowView].forEach { steamContentStackView.addArrangedSubview($0) }
        steamCardView.addSubview(steamContentStackView)

        [primaryTabContainerView, summaryStackView, steamCardView, miniFilterStackView].forEach {
            topContentStackView.addArrangedSubview($0)
        }

        [primaryTabStackView].forEach { primaryTabContainerView.addSubview($0) }
        [topContentStackView, collectionView, loadingIndicatorView].forEach { addSubview($0) }

        ["플레이함", "찜한 게임", "리뷰 작성함"].enumerated().forEach { index, title in
            let button = LibraryPillButton(title: title)
            button.tag = index
            button.addTarget(self, action: #selector(didTapPrimaryTab(_:)), for: .touchUpInside)
            primaryTabButtons.append(button)
            primaryTabStackView.addArrangedSubview(button)
        }

        ["최근 플레이", "평점순", "플레이 시간순"].enumerated().forEach { index, title in
            let button = LibraryPillButton(title: title)
            button.tag = index
            button.addTarget(self, action: #selector(didTapFilter(_:)), for: .touchUpInside)
            filterButtons.append(button)
            miniFilterStackView.addArrangedSubview(button)
        }

        steamPrimaryButton.addTarget(self, action: #selector(didTapSteamPrimaryAction), for: .touchUpInside)
        steamSecondaryButton.addTarget(self, action: #selector(didTapSteamSecondaryAction), for: .touchUpInside)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            topContentStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 0),
            topContentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            topContentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            primaryTabStackView.topAnchor.constraint(equalTo: primaryTabContainerView.topAnchor, constant: 6),
            primaryTabStackView.leadingAnchor.constraint(equalTo: primaryTabContainerView.leadingAnchor, constant: 6),
            primaryTabStackView.trailingAnchor.constraint(equalTo: primaryTabContainerView.trailingAnchor, constant: -6),
            primaryTabStackView.bottomAnchor.constraint(equalTo: primaryTabContainerView.bottomAnchor, constant: -6),

            steamContentStackView.topAnchor.constraint(equalTo: steamCardView.topAnchor, constant: 16),
            steamContentStackView.leadingAnchor.constraint(equalTo: steamCardView.leadingAnchor, constant: 16),
            steamContentStackView.trailingAnchor.constraint(equalTo: steamCardView.trailingAnchor, constant: -16),
            steamContentStackView.bottomAnchor.constraint(equalTo: steamCardView.bottomAnchor, constant: -16),

            steamConnectionIconView.widthAnchor.constraint(equalToConstant: 20),
            steamConnectionIconView.heightAnchor.constraint(equalToConstant: 20),
            steamStatusDotView.widthAnchor.constraint(equalToConstant: 8),
            steamStatusDotView.heightAnchor.constraint(equalToConstant: 8),
            steamStatusStackView.topAnchor.constraint(equalTo: steamStatusContainerView.topAnchor, constant: 6),
            steamStatusStackView.leadingAnchor.constraint(equalTo: steamStatusContainerView.leadingAnchor, constant: 10),
            steamStatusStackView.trailingAnchor.constraint(equalTo: steamStatusContainerView.trailingAnchor, constant: -10),
            steamStatusStackView.bottomAnchor.constraint(equalTo: steamStatusContainerView.bottomAnchor, constant: -6),

            steamPrimaryButton.heightAnchor.constraint(equalToConstant: 36),
            steamPrimaryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112),
            steamSecondaryButton.heightAnchor.constraint(equalToConstant: 36),

            collectionView.topAnchor.constraint(equalTo: topContentStackView.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),

            miniFilterStackView.heightAnchor.constraint(greaterThanOrEqualToConstant: 34)
        ])
    }

    private func configureSteamCard(with state: LibraryState) {
        let statusPresentation = steamStatusPresentation(for: state)
        steamStatusDotView.backgroundColor = statusPresentation.color
        steamStatusLabel.text = statusPresentation.text

        if state.isSteamConnected {
            steamCardTitleLabel.text = "Steam 연동됨"
            steamLastSyncLabel.text = lastSyncText(for: state)
            if state.isSyncingOwnedSteamLibrary {
                steamCardMessageLabel.text = "최근 플레이와 보유 게임을 새로 가져오는 중이에요."
            } else {
                steamCardMessageLabel.text = "최근 플레이, 보유 게임, 리뷰 후보를 자동으로 정리해 더 개인적인 라이브러리를 완성할 수 있어요."
            }
            var configuration = steamPrimaryButton.configuration
            configuration?.title = state.isSyncingOwnedSteamLibrary ? "가져오는 중..." : "보관함 동기화"
            configuration?.showsActivityIndicator = state.isSyncingOwnedSteamLibrary
            steamPrimaryButton.configuration = configuration
            steamPrimaryButton.isEnabled = state.steamLinkStatus.canSync && !state.isSyncingOwnedSteamLibrary
            steamPrimaryButton.alpha = steamPrimaryButton.isEnabled ? 1.0 : 0.7

            var secondaryConfiguration = UIButton.Configuration.plain()
            secondaryConfiguration.baseForegroundColor = .systemRed
            secondaryConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            secondaryConfiguration.title = "연결 해제"
            secondaryConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
                return attributes
            }
            steamSecondaryButton.configuration = secondaryConfiguration
            steamSecondaryButton.isHidden = !state.steamLinkStatus.canDisconnect
            steamSecondaryButton.isEnabled = state.steamLinkStatus.canDisconnect && !state.isUnlinkingSteamAccount
            steamSecondaryButton.alpha = steamSecondaryButton.isEnabled ? 1.0 : 0.6
        } else {
            steamCardTitleLabel.text = "Steam 연동 안내"
            steamLastSyncLabel.text = "Steam 계정을 연결하면 자동 정리를 시작할 수 있어요"
            steamCardMessageLabel.text = "최근 플레이, 보유 게임, 리뷰 후보를 자동으로 정리해 더 개인적인 라이브러리를 완성할 수 있어요."
            var configuration = steamPrimaryButton.configuration
            configuration?.title = "Steam 연결"
            configuration?.showsActivityIndicator = false
            steamPrimaryButton.configuration = configuration
            steamPrimaryButton.isEnabled = true
            steamPrimaryButton.alpha = 1.0
            steamSecondaryButton.isHidden = true
        }
    }

    private func lastSyncText(for state: LibraryState) -> String {
        guard let lastSteamSyncAt = state.steamLinkStatus.lastSteamSyncAt else {
            return "마지막 동기화: 아직 기록이 없어요"
        }

        if abs(lastSteamSyncAt.timeIntervalSinceNow) < 60 {
            return "마지막 동기화: 방금 전"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .short
        return "마지막 동기화: \(formatter.localizedString(for: lastSteamSyncAt, relativeTo: Date()))"
    }

    private func steamStatusPresentation(for state: LibraryState) -> (text: String, color: UIColor) {
        if state.isSyncingOwnedSteamLibrary || state.steamSyncStatus == .syncing {
            return ("동기화 중", .gpPrimary)
        }

        if state.steamSyncErrorCode != nil || state.steamSyncStatus == .failed || state.steamSyncStatus == .privateProfile || state.steamSyncStatus == .tokenExpired {
            return ("오류", .systemRed)
        }

        if state.isSteamConnected {
            return ("연동됨", .systemGreen)
        }

        return ("미연동", .gpTextTertiary)
    }

    private func summaryMetrics(for state: LibraryState) -> LibrarySummaryMetrics {
        let summaryState = state.summaryByTab[state.selectedTab] ?? .empty(for: state.selectedTab)
        return LibrarySummaryMetrics(
            primaryTitle: summaryState.primaryTitle,
            totalPlaytimeText: formattedPrimaryValueText(summaryState),
            averageRatingText: formattedAverageRatingText(
                summaryState.averageRating,
                reviewCount: summaryState.reviewCount
            ),
            gameCountText: Self.numberFormatter.string(from: NSNumber(value: summaryState.gameCount)) ?? "\(summaryState.gameCount)",
            rawReviewsCount: summaryState.reviewCount,
            rawAverageRating: summaryState.averageRating,
            sourceDescription: summaryState.sourceDescription
        )
    }

    private func formattedPrimaryValueText(_ summaryState: LibraryTabSummaryState) -> String {
        switch summaryState.primaryValueKind {
        case .hours:
            if summaryState.primaryValue.rounded(.towardZero) == summaryState.primaryValue {
                return "\(Self.numberFormatter.string(from: NSNumber(value: Int(summaryState.primaryValue))) ?? "\(Int(summaryState.primaryValue))")h"
            }
            return "\(String(format: "%.1f", summaryState.primaryValue))h"
        case .count:
            return Self.numberFormatter.string(from: NSNumber(value: Int(summaryState.primaryValue))) ?? "\(Int(summaryState.primaryValue))"
        }
    }

    private func formattedAverageRatingText(_ rating: Double?, reviewCount: Int) -> String {
        guard reviewCount > 0, let rating, rating.isFinite else { return "—" }
        return String(format: "%.1f", rating)
    }

    private func logSummaryMetrics(_ summaryMetrics: LibrarySummaryMetrics, for state: LibraryState) {
        let rawAverageRatingText = summaryMetrics.rawAverageRating.map { String(format: "%.2f", $0) } ?? "nil"

        print(
            "[LibrarySummary] " +
            "selectedTab=\(state.selectedTab) " +
            "rawReviewsCount=\(summaryMetrics.rawReviewsCount) " +
            "rawAverageRating=\(rawAverageRatingText) " +
            "mappedAverageRatingText=\(summaryMetrics.averageRatingText) " +
            "finalTotalPlaytime=\(summaryMetrics.totalPlaytimeText) " +
            "finalGameCount=\(summaryMetrics.gameCountText) " +
            "source=\(summaryMetrics.sourceDescription)"
        )
    }

    @objc
    private func didTapPrimaryTab(_ sender: UIButton) {
        guard let selectedTab = LibraryTab(rawValue: sender.tag) else { return }
        setSelectedPrimaryTab(tab: selectedTab)
        onPrimaryTabSelected?(sender.tag)
    }

    @objc
    private func didTapFilter(_ sender: UIButton) {
        guard let chip = LibraryHighlightChip(rawValue: sender.tag) else { return }
        setSelectedHighlightChip(chip: chip)
        onFilterSelected?(sender.tag)
    }

    @objc
    private func didTapSteamPrimaryAction() {
        onSteamPrimaryActionTapped?()
    }

    @objc
    private func didTapSteamSecondaryAction() {
        onSteamSecondaryActionTapped?()
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

private final class LibraryPillButton: UIButton {

    init(title: String) {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ])
        )
        self.configuration = configuration
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPrimaryTabStyle(isSelected: Bool) {
        backgroundColor = isSelected ? .gpPrimary : .clear
        layer.borderColor = (isSelected ? UIColor.gpPrimary : UIColor.clear).cgColor
        var configuration = configuration
        configuration?.baseForegroundColor = isSelected ? .gpOnPrimary : .gpTextSecondary
        self.configuration = configuration
    }

    func applySecondaryChipStyle(isSelected: Bool) {
        backgroundColor = isSelected ? UIColor.gpPrimary.withAlphaComponent(0.14) : .clear
        layer.borderColor = (isSelected ? UIColor.gpPrimary.withAlphaComponent(0.18) : UIColor.gpSeparator.withAlphaComponent(0.22)).cgColor
        var configuration = configuration
        configuration?.baseForegroundColor = isSelected ? .gpPrimaryLight : .gpTextSecondary
        self.configuration = configuration
    }
}

private final class LibrarySummaryMetricView: UIView {

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 19, weight: .bold)
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(value: String, title: String, valueColor: UIColor) {
        valueLabel.text = value
        valueLabel.textColor = valueColor
        titleLabel.text = title
    }

    private func setup() {
        backgroundColor = .gpCardBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.24).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13)
        ])
    }
}

private final class PaddingLabel: UILabel {

    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
