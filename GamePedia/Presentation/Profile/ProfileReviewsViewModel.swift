import Combine
import Foundation

final class ProfileReviewsViewModel {
    private(set) var state = ProfileReviewsState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ProfileReviewsState) -> Void)?

    private let fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase
    private let deleteReviewUseCase: DeleteReviewUseCase
    private var cancellables = Set<AnyCancellable>()
    private var didLoad = false

    init(
        fetchMyReviewedGamesUseCase: FetchMyReviewedGamesUseCase = FetchMyReviewedGamesUseCase(
            fetchMyReviewsUseCase: FetchMyReviewsUseCase(reviewRepository: DefaultReviewRepository()),
            gameRepository: DefaultGameRepository()
        ),
        deleteReviewUseCase: DeleteReviewUseCase = DeleteReviewUseCase(
            reviewRepository: DefaultReviewRepository()
        )
    ) {
        self.fetchMyReviewedGamesUseCase = fetchMyReviewedGamesUseCase
        self.deleteReviewUseCase = deleteReviewUseCase
        observeReviewChanges()
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        load(reason: "initialLoad")
    }

    func refreshOnAppear() {
        guard didLoad else {
            loadIfNeeded()
            return
        }
        load(reason: "viewWillAppear")
    }

    func reload() {
        load(reason: "manual")
    }

    func updateSort(_ sortOption: ReviewSortOption) {
        guard state.sortOption != sortOption else { return }
        state.sortOption = sortOption
        load(reason: "sortChanged")
    }

    func delete(review: ReviewedGame) async {
        guard state.deletingReviewId == nil else { return }
        await MainActor.run {
            self.state.deletingReviewId = review.reviewId
            self.state.errorMessage = nil
        }

        do {
            _ = try await deleteReviewUseCase.execute(reviewId: review.reviewId)
            NotificationCenter.default.post(
                name: .reviewDidChange,
                object: nil,
                userInfo: [
                    ReviewChangeUserInfoKey.gameId: String(review.gameId),
                    ReviewChangeUserInfoKey.reviewId: review.reviewId,
                    ReviewChangeUserInfoKey.action: ReviewChangeAction.deleted.rawValue
                ]
            )
            await MainActor.run {
                self.state.deletingReviewId = nil
                self.state.items.removeAll { $0.reviewId == review.reviewId }
            }
        } catch {
            await MainActor.run {
                let reviewError = ReviewError.from(error: error)
                self.state.deletingReviewId = nil
                self.state.errorMessage = reviewError.errorDescription ?? L10n.tr("Localizable", "review.error.deleteFailed")
            }
        }
    }

    private func observeReviewChanges() {
        NotificationCenter.default.publisher(for: .reviewDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.didLoad else { return }
                self.load(reason: "reviewChangeNotification")
            }
            .store(in: &cancellables)
    }

    private func load(reason: String) {
        state.isLoading = true
        state.errorMessage = nil
        print("[ProfileReviews] fetchStart source=\(reason)")

        Task {
            do {
                let items = try await fetchMyReviewedGamesUseCase.execute(
                    sort: state.sortOption,
                    screen: "MyReviews"
                )
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.items = items
                    print("[ProfileReviews] fetchSuccess source=\(reason) count=\(items.count)")
                }
            } catch {
                await MainActor.run {
                    let reviewError = ReviewError.from(error: error)
                    self.state.isLoading = false
                    self.state.errorMessage = reviewError.errorDescription ?? L10n.tr("Localizable", "review.error.loadFailed")
                    print("[ProfileReviews] fetchFailure source=\(reason) error=\(self.state.errorMessage ?? "unknown")")
                }
            }
        }
    }
}
