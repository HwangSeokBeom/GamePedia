import Foundation

struct AddFavoriteRequestDTO: Encodable {
    let gameId: String
}

struct FavoriteResponseEnvelopeDTO<DataDTO: Decodable>: Decodable {
    let success: Bool
    let data: DataDTO
}

struct FavoriteMutationResponseDataDTO: Decodable {
    let favorited: Bool
    let gameId: String
}

struct FavoriteItemDTO: Decodable {
    let gameId: String
    let createdAt: String
}

struct FavoriteListResponseDataDTO: Decodable {
    let favorites: [FavoriteItemDTO]
}

struct FavoriteStatusResponseDataDTO: Decodable {
    let isFavorite: Bool
}
