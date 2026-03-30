import Foundation

struct SteamPrivacyGuideStep: Hashable {
    let iconSystemName: String
    let title: String
    let detail: String
}

enum SteamPrivacyGuideContent {
    static let settingsURL = URL(string: "https://steamcommunity.com/my/edit/settings")
    static let title = "Steam 공개 설정을 확인해주세요"
    static let summary = "Steam 기본 공개 범위 때문에 보관함이나 최근 플레이 정보를 가져오지 못할 수 있어요."
    static let steps: [SteamPrivacyGuideStep] = [
        SteamPrivacyGuideStep(
            iconSystemName: "safari.fill",
            title: "Steam 앱 또는 웹 열기",
            detail: "Steam 앱이나 Steam Community 웹사이트에 로그인해주세요."
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "person.crop.circle",
            title: "프로필 편집",
            detail: "내 프로필 화면에서 프로필 편집 메뉴를 열어주세요."
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "globe",
            title: "공개 설정",
            detail: "프로필 편집 화면에서 공개 설정 탭으로 이동해주세요."
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "eye.fill",
            title: "프로필: 공개",
            detail: "프로필 공개 범위를 '공개'로 변경해주세요."
        ),
        SteamPrivacyGuideStep(
            iconSystemName: "gamecontroller.fill",
            title: "게임 세부 정보: 공개",
            detail: "게임 세부 정보도 '공개'로 바꿔야 보관함과 최근 플레이 정보를 가져올 수 있어요."
        )
    ]
}
