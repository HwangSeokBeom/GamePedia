import Foundation

enum FavoriteMapper {
    private static let dateFormatter = ISO8601DateFormatter()

    static func toItemEntity(_ dto: FavoriteItemDTO) throws -> FavoriteItem {
        guard let gameId = Int(dto.gameId) else {
            throw FavoriteError.invalidResponse
        }

        return FavoriteItem(
            gameId: gameId,
            createdAt: dateFormatter.date(from: dto.createdAt)
        )
    }

    static func toItems(_ dtos: [FavoriteItemDTO]) throws -> [FavoriteItem] {
        try dtos.map(toItemEntity)
    }

    static func toStatusEntity(gameId: Int, dto: FavoriteStatusResponseDataDTO) -> FavoriteStatus {
        FavoriteStatus(isFavorite: dto.isFavorite)
    }

    static func toMutationResult(_ dto: FavoriteMutationResponseDataDTO) throws -> FavoriteMutationResult {
        guard let gameId = Int(dto.gameId) else {
            throw FavoriteError.invalidResponse
        }

        return FavoriteMutationResult(
            gameId: gameId,
            isFavorite: dto.favorited
        )
    }
}
