import Foundation

enum APIJSONCoding {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            let value = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: value) {
                return date
            }

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date-time or Unix timestamp."
            )
        }
        return decoder
    }
}
