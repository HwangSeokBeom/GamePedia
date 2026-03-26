import Foundation

// MARK: - NetworkError

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingFailed(Error)
    case serverError(statusCode: Int, code: String?, message: String?)
    case unauthorized
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .noData:
            return "데이터가 없습니다."
        case .decodingFailed(let error):
            return "데이터 파싱 실패: \(error.localizedDescription)"
        case .serverError(let statusCode, _, let message):
            return "서버 오류 (\(statusCode)): \(message ?? "알 수 없는 오류")"
        case .unauthorized:
            return "인증이 필요합니다."
        case .unknown(let error):
            return "알 수 없는 오류: \(error.localizedDescription)"
        }
    }

    var serverCode: String? {
        if case .serverError(_, let code, _) = self {
            return code
        }
        return nil
    }

    var serverMessage: String? {
        if case .serverError(_, _, let message) = self {
            return message
        }
        return nil
    }
}
