import UIKit

// MARK: - HomeRootView

final class HomeRootView: UIView {

    // MARK: - Section Layout

    /// Home's section identity.
    ///
    /// This used to be an `Int`-raw enum, with the layout and the header
    /// provider both switching on the *position* of a section. That cannot
    /// express Product 2.2's Today feed, whose section count and order are
    /// decided by the server (`meta.sectionOrder`) and change per response —
    /// a fixed position would silently give one section another's layout the
    /// moment the server reordered or omitted one.
    ///
    /// So identity is now the key itself, and both the layout and the header
    /// provider resolve it through the diffable data source.
    enum Section: Hashable {
        /// Feed-level notices: staleness, partial failure. Never an error.
        case todayNotice
        /// One Product 2.2 Today section, named by its server key.
        case today(TodaySectionKey)
        /// Legacy discovery, kept below Today.
        case todayRecommendation
        case popular
        case trending

        /// The pre-existing discovery sections, in their original order.
        static let legacyDiscovery: [Section] = [.todayRecommendation, .popular, .trending]

        var todayKey: TodaySectionKey? {
            if case .today(let key) = self { return key }
            return nil
        }
    }

    /// Resolves the section identifier at a given index.
    ///
    /// The view controller points this at its diffable data source, which is
    /// the only thing that knows what is actually on screen. Without it the
    /// layout would be back to guessing from position.
    var sectionIdentifierProvider: ((Int) -> Section?)?

    // MARK: Subviews

    let searchHintView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpSurface
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewLayout())
        cv.backgroundColor = .gpBackground
        cv.showsVerticalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    let highlightCarouselView: HomeHighlightCarouselView = {
        let view = HomeHighlightCarouselView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let highlightSkeletonView: HomeHighlightSkeletonView = {
        let view = HomeHighlightSkeletonView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var highlightHeightConstraint: NSLayoutConstraint?
    private var showsHighlightContent = false
    private var showsHighlightSkeleton = false

    // MARK: Callback
    var onSearchTapped: (() -> Void)?

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: Setup
    private func setup() {
        backgroundColor = .gpBackground
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)

        setupSearchHint()

        addSubview(searchHintView)
        addSubview(highlightCarouselView)
        addSubview(highlightSkeletonView)
        addSubview(collectionView)

        highlightHeightConstraint = highlightCarouselView.heightAnchor.constraint(
            equalToConstant: HomeHighlightCarouselView.preferredHeight
        )

        NSLayoutConstraint.activate([
            searchHintView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            searchHintView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            searchHintView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            searchHintView.heightAnchor.constraint(equalToConstant: 44),

            highlightCarouselView.topAnchor.constraint(equalTo: searchHintView.bottomAnchor, constant: 14),
            highlightCarouselView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            highlightCarouselView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            highlightSkeletonView.topAnchor.constraint(equalTo: highlightCarouselView.topAnchor),
            highlightSkeletonView.leadingAnchor.constraint(equalTo: highlightCarouselView.leadingAnchor),
            highlightSkeletonView.trailingAnchor.constraint(equalTo: highlightCarouselView.trailingAnchor),
            highlightSkeletonView.bottomAnchor.constraint(equalTo: highlightCarouselView.bottomAnchor),

            collectionView.topAnchor.constraint(equalTo: highlightCarouselView.bottomAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        highlightHeightConstraint?.isActive = true
        setHighlightsVisible(false)

        collectionView.register(TodayRecommendationCardCell.self, forCellWithReuseIdentifier: TodayRecommendationCardCell.reuseId)
        collectionView.register(GameHorizontalCell.self, forCellWithReuseIdentifier: GameHorizontalCell.reuseId)
        collectionView.register(GameRowCell.self, forCellWithReuseIdentifier: GameRowCell.reuseId)
        collectionView.register(TodayRecommendationSkeletonCell.self, forCellWithReuseIdentifier: TodayRecommendationSkeletonCell.reuseId)
        collectionView.register(GameHorizontalSkeletonCell.self, forCellWithReuseIdentifier: GameHorizontalSkeletonCell.reuseId)
        collectionView.register(GameRowSkeletonCell.self, forCellWithReuseIdentifier: GameRowSkeletonCell.reuseId)
        collectionView.register(TodayItemCell.self, forCellWithReuseIdentifier: TodayItemCell.reuseId)
        collectionView.register(TodayStatusCell.self, forCellWithReuseIdentifier: TodayStatusCell.reuseId)
        collectionView.register(TodayNoticeCell.self, forCellWithReuseIdentifier: TodayNoticeCell.reuseId)
        collectionView.register(
            HomeSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: HomeSectionHeaderView.reuseId
        )
    }

    private func setupSearchHint() {
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .gpTextTertiary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = L10n.Home.searchHint
        label.font = .systemFont(ofSize: 15)
        label.textColor = .gpTextTertiary
        label.translatesAutoresizingMaskIntoConstraints = false

        searchHintView.addSubview(icon)
        searchHintView.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: searchHintView.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: searchHintView.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: searchHintView.centerYAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(searchHintTapped))
        searchHintView.addGestureRecognizer(tap)
        searchHintView.isUserInteractionEnabled = true
    }

    @objc private func searchHintTapped() {
        onSearchTapped?()
    }

    // MARK: - Compositional Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self else { return nil }
            // Keyed by identity, not by position — see `Section`.
            switch self.sectionIdentifierProvider?(sectionIndex) {
            case .todayNotice:         return self.noticeSection()
            case .today:               return self.todayFeedSection()
            case .todayRecommendation: return self.todayRecommendationSection()
            case .popular:             return self.horizontalSection()
            case .trending:            return self.verticalSection()
            case nil:                  return self.horizontalSection()
            }
        }
    }

    /// Notices sit above everything with no header of their own.
    private func noticeSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(36)
        ))
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(36)
            ),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20)
        return section
    }

    /// A Today section is a vertical list with an estimated height, so a long
    /// localized string or a large Dynamic Type setting grows the row instead
    /// of clipping it.
    private func todayFeedSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(96)
        ))
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(96)
            ),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 20, bottom: 24, trailing: 20)

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    private func todayRecommendationSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        ))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(
                widthDimension: .fractionalWidth(0.88),
                heightDimension: .absolute(TodayRecommendationCardCell.height)
            ),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 20, bottom: 28, trailing: 20)

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    private func horizontalSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .absolute(GameHorizontalCell.width),
            heightDimension: .absolute(GameHorizontalCell.height)
        ))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(
                widthDimension: .absolute(GameHorizontalCell.width),
                heightDimension: .absolute(GameHorizontalCell.height)
            ),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 20, bottom: 28, trailing: 20)

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    private func verticalSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: .init(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(GameRowCell.height)
        ))
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: .init(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(GameRowCell.height)
            ),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 20, bottom: 24, trailing: 20)

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .absolute(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    // MARK: - State Rendering

    func render(_ state: HomeState) {
        // DataSource reload handled by ViewController
    }

    func setHighlightsVisible(_ visible: Bool) {
        showsHighlightContent = visible
        updateHighlightVisibility()
    }

    func setHighlightLoadingVisible(_ visible: Bool) {
        showsHighlightSkeleton = visible
        updateHighlightVisibility()
    }

    private func updateHighlightVisibility() {
        let shouldReserveHeight = showsHighlightSkeleton || showsHighlightContent

        if shouldReserveHeight {
            highlightHeightConstraint?.constant = HomeHighlightCarouselView.preferredHeight
        }

        let showsVisibleHighlightContent = showsHighlightContent && !showsHighlightSkeleton
        highlightCarouselView.setCollapsed(!showsVisibleHighlightContent)
        highlightSkeletonView.setCollapsed(!showsHighlightSkeleton)

        highlightSkeletonView.isHidden = !showsHighlightSkeleton
        highlightCarouselView.isHidden = !showsVisibleHighlightContent

        if !shouldReserveHeight {
            highlightHeightConstraint?.constant = 0
        }
    }
}

// MARK: - HomeSectionHeaderView

final class HomeSectionHeaderView: UICollectionReusableView {

    static let reuseId = "HomeSectionHeaderView"

    let sectionHeader = SectionHeaderView()
    private let skeletonTitleView = SkeletonPlaceholderView(cornerRadius: 10)
    private let skeletonActionView = SkeletonPlaceholderView(cornerRadius: 8)
    private lazy var skeletonContainerView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [skeletonTitleView, UIView(), skeletonActionView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isHidden = true
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sectionHeader)
        addSubview(skeletonContainerView)
        NSLayoutConstraint.activate([
            sectionHeader.topAnchor.constraint(equalTo: topAnchor),
            sectionHeader.bottomAnchor.constraint(equalTo: bottomAnchor),
            sectionHeader.leadingAnchor.constraint(equalTo: leadingAnchor),
            sectionHeader.trailingAnchor.constraint(equalTo: trailingAnchor),

            skeletonContainerView.topAnchor.constraint(equalTo: topAnchor),
            skeletonContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            skeletonContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            skeletonContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            skeletonTitleView.widthAnchor.constraint(equalToConstant: 124),
            skeletonTitleView.heightAnchor.constraint(equalToConstant: 22),
            skeletonActionView.widthAnchor.constraint(equalToConstant: 52),
            skeletonActionView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configureSkeleton() {
        sectionHeader.isHidden = true
        skeletonContainerView.isHidden = false
    }

    func configure(
        title: String,
        systemImageName: String?,
        tintColor: UIColor,
        showSeeMore: Bool = true
    ) {
        sectionHeader.isHidden = false
        skeletonContainerView.isHidden = true
        sectionHeader.configure(
            title: title,
            systemImageName: systemImageName,
            tintColor: tintColor,
            showSeeMore: showSeeMore
        )
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        sectionHeader.isHidden = false
        skeletonContainerView.isHidden = true
    }
}
