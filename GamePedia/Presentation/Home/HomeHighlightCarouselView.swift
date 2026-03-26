import UIKit

final class HomeHighlightCarouselView: UIView {

    static let preferredHeight: CGFloat = 230

    var onHighlightSelected: ((HomeHighlightItem) -> Void)?

    private let autoScrollController = HomeHighlightAutoScrollController()
    private var highlights: [HomeHighlightItem] = []
    private var displayItems: [HomeHighlightItem] = []
    private var isUserDragging = false
    private var appLifecycleObservers: [NSObjectProtocol] = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.isPagingEnabled = true
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FeaturedBannerCell.self, forCellWithReuseIdentifier: FeaturedBannerCell.reuseId)
        return collectionView
    }()

    private let pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.currentPageIndicatorTintColor = .gpPrimary
        pageControl.pageIndicatorTintColor = .gpTextMuted
        pageControl.hidesForSinglePage = true
        pageControl.isUserInteractionEnabled = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        return pageControl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        registerLifecycleObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        registerLifecycleObservers()
    }

    deinit {
        autoScrollController.stop()
        appLifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let itemSize = CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
        if flowLayout.itemSize != itemSize {
            flowLayout.itemSize = itemSize
            flowLayout.invalidateLayout()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            autoScrollController.pause()
        } else {
            resumeAutoScrollIfNeeded()
        }
    }

    func update(with highlights: [HomeHighlightItem]) {
        guard self.highlights != highlights else {
            resumeAutoScrollIfNeeded()
            return
        }

        self.highlights = highlights
        self.displayItems = makeDisplayItems(from: highlights)
        pageControl.numberOfPages = highlights.count
        collectionView.reloadData()

        if highlights.count <= 1 {
            autoScrollController.pause()
        }

        DispatchQueue.main.async { [weak self] in
            self?.resetToInitialPosition()
            self?.resumeAutoScrollIfNeeded()
        }
    }

    private func setup() {
        backgroundColor = .clear
        addSubview(collectionView)
        addSubview(pageControl)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 208),

            pageControl.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 10),
            pageControl.centerXAnchor.constraint(equalTo: centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func registerLifecycleObservers() {
        let center = NotificationCenter.default
        appLifecycleObservers = [
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.autoScrollController.pause()
            },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.resumeAutoScrollIfNeeded()
            }
        ]
    }

    private func makeDisplayItems(from highlights: [HomeHighlightItem]) -> [HomeHighlightItem] {
        guard highlights.count > 1, let first = highlights.first, let last = highlights.last else {
            return highlights
        }
        return [last] + highlights + [first]
    }

    private func resetToInitialPosition() {
        guard !displayItems.isEmpty else { return }
        let initialIndex = highlights.count > 1 ? 1 : 0
        let indexPath = IndexPath(item: initialIndex, section: 0)
        collectionView.layoutIfNeeded()
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
        pageControl.currentPage = 0
    }

    private func currentDisplayIndex() -> Int {
        guard collectionView.bounds.width > 0 else { return 0 }
        let rawIndex = collectionView.contentOffset.x / collectionView.bounds.width
        return Int(round(rawIndex))
    }

    private func normalizedHighlightIndex(from displayIndex: Int) -> Int {
        guard highlights.count > 1 else { return max(0, min(displayIndex, highlights.count - 1)) }
        switch displayIndex {
        case 0:
            return highlights.count - 1
        case displayItems.count - 1:
            return 0
        default:
            return max(0, min(displayIndex - 1, highlights.count - 1))
        }
    }

    private func normalizeIfNeeded() {
        guard highlights.count > 1 else { return }
        let displayIndex = currentDisplayIndex()
        if displayIndex == 0 {
            let target = IndexPath(item: highlights.count, section: 0)
            collectionView.scrollToItem(at: target, at: .centeredHorizontally, animated: false)
        } else if displayIndex == displayItems.count - 1 {
            let target = IndexPath(item: 1, section: 0)
            collectionView.scrollToItem(at: target, at: .centeredHorizontally, animated: false)
        }
        pageControl.currentPage = normalizedHighlightIndex(from: currentDisplayIndex())
    }

    private func advanceToNextPage() {
        guard highlights.count > 1, !isUserDragging else { return }
        let nextIndex = currentDisplayIndex() + 1
        let target = IndexPath(item: min(nextIndex, displayItems.count - 1), section: 0)
        collectionView.scrollToItem(at: target, at: .centeredHorizontally, animated: true)
    }

    private func resumeAutoScrollIfNeeded() {
        guard window != nil, highlights.count > 1, !isUserDragging else { return }
        autoScrollController.start { [weak self] in
            self?.advanceToNextPage()
        }
    }
}

extension HomeHighlightCarouselView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeaturedBannerCell.reuseId,
            for: indexPath
        ) as! FeaturedBannerCell
        cell.configure(with: displayItems[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let logicalIndex = normalizedHighlightIndex(from: indexPath.item)
        guard highlights.indices.contains(logicalIndex) else { return }
        onHighlightSelected?(highlights[logicalIndex])
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserDragging = true
        autoScrollController.pause()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isUserDragging = false
            normalizeIfNeeded()
            resumeAutoScrollIfNeeded()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserDragging = false
        normalizeIfNeeded()
        resumeAutoScrollIfNeeded()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        normalizeIfNeeded()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !highlights.isEmpty, scrollView.bounds.width > 0 else { return }
        pageControl.currentPage = normalizedHighlightIndex(from: currentDisplayIndex())
    }
}
