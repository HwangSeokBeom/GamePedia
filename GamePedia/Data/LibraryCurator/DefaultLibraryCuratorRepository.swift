import Foundation

final class DefaultLibraryCuratorRepository: LibraryCuratorRepository {
    private let remoteDataSource: any LibraryCuratorRemoteDataSource

    init(remoteDataSource: any LibraryCuratorRemoteDataSource = DefaultLibraryCuratorRemoteDataSource()) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchCuratorResult(request: LibraryCuratorRequest) async throws -> LibraryCuratorResult {
        do {
            let requestDTO = LibraryCuratorRequestDTO(
                query: sanitizedQuery(request.query),
                mode: request.mode.rawValue,
                limit: request.limit,
                locale: request.locale,
                candidateScope: request.candidateScope.rawValue,
                excludedGameIds: request.excludedGameIds
            )
#if DEBUG
            print(
                "[LibraryCurator] repositoryRequest " +
                "mode=\(requestDTO.mode) " +
                "locale=\(requestDTO.locale) " +
                "candidateScope=\(requestDTO.candidateScope) " +
                "limit=\(requestDTO.limit) " +
                "queryExists=\(!(requestDTO.query?.isEmpty ?? true))"
            )
#endif
            let responseDTO = try await remoteDataSource.fetchCuratorResult(requestDTO: requestDTO)
            let result = LibraryCuratorMapper.toEntity(responseDTO)
#if DEBUG
            if result.isFallback {
                print(
                    "[LibraryCurator] fallback source " +
                    "reason=\(result.meta.fallbackReason ?? "nil") " +
                    "candidateCount=\(result.meta.candidateCount) " +
                    "selectedCount=\(result.meta.selectedCount)"
                )
            } else {
                print(
                    "[LibraryCurator] repositoryResponse " +
                    "source=\(result.source) " +
                    "candidateCount=\(result.meta.candidateCount) " +
                    "selectedCount=\(result.meta.selectedCount)"
                )
            }
#endif
            return result
        } catch {
#if DEBUG
            print("[LibraryCurator] decodeFailed error=\(error)")
#endif
            throw LibraryCuratorError.from(error: error)
        }
    }

    private func sanitizedQuery(_ query: String?) -> String? {
        guard let query else { return nil }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? nil : trimmedQuery
    }
}
