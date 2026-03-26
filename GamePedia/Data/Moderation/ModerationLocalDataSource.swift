import Foundation

protocol ModerationLocalDataSource {
    func saveReport(_ request: ReportRequest) throws
    func saveBlockedUser(_ request: BlockUserRequest) throws
    func hiddenReviewIDs() -> Set<String>
    func blockedUserIDs() -> Set<String>
}

final class DefaultModerationLocalDataSource: ModerationLocalDataSource {

    private enum Keys {
        static let reports = "moderation.report.records"
        static let blockedUsers = "moderation.blocked-user.records"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let iso8601Formatter = ISO8601DateFormatter()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func saveReport(_ request: ReportRequest) throws {
        var records = loadReportRecords()

        let alreadyStored = records.contains {
            $0.targetType == request.targetType.rawValue && $0.targetId == request.targetId
        }

        if !alreadyStored {
            records.append(
                ReportRecordDTO(
                    targetType: request.targetType.rawValue,
                    targetId: request.targetId,
                    reportedUserId: request.reportedUserId,
                    reportedUserName: request.reportedUserName,
                    reason: request.reason.rawValue,
                    detail: request.detail,
                    createdAt: iso8601Formatter.string(from: Date())
                )
            )
        }

        do {
            let data = try encoder.encode(records)
            userDefaults.set(data, forKey: Keys.reports)
        } catch {
            throw ModerationError.persistenceFailed
        }
    }

    func saveBlockedUser(_ request: BlockUserRequest) throws {
        var records = loadBlockedUserRecords()

        let alreadyStored = records.contains { $0.userId == request.userId }
        if !alreadyStored {
            records.append(
                BlockedUserRecordDTO(
                    userId: request.userId,
                    userName: request.userName,
                    createdAt: iso8601Formatter.string(from: Date())
                )
            )
        }

        do {
            let data = try encoder.encode(records)
            userDefaults.set(data, forKey: Keys.blockedUsers)
        } catch {
            throw ModerationError.persistenceFailed
        }
    }

    func hiddenReviewIDs() -> Set<String> {
        Set(
            loadReportRecords()
                .filter { $0.targetType == ReportTargetType.review.rawValue }
                .map(\.targetId)
        )
    }

    func blockedUserIDs() -> Set<String> {
        Set(loadBlockedUserRecords().map(\.userId))
    }

    private func loadReportRecords() -> [ReportRecordDTO] {
        guard let data = userDefaults.data(forKey: Keys.reports),
              let records = try? decoder.decode([ReportRecordDTO].self, from: data) else {
            return []
        }
        return records
    }

    private func loadBlockedUserRecords() -> [BlockedUserRecordDTO] {
        guard let data = userDefaults.data(forKey: Keys.blockedUsers),
              let records = try? decoder.decode([BlockedUserRecordDTO].self, from: data) else {
            return []
        }
        return records
    }
}

private struct ReportRecordDTO: Codable {
    let targetType: String
    let targetId: String
    let reportedUserId: String?
    let reportedUserName: String?
    let reason: String
    let detail: String?
    let createdAt: String
}

private struct BlockedUserRecordDTO: Codable {
    let userId: String
    let userName: String
    let createdAt: String
}
