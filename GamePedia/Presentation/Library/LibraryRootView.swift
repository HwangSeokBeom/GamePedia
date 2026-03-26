import UIKit

final class LibraryRootView: UIView {

    var onTabSelected: ((Int) -> Void)?
    var onFilterSelected: ((Int) -> Void)?

    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 14
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isScrollEnabled = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 108, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 108, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
        let descriptor = baseDescriptor.withDesign(.serif) ?? baseDescriptor
        label.font = UIFont(descriptor: descriptor, size: 32)
        label.text = "내 라이브러리"
        label.textColor = .gpTextPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var headerRow: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [titleLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let tabsContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurface
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tabStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let statsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let filterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private var collectionHeightConstraint: NSLayoutConstraint!
    private var tabButtons: [LibraryPillButton] = []
    private var filterButtons: [LibraryPillButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
        configureSelections()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupLayout()
        configureSelections()
    }

    func setSelectedTab(index: Int) {
        tabButtons.enumerated().forEach { offset, button in
            button.applyStyle(
                isSelected: offset == index,
                selectedBackgroundColor: .gpPrimary,
                selectedTextColor: .white,
                normalBackgroundColor: .clear,
                normalTextColor: .gpTextSecondary,
                normalBorderColor: .clear
            )
        }
    }

    func setSelectedFilter(index: Int) {
        filterButtons.enumerated().forEach { offset, button in
            button.applyStyle(
                isSelected: offset == index,
                selectedBackgroundColor: UIColor.gpPrimary.withAlphaComponent(0.16),
                selectedTextColor: .gpPrimaryLight,
                normalBackgroundColor: .gpSurface,
                normalTextColor: .gpTextSecondary,
                normalBorderColor: .gpSeparator
            )
        }
    }

    func updateCollectionHeight() {
        layoutIfNeeded()
        collectionHeightConstraint.constant = collectionView.collectionViewLayout.collectionViewContentSize.height
    }

    func setUsesNavigationTitle(_ usesNavigationTitle: Bool) {
        titleLabel.isHidden = usesNavigationTitle
        headerRow.isHidden = usesNavigationTitle
    }

    private func setupView() {
        backgroundColor = UIColor(hex: "#0B0B0E")

        addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(headerRow)
        contentView.addSubview(tabsContainerView)
        tabsContainerView.addSubview(tabStackView)
        contentView.addSubview(statsStackView)
        contentView.addSubview(filterStackView)
        contentView.addSubview(collectionView)

        ["플레이중", "찜한 게임", "리뷰 작성함"].enumerated().forEach { index, title in
            let button = LibraryPillButton(title: title)
            button.tag = index
            button.addTarget(self, action: #selector(didTapTab(_:)), for: .touchUpInside)
            tabButtons.append(button)
            tabStackView.addArrangedSubview(button)
        }

        [
            LibraryStatCardView(value: "1,284h", subtitle: "총 플레이", accentColor: UIColor(hex: "#57F7B0")),
            LibraryStatCardView(value: "4.3", subtitle: "평균 평점", accentColor: UIColor(hex: "#FFB14A")),
            LibraryStatCardView(value: "142", subtitle: "게임 수", accentColor: .gpPrimaryLight)
        ].forEach { statsStackView.addArrangedSubview($0) }

        ["최근 플레이", "평점순", "플레이 시간순"].enumerated().forEach { index, title in
            let button = LibraryPillButton(title: title)
            button.tag = index
            button.addTarget(self, action: #selector(didTapFilter(_:)), for: .touchUpInside)
            filterButtons.append(button)
            filterStackView.addArrangedSubview(button)
        }

        collectionView.register(LibraryGameCardCell.self, forCellWithReuseIdentifier: LibraryGameCardCell.reuseId)
        collectionHeightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 420)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            headerRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            tabsContainerView.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 20),
            tabsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tabsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            tabStackView.topAnchor.constraint(equalTo: tabsContainerView.topAnchor, constant: 4),
            tabStackView.leadingAnchor.constraint(equalTo: tabsContainerView.leadingAnchor, constant: 4),
            tabStackView.trailingAnchor.constraint(equalTo: tabsContainerView.trailingAnchor, constant: -4),
            tabStackView.bottomAnchor.constraint(equalTo: tabsContainerView.bottomAnchor, constant: -4),

            statsStackView.topAnchor.constraint(equalTo: tabsContainerView.bottomAnchor, constant: 14),
            statsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            filterStackView.topAnchor.constraint(equalTo: statsStackView.bottomAnchor, constant: 14),
            filterStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            filterStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: filterStackView.bottomAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            collectionHeightConstraint
        ])
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func configureSelections() {
        setSelectedTab(index: 0)
        setSelectedFilter(index: 0)
    }

    @objc
    private func didTapTab(_ sender: UIButton) {
        setSelectedTab(index: sender.tag)
        onTabSelected?(sender.tag)
    }

    @objc
    private func didTapFilter(_ sender: UIButton) {
        setSelectedFilter(index: sender.tag)
        onFilterSelected?(sender.tag)
    }
}

private final class LibraryPillButton: UIButton {

    init(title: String) {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
            ])
        )
        self.configuration = configuration
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func applyStyle(
        isSelected: Bool,
        selectedBackgroundColor: UIColor,
        selectedTextColor: UIColor,
        normalBackgroundColor: UIColor,
        normalTextColor: UIColor,
        normalBorderColor: UIColor
    ) {
        backgroundColor = isSelected ? selectedBackgroundColor : normalBackgroundColor
        layer.borderWidth = isSelected ? 0 : 1
        layer.borderColor = normalBorderColor.cgColor

        var updatedConfiguration = configuration ?? .plain()
        updatedConfiguration.baseForegroundColor = isSelected ? selectedTextColor : normalTextColor
        configuration = updatedConfiguration
    }
}

private final class LibraryStatCardView: UIView {

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .gpTextTertiary
        label.textAlignment = .center
        return label
    }()

    init(value: String, subtitle: String, accentColor: UIColor) {
        super.init(frame: .zero)

        backgroundColor = .gpSurface
        layer.cornerRadius = 14
        translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = value
        valueLabel.textColor = accentColor
        subtitleLabel.text = subtitle

        let stackView = UIStackView(arrangedSubviews: [valueLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 14, left: 8, bottom: 14, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
