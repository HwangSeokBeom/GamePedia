import Foundation

struct SteamPrivacyGuideStep: Hashable {
    let iconSystemName: String
    let title: String
    let detail: String
}

enum SteamPrivacyGuideContent {
    static let settingsURL = URL(string: "https://steamcommunity.com/my/edit/settings")
    static let title = L10n.tr("Localizable", "library.steam.privacy.content.title")
    static let summary = L10n.tr("Localizable", "library.steam.privacy.content.summary")
    static let steps: [SteamPrivacyGuideStep] = [
        SteamPrivacyGuideStep(
            iconSystemName: "safari.fill",
            title: L10n.tr("Localizable", "library.steam.privacy.step.open.title"),
            detail: L10n.tr("Localizable", "library.steam.privacy.step.open.detail")
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "person.crop.circle",
            title: L10n.tr("Localizable", "library.steam.privacy.step.editProfile.title"),
            detail: L10n.tr("Localizable", "library.steam.privacy.step.editProfile.detail")
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "globe",
            title: L10n.tr("Localizable", "library.steam.privacy.step.privacy.title"),
            detail: L10n.tr("Localizable", "library.steam.privacy.step.privacy.detail")
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "eye.fill",
            title: L10n.tr("Localizable", "library.steam.privacy.step.profilePublic.title"),
            detail: L10n.tr("Localizable", "library.steam.privacy.step.profilePublic.detail")
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "gamecontroller.fill",
            title: L10n.tr("Localizable", "library.steam.privacy.step.gameDetailsPublic.title"),
            detail: L10n.tr("Localizable", "library.steam.privacy.step.gameDetailsPublic.detail")
        )
    ]
}
