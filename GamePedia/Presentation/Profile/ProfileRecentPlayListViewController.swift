import UIKit

final class ProfileRecentPlayListViewController: UIViewController {

    var onGameSelected: ((Int) -> Void)?

    private let games: [RecentGame]
    private let translatedTitles: [Int: String]

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .gpBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = RecentPlayCell.height
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    private let emptyCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .gpCardBackground
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.gpSeparator.withAlphaComponent(0.24).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .gpTextSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = L10n.Profile.Empty.noRecentPlayedGames
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(games: [RecentGame], translatedTitles: [Int: String]) {
        self.games = games
        self.translatedTitles = translatedTitles
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[Profile] recentPlayList didLoad count=\(games.count)")
        GameDetailSeedStore.shared.store(recentGames: games, screen: "Profile.recentPlayList.render")
        view.backgroundColor = .gpBackground
        navigationItem.title = L10n.Profile.Section.recentPlay
        navigationItem.largeTitleDisplayMode = .never

        tableView.register(RecentPlayCell.self, forCellReuseIdentifier: RecentPlayCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self

        view.addSubview(tableView)
        view.addSubview(emptyCardView)
        emptyCardView.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyCardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            emptyCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            emptyCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            emptyLabel.topAnchor.constraint(equalTo: emptyCardView.topAnchor, constant: 20),
            emptyLabel.leadingAnchor.constraint(equalTo: emptyCardView.leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: emptyCardView.trailingAnchor, constant: -20),
            emptyLabel.bottomAnchor.constraint(equalTo: emptyCardView.bottomAnchor, constant: -20)
        ])

        tableView.isHidden = games.isEmpty
        emptyCardView.isHidden = !games.isEmpty
    }
}

extension ProfileRecentPlayListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        games.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: RecentPlayCell.reuseId,
            for: indexPath
        ) as! RecentPlayCell
        let game = games[indexPath.row]
        let resolvedTitle = game.title
        cell.configure(with: game, resolvedTitle: resolvedTitle)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let game = games[indexPath.row]
        GameDetailSeedStore.shared.store(recentGames: [game], screen: "Profile.recentPlayList.tap")
        let resolvedTitle = game.title
        let resolvedGameId = game.resolvedDetailGameId
        let blockedReason: String?
        if game.detailAvailable == false {
            blockedReason = "detailUnavailable"
        } else if resolvedGameId == nil {
            blockedReason = "invalidGameId"
        } else {
            blockedReason = nil
        }
        print(
            "[DetailRouteMapping] " +
            "screen=Profile.recentPlayList " +
            "title=\(resolvedTitle) " +
            "externalGameId=\(game.externalGameId ?? "nil") " +
            "igdbGameId=\(game.igdbGameId.map(String.init) ?? "nil") " +
            "detailAvailable=\(game.detailAvailable) " +
            "createdDestination=\(resolvedGameId.map(String.init) ?? "nil") " +
            "blockedReason=\(blockedReason ?? "nil")"
        )
        guard let resolvedGameId, resolvedGameId > 0, game.detailAvailable else {
            presentUnavailableDetailAlert()
            return
        }
        print(
            "[GameTap] " +
            "screen=Profile.recentPlayList " +
            "title=\(resolvedTitle) " +
            "destination=igdb:\(resolvedGameId) " +
            "igdbGameId=\(game.igdbGameId.map(String.init) ?? "nil") " +
            "externalGameId=\(game.externalGameId ?? "nil")"
        )
        onGameSelected?(resolvedGameId)
    }
}

private extension ProfileRecentPlayListViewController {
    func presentUnavailableDetailAlert() {
        let alert = UIAlertController(
            title: L10n.tr("Localizable", "profile.alert.detailUnavailableTitle"),
            message: L10n.tr("Localizable", "profile.alert.detailUnavailableMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.tr("Localizable", "common.button.ok"), style: .default))
        present(alert, animated: true)
    }
}
