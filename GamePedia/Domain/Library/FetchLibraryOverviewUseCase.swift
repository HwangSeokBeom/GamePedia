import Foundation

struct FetchLibraryOverviewUseCase {
    let libraryRepository: any LibraryRepository

    func execute(sort: UserGameCollectionSortOption?) async throws -> LibraryOverview {
        try await libraryRepository.fetchLibraryOverview(sort: sort)
    }
}
