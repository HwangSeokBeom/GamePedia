import XCTest
@testable import GamePedia

final class RecommendationTagLocalizerTests: XCTestCase {
    func testKoreanLocalizesRequiredTagAliases() {
        XCTAssertEqual(localized("relaxing visual novel", language: .korean), ["힐링 비주얼 노벨"])
        XCTAssertEqual(localized("short interactive story", language: .korean), ["짧은 인터랙티브 스토리"])
        XCTAssertEqual(localized("Visual Novel", language: .korean), ["비주얼 노벨"])
        XCTAssertEqual(localized("singleplayer", language: .korean), ["싱글플레이"])
        XCTAssertEqual(localized("low", language: .korean), ["낮은 난이도"])
        XCTAssertEqual(localized("balanced", language: .korean), ["균형형"])
    }

    func testEnglishNormalizesMachineReadableTags() {
        XCTAssertEqual(localized("short_interactive_story", language: .english), ["Short Interactive Story"])
        XCTAssertEqual(localized("visual_novel", language: .english), ["Visual Novel"])
        XCTAssertEqual(localized("ShortInteractiveStory", language: .english), ["Short Interactive Story"])
        XCTAssertEqual(localized("single_player", language: .english), ["Singleplayer"])
    }

    func testUnknownTagUsesReadableFallback() {
        XCTAssertEqual(localized("unknown_tag_name", language: .english), ["Unknown Tag Name"])
    }

    func testDuplicatesAreRemovedByCanonicalKey() {
        let tags = RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: ["Visual Novel", "visual_novel", "visual novel"],
            language: .korean,
            maxCount: 4,
            screen: "Test"
        )

        XCTAssertEqual(tags, ["비주얼 노벨"])
    }

    func testMaxCountIsApplied() {
        let tags = RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: ["personalized", "relaxing", "short", "singleplayer", "visual novel"],
            language: .korean,
            maxCount: 3,
            screen: "Test"
        )

        XCTAssertEqual(tags, ["맞춤", "힐링", "짧은 세션"])
    }

    func testJapaneseAndChineseUseCanonicalKeys() {
        XCTAssertEqual(localized("short_interactive_story", language: .japanese), ["短編インタラクティブストーリー"])
        XCTAssertEqual(localized("short_interactive_story", language: .chinese), ["短篇互动故事"])
    }

    private func localized(_ rawTag: String, language: AppLanguage) -> [String] {
        RecommendationTagLocalizer.localizedDisplayTags(
            rawTags: [rawTag],
            language: language,
            maxCount: 4,
            screen: "Test"
        )
    }
}
