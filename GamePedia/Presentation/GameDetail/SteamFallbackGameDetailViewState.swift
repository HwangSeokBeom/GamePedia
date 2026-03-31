import Foundation

struct SteamFallbackGameDetailViewState: Hashable {
    let title: String
    let coverImageURL: URL?
    let fallbackCoverImageURLs: [URL]
    let sourceLabelText: String
    let metadataText: String
    let descriptionText: String
    let playtimeValueText: String?
    let externalGameId: String
    let gameSource: GameSource
    let metadataEnriched: Bool
    let matchStatus: LibraryGameMatchStatus
}
