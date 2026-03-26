import Foundation

protocol ModerationRepository {
    func submitReport(_ request: ReportRequest) async throws
    func blockUser(_ request: BlockUserRequest) async throws
    func hiddenReviewIDs() -> Set<String>
    func blockedUserIDs() -> Set<String>
}
