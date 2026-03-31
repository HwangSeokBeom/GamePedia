import UIKit

final class HomeFilterSheetViewController: UIViewController {
    private var draftFilter: HomeContentFilter {
        didSet { render() }
    }

    var onApply: ((HomeContentFilter) -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .gpTextPrimary
        label.text = "홈 필터"
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .gpTextSecondary
        label.text = "플랫폼, 카테고리, 게임 모드로 홈 콘텐츠를 좁혀볼 수 있어요."
        label.numberOfLines = 0
        return label
    }()

    private let platformButton = HomeFilterSheetViewController.makeSelectionButton()
    private let categoryButton = HomeFilterSheetViewController.makeSelectionButton()
    private let gameModeButton = HomeFilterSheetViewController.makeSelectionButton()

    private let resetButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = "초기화"
        configuration.baseForegroundColor = .gpTextSecondary
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        return button
    }()

    private let applyButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "적용하기"
        configuration.baseBackgroundColor = .gpPrimary
        configuration.baseForegroundColor = .gpOnPrimary
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return button
    }()

    init(filter: HomeContentFilter) {
        self.draftFilter = filter
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gpBackground
        configureSheetPresentation()
        setupLayout()
        configureMenus()
        render()
    }

    private func configureSheetPresentation() {
        guard let sheetPresentationController else { return }
        sheetPresentationController.detents = [.medium()]
        sheetPresentationController.prefersGrabberVisible = true
        sheetPresentationController.preferredCornerRadius = 24
    }

    private func setupLayout() {
        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            makeFilterRow(title: "플랫폼", selectionButton: platformButton),
            makeFilterRow(title: "카테고리", selectionButton: categoryButton),
            makeFilterRow(title: "게임 모드", selectionButton: gameModeButton),
            makeActionStack()
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        resetButton.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
        applyButton.addTarget(self, action: #selector(didTapApply), for: .touchUpInside)
    }

    private func configureMenus() {
        platformButton.menu = makePlatformMenu()
        categoryButton.menu = makeCategoryMenu()
        gameModeButton.menu = makeGameModeMenu()
    }

    private func render() {
        updateSelectionButton(platformButton, title: draftFilter.platform.title)
        updateSelectionButton(categoryButton, title: draftFilter.category.title)
        updateSelectionButton(gameModeButton, title: draftFilter.gameMode.title)
        configureMenus()
    }

    private func makePlatformMenu() -> UIMenu {
        UIMenu(children: HomePlatformFilter.allCases.map { option in
            UIAction(
                title: option.title,
                state: draftFilter.platform == option ? .on : .off
            ) { [weak self] _ in
                self?.draftFilter.platform = option
            }
        })
    }

    private func makeCategoryMenu() -> UIMenu {
        UIMenu(children: HomeCategoryFilter.allCases.map { option in
            UIAction(
                title: option.title,
                state: draftFilter.category == option ? .on : .off
            ) { [weak self] _ in
                self?.draftFilter.category = option
            }
        })
    }

    private func makeGameModeMenu() -> UIMenu {
        UIMenu(children: HomeGameModeFilter.allCases.map { option in
            UIAction(
                title: option.title,
                state: draftFilter.gameMode == option ? .on : .off
            ) { [weak self] _ in
                self?.draftFilter.gameMode = option
            }
        })
    }

    private func makeFilterRow(title: String, selectionButton: UIButton) -> UIView {
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .gpTextPrimary
        titleLabel.text = title

        let stackView = UIStackView(arrangedSubviews: [titleLabel, UIView(), selectionButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        return stackView
    }

    private func makeActionStack() -> UIView {
        let spacerView = UIView()
        let stackView = UIStackView(arrangedSubviews: [resetButton, spacerView, applyButton])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        return stackView
    }

    private func updateSelectionButton(_ button: UIButton, title: String) {
        var configuration = button.configuration ?? UIButton.Configuration.filled()
        configuration.title = title
        button.configuration = configuration
    }

    @objc
    private func didTapReset() {
        draftFilter = .default
    }

    @objc
    private func didTapApply() {
        onApply?(draftFilter)
        dismiss(animated: true)
    }

    private static func makeSelectionButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .gpCardBackground
        configuration.baseForegroundColor = .gpTextPrimary
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 8
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        let button = UIButton(configuration: configuration)
        button.showsMenuAsPrimaryAction = true
        return button
    }
}
