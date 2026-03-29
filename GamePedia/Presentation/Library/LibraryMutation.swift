import Foundation

enum LibraryMutation {
    case setLoading(Bool)
    case setRefreshing(Bool)
    case setSort(LibrarySortOption)
    case setSections([LibrarySectionViewState])
    case setError(String)
    case clearError
    case consumeInitialFocus
}
