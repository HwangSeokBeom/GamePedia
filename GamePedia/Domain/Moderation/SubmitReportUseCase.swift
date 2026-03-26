import Foundation

final class SubmitReportUseCase {

    private let moderationRepository: any ModerationRepository

    init(moderationRepository: any ModerationRepository) {
        self.moderationRepository = moderationRepository
    }

    func execute(request: ReportRequest) async throws {
        try await moderationRepository.submitReport(request)
    }
}
