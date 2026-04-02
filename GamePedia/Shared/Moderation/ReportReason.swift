import Foundation

enum ReportReason: String, CaseIterable, Equatable {
    case spam
    case abusiveOrHateful
    case sexualOrInappropriate
    case misinformation
    case copyrightViolation
    case other

    var title: String {
        switch self {
        case .spam:
            return L10n.Review.Report.reasonSpam
        case .abusiveOrHateful:
            return L10n.Review.Report.reasonAbusive
        case .sexualOrInappropriate:
            return L10n.Review.Report.reasonSexual
        case .misinformation:
            return L10n.Review.Report.reasonMisinformation
        case .copyrightViolation:
            return L10n.Review.Report.reasonCopyright
        case .other:
            return L10n.Review.Report.reasonOther
        }
    }

    var requiresDetailInput: Bool {
        self == .other
    }
}

enum ReportTargetType: String, Equatable {
    case review
}

struct ReportRequest: Equatable {
    let targetType: ReportTargetType
    let targetId: String
    let reportedUserId: String?
    let reportedUserName: String?
    let reason: ReportReason
    let detail: String?
}

struct BlockUserRequest: Equatable {
    let userId: String
    let userName: String
}
