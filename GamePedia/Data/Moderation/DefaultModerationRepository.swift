import Foundation

final class DefaultModerationRepository: ModerationRepository {

    private let localDataSource: any ModerationLocalDataSource

    init(localDataSource: any ModerationLocalDataSource = DefaultModerationLocalDataSource()) {
        self.localDataSource = localDataSource
    }

    func submitReport(_ request: ReportRequest) async throws {
        guard !request.targetId.isEmpty else {
            throw ModerationError.invalidReportTarget
        }

        try localDataSource.saveReport(request)
    }

    func blockUser(_ request: BlockUserRequest) async throws {
        guard !request.userId.isEmpty else {
            throw ModerationError.invalidBlockedUser
        }

        try localDataSource.saveBlockedUser(request)
    }

    func hiddenReviewIDs() -> Set<String> {
        localDataSource.hiddenReviewIDs()
    }

    func blockedUserIDs() -> Set<String> {
        localDataSource.blockedUserIDs()
    }
}
