import Foundation

enum ReviewMapper {

    static func toEntity(_ dto: ReviewDTO) -> Review {
        Review(
            id: dto.id,
            authorName: dto.userName,
            authorAvatarURL: dto.userAvatarUrl.flatMap(URL.init(string:)),
            rating: dto.rating,
            body: dto.body,
            isSpoiler: dto.isSpoiler,
            formattedDate: dto.createdAt.toRelativeDateString()
        )
    }
}
