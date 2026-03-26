import Foundation

final class BlockUserUseCase {

    private let moderationRepository: any ModerationRepository

    init(moderationRepository: any ModerationRepository) {
        self.moderationRepository = moderationRepository
    }

    func execute(request: BlockUserRequest) async throws {
        try await moderationRepository.blockUser(request)
    }
}
