import Combine
import Foundation

final class ProfileCommentsViewModel {
    private(set) var state = ProfileCommentsState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ProfileCommentsState) -> Void)?
    private let fetchMyReviewCommentsUseCase: FetchMyReviewCommentsUseCase
    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false

    init(
        fetchMyReviewCommentsUseCase: FetchMyReviewCommentsUseCase = FetchMyReviewCommentsUseCase(
            repository: DefaultReviewCommentRepository()
        )
    ) {
        self.fetchMyReviewCommentsUseCase = fetchMyReviewCommentsUseCase
        observeCommentChanges()
    }

    func loadIfNeeded() {
        guard !hasLoaded else {
            onStateChanged?(state)
            return
        }
        hasLoaded = true
        reload()
    }

    func reload() {
        state.isLoading = true
        state.errorMessage = nil

        Task {
            do {
                let items = try await fetchMyReviewCommentsUseCase.execute()
                await MainActor.run {
                    self.state.items = items
                    self.state.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.items = []
                    self.state.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func observeCommentChanges() {
        NotificationCenter.default.publisher(for: .reviewCommentsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }
}
