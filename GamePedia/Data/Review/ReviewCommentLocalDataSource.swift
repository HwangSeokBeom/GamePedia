import Foundation

protocol ReviewCommentLocalDataSource {
    func fetchComments(for context: ReviewDiscussionContext, currentUser: AuthUser?) throws -> [ReviewComment]
    func createComment(draft: ReviewCommentDraft, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment
    func updateComment(commentId: String, content: String, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment
    func deleteComment(commentId: String, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment
    func react(to commentId: String, reaction: ReviewCommentReaction?, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment
    func react(to commentId: String, reaction: ReviewCommentReaction?, currentUser: AuthUser) throws -> ReviewComment
    func fetchCommentCounts(reviewIds: [String]) throws -> [String: Int]
    func fetchMyComments(currentUser: AuthUser?) throws -> [MyReviewCommentEntry]
    func fetchNotifications() throws -> [AppNotification]
    func markAllNotificationsRead() throws
}

final class DefaultReviewCommentLocalDataSource: ReviewCommentLocalDataSource {
    private enum Keys {
        static let comments = "review.comment.records"
        static let notifications = "review.comment.notification.records"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func fetchComments(for context: ReviewDiscussionContext, currentUser: AuthUser?) throws -> [ReviewComment] {
        let records = loadComments().filter { $0.reviewId == context.reviewId }
        return mapComments(records: records, context: context, currentUser: currentUser)
    }

    func createComment(draft: ReviewCommentDraft, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment {
        let trimmedContent = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw ReviewCommentError.invalidContent
        }

        var records = loadComments()
        let normalizedParentId = normalizedParentCommentId(
            from: draft.parentCommentId,
            records: records
        )
        let newRecord = StoredReviewCommentRecord(
            id: UUID().uuidString,
            reviewId: context.reviewId,
            gameId: context.gameId,
            gameTitle: context.gameTitle,
            reviewSnippet: context.reviewSnippet,
            reviewAuthorId: context.reviewAuthor.id,
            reviewAuthorNickname: context.reviewAuthor.nickname,
            reviewAuthorProfileImageUrl: context.reviewAuthor.profileImageUrl,
            parentCommentId: normalizedParentId,
            authorId: currentUser.id,
            authorNickname: currentUser.nickname,
            authorProfileImageUrl: currentUser.profileImageUrl,
            content: trimmedContent,
            createdAt: Date(),
            updatedAt: nil,
            isDeleted: false,
            likeUserIds: [],
            dislikeUserIds: []
        )
        records.append(newRecord)
        try saveComments(records)

        if let parentId = normalizedParentId,
           let parentRecord = records.first(where: { $0.id == parentId }),
           parentRecord.authorId != currentUser.id {
            try appendNotification(
                StoredReviewCommentNotificationRecord(
                    id: UUID().uuidString,
                    type: "review_comment_reply",
                    title: L10n.tr("Localizable", "review.comment.notification.replyTitle"),
                    message: L10n.tr("Localizable", "review.comment.notification.replyBody", context.gameTitle),
                    relatedGameId: context.gameId,
                    relatedReviewId: context.reviewId,
                    relatedCommentId: newRecord.id,
                    isRead: false,
                    createdAt: Date()
                )
            )
        }

        return try requireComment(id: newRecord.id, in: context, currentUser: currentUser)
    }

    func updateComment(commentId: String, content: String, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw ReviewCommentError.invalidContent
        }

        var records = loadComments()
        guard let index = records.firstIndex(where: { $0.id == commentId && $0.reviewId == context.reviewId }) else {
            throw ReviewCommentError.commentNotFound
        }
        guard records[index].authorId == currentUser.id else {
            throw ReviewCommentError.unauthorized
        }

        records[index].content = trimmedContent
        records[index].updatedAt = Date()
        try saveComments(records)
        return try requireComment(id: commentId, in: context, currentUser: currentUser)
    }

    func deleteComment(commentId: String, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment {
        var records = loadComments()
        guard let index = records.firstIndex(where: { $0.id == commentId && $0.reviewId == context.reviewId }) else {
            throw ReviewCommentError.commentNotFound
        }
        guard records[index].authorId == currentUser.id else {
            throw ReviewCommentError.unauthorized
        }

        records[index].isDeleted = true
        records[index].content = ""
        records[index].updatedAt = Date()
        try saveComments(records)
        return try requireComment(id: commentId, in: context, currentUser: currentUser)
    }

    func react(to commentId: String, reaction: ReviewCommentReaction?, in context: ReviewDiscussionContext, currentUser: AuthUser) throws -> ReviewComment {
        try reactInternal(to: commentId, reaction: reaction, currentUser: currentUser, notificationGameTitle: context.gameTitle)
    }

    func react(to commentId: String, reaction: ReviewCommentReaction?, currentUser: AuthUser) throws -> ReviewComment {
        try reactInternal(to: commentId, reaction: reaction, currentUser: currentUser, notificationGameTitle: nil)
    }

    func fetchCommentCounts(reviewIds: [String]) throws -> [String: Int] {
        guard !reviewIds.isEmpty else { return [:] }

        let reviewIdSet = Set(reviewIds)
        let matchingRecords = loadComments().filter { reviewIdSet.contains($0.reviewId) }
        guard !matchingRecords.isEmpty else { return [:] }

        var countsByReviewId = Dictionary(
            uniqueKeysWithValues: Set(matchingRecords.map(\.reviewId)).map { ($0, 0) }
        )

        for record in matchingRecords where !record.isDeleted {
            countsByReviewId[record.reviewId, default: 0] += 1
        }

        return countsByReviewId
    }

    func fetchMyComments(currentUser: AuthUser?) throws -> [MyReviewCommentEntry] {
        guard let currentUser else { return [] }

        let allRecords = loadComments()
        let reviewAuthorByReviewId = allRecords.reduce(into: [String: ReviewAuthor]()) { partialResult, record in
            guard partialResult[record.reviewId] == nil else { return }
            partialResult[record.reviewId] = ReviewAuthor(
                id: record.reviewAuthorId,
                nickname: record.reviewAuthorNickname,
                profileImageUrl: record.reviewAuthorProfileImageUrl
            )
        }
        let groupedReplies = Dictionary(grouping: allRecords.filter { $0.parentCommentId != nil }, by: { $0.parentCommentId ?? "" })

        return allRecords
            .filter { $0.authorId == currentUser.id }
            .sorted { lhs, rhs in
                (lhs.updatedAt ?? lhs.createdAt) > (rhs.updatedAt ?? rhs.createdAt)
            }
            .compactMap { record in
                guard let reviewAuthor = reviewAuthorByReviewId[record.reviewId] else { return nil }
                let myReaction = reaction(for: record, currentUser: currentUser)
                let context = ReviewDiscussionContext(
                    gameId: record.gameId,
                    gameTitle: record.gameTitle,
                    reviewId: record.reviewId,
                    reviewSnippet: record.reviewSnippet,
                    reviewAuthor: reviewAuthor
                )
                let comment = makeComment(
                    from: record,
                    context: context,
                    groupedReplies: groupedReplies,
                    currentUser: currentUser
                )

                return MyReviewCommentEntry(
                    id: record.id,
                    reviewId: record.reviewId,
                    gameId: record.gameId,
                    gameTitle: record.gameTitle,
                    reviewSnippet: record.reviewSnippet,
                    commentContent: comment.content,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    depth: record.parentCommentId == nil ? 0 : 1,
                    isDeleted: record.isDeleted,
                    likeCount: record.likeUserIds.count,
                    dislikeCount: record.dislikeUserIds.count,
                    myReaction: myReaction,
                    comment: comment
                )
            }
    }

    private func reactInternal(
        to commentId: String,
        reaction: ReviewCommentReaction?,
        currentUser: AuthUser,
        notificationGameTitle: String?
    ) throws -> ReviewComment {
        var records = loadComments()
        guard let index = records.firstIndex(where: { $0.id == commentId }) else {
            throw ReviewCommentError.commentNotFound
        }

        records[index].likeUserIds.removeAll { $0 == currentUser.id }
        records[index].dislikeUserIds.removeAll { $0 == currentUser.id }

        switch reaction {
        case .like:
            records[index].likeUserIds.append(currentUser.id)
        case .dislike:
            records[index].dislikeUserIds.append(currentUser.id)
        case .none:
            break
        }

        try saveComments(records)

        if records[index].authorId != currentUser.id,
           let reaction,
           let notificationGameTitle {
            let type = reaction == .like ? "review_comment_like" : "review_comment_dislike"
            let titleKey = reaction == .like
                ? "review.comment.notification.likeTitle"
                : "review.comment.notification.dislikeTitle"
            let bodyKey = reaction == .like
                ? "review.comment.notification.likeBody"
                : "review.comment.notification.dislikeBody"
            try appendNotification(
                StoredReviewCommentNotificationRecord(
                    id: UUID().uuidString,
                    type: type,
                    title: L10n.tr("Localizable", titleKey),
                    message: L10n.tr("Localizable", bodyKey, notificationGameTitle),
                    relatedGameId: records[index].gameId,
                    relatedReviewId: records[index].reviewId,
                    relatedCommentId: commentId,
                    isRead: false,
                    createdAt: Date()
                )
            )
        }

        let record = records[index]
        let reviewAuthor = ReviewAuthor(
            id: record.reviewAuthorId,
            nickname: record.reviewAuthorNickname,
            profileImageUrl: record.reviewAuthorProfileImageUrl
        )
        let context = ReviewDiscussionContext(
            gameId: record.gameId,
            gameTitle: record.gameTitle,
            reviewId: record.reviewId,
            reviewSnippet: record.reviewSnippet,
            reviewAuthor: reviewAuthor
        )
        return try requireComment(id: commentId, in: context, currentUser: currentUser)
    }

    func fetchNotifications() throws -> [AppNotification] {
        try loadNotifications()
            .sorted { $0.createdAt > $1.createdAt }
            .map {
                AppNotification(
                    id: $0.id,
                    type: $0.type,
                    title: $0.title,
                    message: $0.message,
                    relatedGameID: $0.relatedGameId,
                    relatedUserID: nil,
                    relatedReviewID: $0.relatedReviewId,
                    relatedCommentID: $0.relatedCommentId,
                    isRead: $0.isRead,
                    createdAt: $0.createdAt
                )
            }
    }

    func markAllNotificationsRead() throws {
        var notifications = try loadNotifications()
        guard notifications.contains(where: { !$0.isRead }) else { return }
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        do {
            let data = try encoder.encode(notifications)
            userDefaults.set(data, forKey: Keys.notifications)
        } catch {
            throw ReviewCommentError.persistenceFailed
        }
    }

    private func requireComment(id: String, in context: ReviewDiscussionContext, currentUser: AuthUser?) throws -> ReviewComment {
        let comments = try fetchComments(for: context, currentUser: currentUser)
        guard let comment = comments.first(where: { $0.id == id }) else {
            throw ReviewCommentError.commentNotFound
        }
        return comment
    }

    private func normalizedParentCommentId(from parentCommentId: String?, records: [StoredReviewCommentRecord]) -> String? {
        guard let parentCommentId else { return nil }
        guard let parentRecord = records.first(where: { $0.id == parentCommentId }) else {
            return nil
        }
        return parentRecord.parentCommentId ?? parentRecord.id
    }

    private func mapComments(
        records: [StoredReviewCommentRecord],
        context: ReviewDiscussionContext,
        currentUser: AuthUser?
    ) -> [ReviewComment] {
        let groupedReplies = Dictionary(
            grouping: records.filter { $0.parentCommentId != nil },
            by: { $0.parentCommentId ?? "" }
        )
        let rootCommentById = MappingSafety.dictionary(
            pairs: records.map { ($0.id, $0) },
            logPrefix: "[ReviewCommentMapping]",
            keyName: "commentId",
            countLabel: "recordCount",
            screen: "ReviewCommentLocalDataSource.mapComments.rootCommentById",
            mergePolicy: .keepFirst
        )
        let rootCreatedAtByThreadId = MappingSafety.dictionary(
            pairs: records.map { record in
                let rootId = record.parentCommentId ?? record.id
                let rootCreatedAt = rootCommentById[rootId]?.createdAt ?? record.createdAt
                return (record.id, rootCreatedAt)
            },
            logPrefix: "[ReviewCommentMapping]",
            keyName: "commentId",
            countLabel: "recordCount",
            screen: "ReviewCommentLocalDataSource.mapComments.rootCreatedAtByThreadId",
            mergePolicy: .keepFirst
        )

        return records
            .sorted { lhs, rhs in
                commentSort(lhs: lhs, rhs: rhs, rootCreatedAtByThreadId: rootCreatedAtByThreadId)
            }
            .map { record in
                makeComment(
                    from: record,
                    context: context,
                    groupedReplies: groupedReplies,
                    currentUser: currentUser
                )
            }
    }

    private func makeComment(
        from record: StoredReviewCommentRecord,
        context: ReviewDiscussionContext,
        groupedReplies: [String: [StoredReviewCommentRecord]],
        currentUser: AuthUser?
    ) -> ReviewComment {
        ReviewComment(
            id: record.id,
            reviewId: record.reviewId,
            gameId: record.gameId,
            gameTitle: record.gameTitle,
            reviewSnippet: record.reviewSnippet,
            parentCommentId: record.parentCommentId,
            depth: record.parentCommentId == nil ? 0 : 1,
            author: ReviewCommentAuthor(
                id: record.authorId,
                nickname: record.authorNickname,
                profileImageUrl: record.authorProfileImageUrl
            ),
            content: record.isDeleted ? L10n.tr("Localizable", "review.comment.deletedPlaceholder") : record.content,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            isMine: record.authorId == currentUser?.id,
            isReviewAuthor: record.authorId == context.reviewAuthor.id,
            isDeleted: record.isDeleted,
            isEdited: record.updatedAt != nil,
            replyCount: groupedReplies[record.id]?.count ?? 0,
            likeCount: record.likeUserIds.count,
            dislikeCount: record.dislikeUserIds.count,
            myReaction: reaction(for: record, currentUser: currentUser)
        )
    }

    private func reaction(for record: StoredReviewCommentRecord, currentUser: AuthUser?) -> ReviewCommentReaction? {
        if let currentUser, record.likeUserIds.contains(currentUser.id) {
            return .like
        }
        if let currentUser, record.dislikeUserIds.contains(currentUser.id) {
            return .dislike
        }
        return nil
    }

    private func commentSort(
        lhs: StoredReviewCommentRecord,
        rhs: StoredReviewCommentRecord,
        rootCreatedAtByThreadId: [String: Date]
    ) -> Bool {
        let lhsParent = lhs.parentCommentId ?? lhs.id
        let rhsParent = rhs.parentCommentId ?? rhs.id
        if lhsParent != rhsParent {
            let lhsRootCreatedAt = rootCreatedAtByThreadId[lhs.id] ?? lhs.createdAt
            let rhsRootCreatedAt = rootCreatedAtByThreadId[rhs.id] ?? rhs.createdAt
            if lhsRootCreatedAt != rhsRootCreatedAt {
                return lhsRootCreatedAt < rhsRootCreatedAt
            }
            return lhsParent < rhsParent
        }

        if lhs.parentCommentId == nil && rhs.parentCommentId != nil {
            return true
        }
        if lhs.parentCommentId != nil && rhs.parentCommentId == nil {
            return false
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id < rhs.id
    }

    private func appendNotification(_ record: StoredReviewCommentNotificationRecord) throws {
        var notifications = try loadNotifications()
        notifications.append(record)
        do {
            let data = try encoder.encode(notifications)
            userDefaults.set(data, forKey: Keys.notifications)
        } catch {
            throw ReviewCommentError.persistenceFailed
        }
    }

    private func saveComments(_ records: [StoredReviewCommentRecord]) throws {
        do {
            let data = try encoder.encode(records)
            userDefaults.set(data, forKey: Keys.comments)
        } catch {
            throw ReviewCommentError.persistenceFailed
        }
    }

    private func loadComments() -> [StoredReviewCommentRecord] {
        guard let data = userDefaults.data(forKey: Keys.comments),
              let records = try? decoder.decode([StoredReviewCommentRecord].self, from: data) else {
            return []
        }
        return records
    }

    private func loadNotifications() throws -> [StoredReviewCommentNotificationRecord] {
        guard let data = userDefaults.data(forKey: Keys.notifications) else {
            return []
        }
        do {
            return try decoder.decode([StoredReviewCommentNotificationRecord].self, from: data)
        } catch {
            throw ReviewCommentError.persistenceFailed
        }
    }
}

private struct StoredReviewCommentRecord: Codable {
    let id: String
    let reviewId: String
    let gameId: Int
    let gameTitle: String
    let reviewSnippet: String
    let reviewAuthorId: String
    let reviewAuthorNickname: String
    let reviewAuthorProfileImageUrl: String?
    let parentCommentId: String?
    let authorId: String
    let authorNickname: String
    let authorProfileImageUrl: String?
    var content: String
    let createdAt: Date
    var updatedAt: Date?
    var isDeleted: Bool
    var likeUserIds: [String]
    var dislikeUserIds: [String]
}

private struct StoredReviewCommentNotificationRecord: Codable {
    let id: String
    let type: String
    let title: String
    let message: String
    let relatedGameId: Int
    let relatedReviewId: String
    let relatedCommentId: String
    var isRead: Bool
    let createdAt: Date
}
