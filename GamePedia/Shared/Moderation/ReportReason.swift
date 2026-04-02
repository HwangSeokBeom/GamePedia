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
            return "스팸"
        case .abusiveOrHateful:
            return "욕설/혐오 표현"
        case .sexualOrInappropriate:
            return "성적/부적절한 콘텐츠"
        case .misinformation:
            return "허위 정보"
        case .copyrightViolation:
            return "저작권/권리 침해"
        case .other:
            return "기타"
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
