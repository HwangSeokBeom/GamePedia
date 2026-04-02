import UIKit

// MARK: - SearchRootView

final class SearchRootView: UIView {

    // MARK: Subviews

    let searchTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "게임을 검색하세요"
        textField.textColor = .gpTextPrimary
        textField.font = .systemFont(ofSize: 15)
        textField.backgroundColor = .gpSurface
        textField.layer.cornerRadius = 14
        textField.returnKeyType = .search
        textField.tintColor = .gpPrimary

        let leftContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 48))
        let iconImageView = UIImageView(
            image: UIImage(
                systemName: "magnifyingglass",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
            )
        )
        iconImageView.tintColor = .gpPrimary
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.frame = CGRect(x: 14, y: 14, width: 20, height: 20)
        leftContainerView.addSubview(iconImageView)
        textField.leftView = leftContainerView
        textField.leftViewMode = .always

        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    let clearButton: UIButton = {
        let button = UIButton(type: .custom)
        let configuration = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        button.tintColor = .gpTextSecondary
        return button
    }()

    let genreCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    let resultCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .gpTextSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = SearchResultCell.height
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    let emptyStateView: EmptyStateView = {
        let emptyStateView = EmptyStateView()
        emptyStateView.isHidden = true
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        return emptyStateView
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .gpTextSecondary
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

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

        let clearContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 36, height: 48))
        clearButton.frame = CGRect(x: 4, y: 14, width: 18, height: 20)
        clearContainerView.addSubview(clearButton)
        searchTextField.rightView = clearContainerView
        searchTextField.rightViewMode = .never

        [searchTextField, genreCollectionView, resultCountLabel, tableView, emptyStateView, activityIndicator].forEach {
            addSubview($0)
        }

        genreCollectionView.register(GenreChipCell.self, forCellWithReuseIdentifier: GenreChipCell.reuseId)
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseId)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)

        emptyStateView.configure(icon: "magnifyingglass", message: "검색 결과가 없습니다")

        NSLayoutConstraint.activate([
            searchTextField.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 0),
            searchTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            searchTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            searchTextField.heightAnchor.constraint(equalToConstant: 48),

            genreCollectionView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 10),
            genreCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            genreCollectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            genreCollectionView.heightAnchor.constraint(equalToConstant: 36),

            resultCountLabel.topAnchor.constraint(equalTo: genreCollectionView.bottomAnchor, constant: 12),
            resultCountLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            tableView.topAnchor.constraint(equalTo: resultCountLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: centerYAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: resultCountLabel.bottomAnchor, constant: 32)
        ])
    }

    // MARK: - State Rendering

    func render(_ state: SearchState) {
        searchTextField.rightViewMode = state.query.isEmpty ? .never : .always

        if state.query.isEmpty {
            resultCountLabel.isHidden = true
        } else {
            resultCountLabel.isHidden = false
            resultCountLabel.text = "검색 결과 \(state.resultCount)건"
        }

        emptyStateView.isHidden = !state.showEmptyResult
        tableView.isHidden = state.showEmptyResult

        if state.isSearching {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
}
