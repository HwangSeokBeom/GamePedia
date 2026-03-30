import UIKit

final class LibraryRootView: UIView {

    var onFilterSelected: ((Int) -> Void)?

    let collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let filterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private let loadingIndicatorView: UIActivityIndicatorView = {
        let indicatorView = UIActivityIndicatorView(style: .large)
        indicatorView.color = .gpPrimary
        indicatorView.hidesWhenStopped = true
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        return indicatorView
    }()

    private var filterButtons: [LibraryPillButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupLayout()
        setSelectedFilter(index: 0)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupLayout()
        setSelectedFilter(index: 0)
    }

    func setCollectionViewLayout(_ layout: UICollectionViewLayout) {
        collectionView.setCollectionViewLayout(layout, animated: false)
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

    func render(_ state: LibraryState) {
        setSelectedFilter(index: state.selectedSort.rawValue)

        if (state.isLoading || state.isRefreshing) && state.sections.isEmpty {
            loadingIndicatorView.startAnimating()
        } else {
            loadingIndicatorView.stopAnimating()
        }
    }

    private func setupView() {
        backgroundColor = .gpBackground

        addSubview(filterStackView)
        addSubview(collectionView)
        addSubview(loadingIndicatorView)

        ["최신순", "오래된순"].enumerated().forEach { index, title in
            let button = LibraryPillButton(title: title)
            button.tag = index
            button.addTarget(self, action: #selector(didTapFilter(_:)), for: .touchUpInside)
            filterButtons.append(button)
            filterStackView.addArrangedSubview(button)
        }
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            filterStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            filterStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            filterStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: filterStackView.bottomAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            loadingIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingIndicatorView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
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
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ])
        )
        self.configuration = configuration
        layer.cornerRadius = 14
        layer.masksToBounds = true
        layer.borderWidth = 1
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        layer.borderColor = (isSelected ? selectedBackgroundColor : normalBorderColor).cgColor
        var configuration = configuration
        configuration?.baseForegroundColor = isSelected ? selectedTextColor : normalTextColor
        self.configuration = configuration
    }
}
