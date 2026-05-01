import Foundation

// MARK: - NetworkError

enum NetworkError: Error, LocalizedError {
    case configurationMissing(String)
    case invalidURL
    case noData
    case decodingFailed(Error)
    case rateLimited(statusCode: Int, code: String?, message: String?)
    case serverError(statusCode: Int, code: String?, message: String?)
    case unauthorized
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .configurationMissing(let message):
            return message
        case .invalidURL:
            return L10n.Common.Error.invalidURL
        case .noData:
            return L10n.Common.Error.noData
        case .decodingFailed(let error):
            return L10n.Common.Error.decodingFailed(error.localizedDescription)
        case .rateLimited(let statusCode, _, let message):
            return L10n.Common.Error.serverStatus(statusCode, message ?? L10n.Common.Error.unknown)
        case .serverError(let statusCode, _, let message):
            return L10n.Common.Error.serverStatus(statusCode, message ?? L10n.Common.Error.unknown)
        case .unauthorized:
            return L10n.Common.Error.unauthorized
        case .unknown(let error):
            return L10n.Common.Error.unknownWithMessage(error.localizedDescription)
        }
    }

    var serverCode: String? {
        if case .serverError(_, let code, _) = self {
            return code
        }
        if case .rateLimited(_, let code, _) = self {
            return code
        }
        return nil
    }

    var serverMessage: String? {
        if case .serverError(_, _, let message) = self {
            return message
        }
        if case .rateLimited(_, _, let message) = self {
            return message
        }
        return nil
    }
}
