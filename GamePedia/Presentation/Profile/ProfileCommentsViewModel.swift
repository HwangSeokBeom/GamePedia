import Combine
import Foundation

final class ProfileCommentsViewModel {
    private(set) var state = ProfileCommentsState() {
        didSet { onStateChanged?(state) }
    }

    var onStateChanged: ((ProfileCommentsState) -> Void)?
    private let fetchMyReviewCommentsUseCase: FetchMyReviewCommentsUseCase
    private let reactToStoredReviewCommentUseCase: ReactToStoredReviewCommentUseCase
    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false

    init(
        fetchMyReviewCommentsUseCase: FetchMyReviewCommentsUseCase = FetchMyReviewCommentsUseCase(
            repository: DefaultReviewCommentRepository()
        ),
        reactToStoredReviewCommentUseCase: ReactToStoredReviewCommentUseCase = ReactToStoredReviewCommentUseCase(
            repository: DefaultReviewCommentRepository()
        )
    ) {
        self.fetchMyReviewCommentsUseCase = fetchMyReviewCommentsUseCase
        self.reactToStoredReviewCommentUseCase = reactToStoredReviewCommentUseCase
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
                    self.state.allItems = items
                    self.state.items = self.sort(items, by: self.state.sortOption)
                    self.state.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.state.isLoading = false
                    self.state.allItems = []
                    self.state.items = []
                    self.state.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    func updateSort(_ option: ReviewCommentSortOption) {
        guard state.sortOption != option else { return }
        state.sortOption = option
        state.items = sort(state.allItems, by: option)
    }

    func toggleLike(commentId: String) {
        guard let originalEntry = state.allItems.first(where: { $0.id == commentId }) else { return }

        let nextReaction: ReviewCommentReaction? = originalEntry.myReaction == .like ? nil : .like
        let optimisticComment = optimisticUpdatedComment(originalEntry.comment, nextReaction: nextReaction)
        replaceEntry(makeEntry(from: optimisticComment, fallback: originalEntry))
        state.reactingCommentIds.insert(commentId)

        Task {
            do {
                let updatedComment = try await reactToStoredReviewCommentUseCase.execute(commentId: commentId, reaction: nextReaction)
                await MainActor.run {
                    self.replaceEntry(self.makeEntry(from: updatedComment, fallback: originalEntry))
                    self.state.reactingCommentIds.remove(commentId)
                }
            } catch {
                await MainActor.run {
                    self.replaceEntry(originalEntry)
                    self.state.reactingCommentIds.remove(commentId)
                }
            }
        }
    }

    private func observeCommentChanges() {
        ReviewCommentSyncCenter.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.hasLoaded else { return }
                self.reload()
            }
            .store(in: &cancellables)
    }

    private func replaceEntry(_ entry: MyReviewCommentEntry) {
        if let index = state.allItems.firstIndex(where: { $0.id == entry.id }) {
            state.allItems[index] = entry
            state.items = sort(state.allItems, by: state.sortOption)
        }
    }

    private func sort(_ items: [MyReviewCommentEntry], by option: ReviewCommentSortOption) -> [MyReviewCommentEntry] {
        items.sorted { lhs, rhs in
            let lhsDate = lhs.updatedAt ?? lhs.createdAt
            let rhsDate = rhs.updatedAt ?? rhs.createdAt

            switch option {
            case .latest:
                if lhsDate != rhsDate { return lhsDate > rhsDate }
            case .oldest:
                if lhsDate != rhsDate { return lhsDate < rhsDate }
            case .likeDescending:
                if lhs.likeCount != rhs.likeCount { return lhs.likeCount > rhs.likeCount }
                if lhsDate != rhsDate { return lhsDate > rhsDate }
            case .likeAscending:
                if lhs.likeCount != rhs.likeCount { return lhs.likeCount < rhs.likeCount }
                if lhsDate != rhsDate { return lhsDate < rhsDate }
            }

            return lhs.id < rhs.id
        }
    }

    private func optimisticUpdatedComment(
        _ comment: ReviewComment,
        nextReaction: ReviewCommentReaction?
    ) -> ReviewComment {
        var likeCount = comment.likeCount
        var dislikeCount = comment.dislikeCount

        switch comment.myReaction {
        case .like:
            likeCount = max(0, likeCount - 1)
        case .dislike:
            dislikeCount = max(0, dislikeCount - 1)
        case .none:
            break
        }

        switch nextReaction {
        case .like:
            likeCount += 1
        case .dislike:
            dislikeCount += 1
        case .none:
            break
        }

        return ReviewComment(
            id: comment.id,
            reviewId: comment.reviewId,
            gameId: comment.gameId,
            gameTitle: comment.gameTitle,
            reviewSnippet: comment.reviewSnippet,
            parentCommentId: comment.parentCommentId,
            depth: comment.depth,
            author: comment.author,
            content: comment.content,
            createdAt: comment.createdAt,
            updatedAt: comment.updatedAt,
            isMine: comment.isMine,
            isReviewAuthor: comment.isReviewAuthor,
            isDeleted: comment.isDeleted,
            isEdited: comment.isEdited,
            replyCount: comment.replyCount,
            likeCount: likeCount,
            dislikeCount: dislikeCount,
            myReaction: nextReaction
        )
    }

    private func makeEntry(from comment: ReviewComment, fallback: MyReviewCommentEntry) -> MyReviewCommentEntry {
        MyReviewCommentEntry(
            id: comment.id,
            reviewId: comment.reviewId,
            gameId: comment.gameId,
            gameTitle: fallback.gameTitle,
            reviewSnippet: fallback.reviewSnippet,
            commentContent: comment.content,
            createdAt: comment.createdAt,
            updatedAt: comment.updatedAt,
            depth: comment.depth,
            isDeleted: comment.isDeleted,
            likeCount: comment.likeCount,
            dislikeCount: comment.dislikeCount,
            myReaction: comment.myReaction,
            comment: comment
        )
    }
}
