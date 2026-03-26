//
//  LibraryViewController.swift
//  GamePedia
//
//  Created by Hwangseokbeom on 3/23/26.
//

import UIKit

final class LibraryViewController: BaseViewController<LibraryRootView, Void> {

    private enum Section {
        case main
    }

    private var dataSource: UICollectionViewDiffableDataSource<Section, LibraryGameCardItem>!

    private let items: [LibraryGameCardItem] = [
        LibraryGameCardItem(
            id: 1,
            title: "엘든 링",
            playHours: 120,
            ratingValue: 4.9,
            symbolName: "flame",
            startColorHex: "#A96E20",
            endColorHex: "#1C1B27"
        ),
        LibraryGameCardItem(
            id: 2,
            title: "젤다의 전설",
            playHours: 85,
            ratingValue: 4.8,
            symbolName: "leaf",
            startColorHex: "#66D4FF",
            endColorHex: "#3B6B5C"
        ),
        LibraryGameCardItem(
            id: 3,
            title: "갓 오브 워",
            playHours: 32,
            ratingValue: 4.9,
            symbolName: "shield.lefthalf.filled",
            startColorHex: "#50545F",
            endColorHex: "#1B1B21"
        ),
        LibraryGameCardItem(
            id: 4,
            title: "사이버펑크",
            playHours: 65,
            ratingValue: 4.5,
            symbolName: "building.2.crop.circle",
            startColorHex: "#8C46F9",
            endColorHex: "#0C2C4E"
        )
    ]

    override init(rootView: LibraryRootView = LibraryRootView()) {
        super.init(rootView: rootView)
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        configureNavigationItem()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        rootView.setUsesNavigationTitle(true)
        setupCollectionView()
        setupBindings()
        applySnapshot()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    private func configureNavigationItem() {
        UIView.performWithoutAnimation {
            navigationItem.title = "내 라이브러리"
            navigationItem.largeTitleDisplayMode = .never
            navigationItem.rightBarButtonItem = makeSortFilterBarButtonItem()
        }
    }

    private func makeSortFilterBarButtonItem() -> UIBarButtonItem {
        let image = UIImage(
            systemName: "slider.horizontal.3",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )
        let item = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(didTapSortFilter)
        )
        item.tintColor = .gpTextSecondary
        return item
    }

    private func setupCollectionView() {
        rootView.collectionView.delegate = self

        dataSource = UICollectionViewDiffableDataSource<Section, LibraryGameCardItem>(
            collectionView: rootView.collectionView
        ) { collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: LibraryGameCardCell.reuseId,
                for: indexPath
            ) as! LibraryGameCardCell
            cell.configure(with: item)
            return cell
        }
    }

    private func setupBindings() {
        rootView.onTabSelected = { _ in }
        rootView.onFilterSelected = { _ in }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, LibraryGameCardItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            self?.rootView.updateCollectionHeight()
        }
    }

    @objc
    private func didTapSortFilter() {
        // No sort action was previously wired for the in-content button.
    }
}

extension LibraryViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = floor((collectionView.bounds.width - 12) / 2)
        return CGSize(width: width, height: width * 1.54)
    }
}
