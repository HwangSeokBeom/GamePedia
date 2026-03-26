import UIKit

final class CustomTabBarView: UIView {

    var onTabSelected: ((Int) -> Void)?

    private let backgroundContainerView = UIView()
    private let selectedBackgroundView = UIView()
    private let stackView = UIStackView()

    private let tabItems: [(title: String, image: String, selectedImage: String)] = [
        ("홈", "house", "house.fill"),
        ("검색", "magnifyingglass", "magnifyingglass"),
        ("라이브러리", "books.vertical", "books.vertical.fill"),
        ("프로필", "person", "person.fill")
    ]

    private var tabButtons: [UIButton] = []
    private var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupTabs()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundContainerView.frame = bounds
        backgroundContainerView.layer.cornerRadius = bounds.height / 2
        moveSelectedBackground(animated: false)
    }

    func updateSelectedIndex(_ index: Int) {
        guard tabItems.indices.contains(index) else { return }
        selectedIndex = index
        updateButtonStates()
        moveSelectedBackground(animated: true)
    }

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false

        backgroundContainerView.backgroundColor = .gpSurface
        backgroundContainerView.layer.shadowColor = UIColor.black.cgColor
        backgroundContainerView.layer.shadowOffset = CGSize(width: 0, height: 8)
        backgroundContainerView.layer.shadowRadius = 20
        backgroundContainerView.layer.shadowOpacity = 0.35
        backgroundContainerView.clipsToBounds = false
        addSubview(backgroundContainerView)

        selectedBackgroundView.backgroundColor = UIColor.gpPrimary.withAlphaComponent(0.18)
        backgroundContainerView.addSubview(selectedBackgroundView)

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        backgroundContainerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor, constant: -8)
        ])
    }

    private func setupTabs() {
        tabItems.enumerated().forEach { index, _ in
            let button = UIButton(type: .system)
            button.tag = index
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
            button.configuration = makeButtonConfiguration(for: index, isSelected: index == selectedIndex)
            button.configurationUpdateHandler = { [weak self] button in
                guard let self else { return }
                let isSelected = button.tag == self.selectedIndex
                button.configuration = self.makeButtonConfiguration(for: button.tag, isSelected: isSelected)
            }

            let containerView = UIView()
            containerView.backgroundColor = .clear
            containerView.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                button.topAnchor.constraint(equalTo: containerView.topAnchor),
                button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])

            stackView.addArrangedSubview(containerView)
            tabButtons.append(button)
        }

        updateButtonStates()
    }

    private func makeButtonConfiguration(for index: Int, isSelected: Bool) -> UIButton.Configuration {
        let tabItem = tabItems[index]

        var configuration = UIButton.Configuration.plain()
        configuration.title = tabItem.title
        configuration.image = UIImage(systemName: isSelected ? tabItem.selectedImage : tabItem.image)
        configuration.imagePlacement = .top
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        configuration.baseForegroundColor = isSelected ? .gpPrimary : .gpTextTertiary
        configuration.titleAlignment = .center

        let titleFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let attributes = AttributeContainer([
            .font: titleFont
        ])
        configuration.attributedTitle = AttributedString(tabItem.title, attributes: attributes)

        return configuration
    }

    private func updateButtonStates() {
        tabButtons.forEach { button in
            button.setNeedsUpdateConfiguration()
        }
    }

    private func moveSelectedBackground(animated: Bool) {
        guard !tabButtons.isEmpty else { return }

        let horizontalInset: CGFloat = 8
        let verticalInset: CGFloat = 8
        let itemWidth = (backgroundContainerView.bounds.width - (horizontalInset * 2)) / CGFloat(tabButtons.count)
        let backgroundHeight = backgroundContainerView.bounds.height - (verticalInset * 2)

        let targetFrame = CGRect(
            x: horizontalInset + (CGFloat(selectedIndex) * itemWidth),
            y: verticalInset,
            width: itemWidth,
            height: backgroundHeight
        )

        let applyFrame = {
            self.selectedBackgroundView.frame = targetFrame
            self.selectedBackgroundView.layer.cornerRadius = targetFrame.height / 2
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
                applyFrame()
            }
        } else {
            applyFrame()
        }
    }

    @objc
    private func tabButtonTapped(_ sender: UIButton) {
        onTabSelected?(sender.tag)
    }
}
