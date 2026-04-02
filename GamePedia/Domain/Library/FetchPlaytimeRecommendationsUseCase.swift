import Foundation

struct FetchPlaytimeRecommendationsUseCase {
    let libraryRepository: any LibraryRepository

    func execute() async throws -> [PlaytimeRecommendation] {
        try await libraryRepository.fetchPlaytimeRecommendations()
    }
}
