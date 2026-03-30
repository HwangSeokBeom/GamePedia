import UIKit

final class SteamFallbackGameDetailViewController: BaseViewController<SteamFallbackGameDetailRootView, SteamFallbackGameDetailViewState> {

    private let viewState: SteamFallbackGameDetailViewState

    init(viewState: SteamFallbackGameDetailViewState) {
        self.viewState = viewState
        super.init(rootView: SteamFallbackGameDetailRootView())
        NavigationBarStyler.apply(.opaque, to: navigationItem, buttonTintColor: .gpPrimary)
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = "게임 상세"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render(viewState)
    }

    override func render(_ state: SteamFallbackGameDetailViewState) {
        rootView.render(state)
    }

    deinit {
        rootView.prepareForReuse()
    }
}
