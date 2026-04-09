import SwiftUI
import WidgetKit

struct ReviewPromptWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: GameWidgetKind.reviewPrompt,
            provider: ReviewPromptWidgetProvider()
        ) { entry in
            ReviewPromptWidgetView(entry: entry)
        }
        .configurationDisplayName("리뷰 유도")
        .description("찜한 게임의 리뷰 작성을 홈 화면에서 바로 이어갑니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct ReviewPromptWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ReviewPromptWidgetEntry

    var body: some View {
        Group {
            switch entry.snapshot.state {
            case .ready:
                switch family {
                case .systemSmall:
                    ReviewPromptSmallView(snapshot: entry.snapshot)
                case .systemMedium:
                    ReviewPromptMediumView(snapshot: entry.snapshot)
                default:
                    ReviewPromptLargeView(snapshot: entry.snapshot)
                }
            case .empty:
                WidgetMessageCard(
                    headerTitle: entry.snapshot.headerTitle,
                    systemImageName: "pencil",
                    headlineText: entry.snapshot.headlineText,
                    bodyText: entry.snapshot.bodyText,
                    targetURL: entry.snapshot.targetURL ?? WidgetDeepLinkURL.trending
                )
            case .loggedOut:
                LoggedOutWidgetCard(content: entry.snapshot.loggedOutContent ?? .placeholder)
            }
        }
        .gamePediaWidgetBackground()
    }
}

private struct ReviewPromptSmallView: View {
    let snapshot: ReviewPromptWidgetSnapshot

    private var item: ReviewPromptWidgetSnapshot.Item {
        snapshot.item ?? ReviewPromptWidgetSnapshot.Item(
            gameID: -1,
            title: "리뷰할 게임",
            subtitleText: "찜했지만 아직 리뷰가 없어요",
            coverImageURL: nil,
            gameTargetURL: WidgetDeepLinkURL.trending,
            reviewTargetURL: WidgetDeepLinkURL.trending
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: snapshot.headerTitle, systemImageName: "pencil")

            Link(destination: item.gameTargetURL ?? WidgetDeepLinkURL.trending) {
                HStack(spacing: 10) {
                    WidgetArtworkView(url: item.coverImageURL, cornerRadius: 10)
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(WidgetTheme.textPrimary)
                            .lineLimit(2)

                        Text(item.subtitleText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetTheme.textTertiary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Link(destination: item.reviewTargetURL ?? WidgetDeepLinkURL.trending) {
                WidgetCTAButton(title: snapshot.ctaTitle ?? "리뷰 작성하기", fill: WidgetTheme.coral)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }
}

private struct ReviewPromptMediumView: View {
    let snapshot: ReviewPromptWidgetSnapshot

    var body: some View {
        let item = snapshot.item

        HStack(spacing: 12) {
            Link(destination: item?.gameTargetURL ?? WidgetDeepLinkURL.trending) {
                WidgetArtworkView(url: item?.coverImageURL, cornerRadius: 14)
                    .frame(width: 90, height: 124)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(title: snapshot.headerTitle, systemImageName: "pencil")

                Text(item?.title ?? snapshot.headlineText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(2)

                Text(item?.subtitleText ?? snapshot.bodyText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(3)

                Spacer(minLength: 0)

                if let ctaTitle = snapshot.ctaTitle {
                    Link(destination: item?.reviewTargetURL ?? snapshot.targetURL ?? WidgetDeepLinkURL.trending) {
                        WidgetCTAButton(title: ctaTitle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .widgetURL(item?.gameTargetURL ?? snapshot.targetURL ?? WidgetDeepLinkURL.trending)
    }
}

private struct ReviewPromptLargeView: View {
    let snapshot: ReviewPromptWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: snapshot.headerTitle, systemImageName: "pencil")

            Text(snapshot.bodyText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(1)

            VStack(spacing: 8) {
                ForEach(snapshot.items.prefix(4)) { item in
                    ReviewPromptLargeRow(item: item)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct ReviewPromptLargeRow: View {
    let item: ReviewPromptWidgetSnapshot.Item

    var body: some View {
        HStack(spacing: 10) {
            Link(destination: item.gameTargetURL ?? WidgetDeepLinkURL.trending) {
                HStack(spacing: 10) {
                    WidgetArtworkView(url: item.coverImageURL, cornerRadius: 10)
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(WidgetTheme.textPrimary)
                            .lineLimit(1)

                        Text(item.subtitleText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetTheme.textTertiary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Link(destination: item.reviewTargetURL ?? WidgetDeepLinkURL.trending) {
                WidgetCTAButton(title: "작성", fill: WidgetTheme.coral, compact: true)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

#if DEBUG
#Preview("Review Prompt Small", as: .systemSmall) {
    ReviewPromptWidget()
} timeline: {
    ReviewPromptWidgetEntry(date: .now, snapshot: reviewPromptPreviewSnapshot)
}

#Preview("Review Prompt Large", as: .systemLarge) {
    ReviewPromptWidget()
} timeline: {
    ReviewPromptWidgetEntry(date: .now, snapshot: reviewPromptPreviewSnapshot)
}

private let reviewPromptPreviewSnapshot = ReviewPromptWidgetSnapshot(
    generatedAt: .now,
    state: .ready,
    headerTitle: "리뷰 남기기",
    headlineText: "엘든 링",
    bodyText: "찜했지만 아직 리뷰를 남기지 않은 게임",
    ctaTitle: "리뷰 작성하기",
    targetURL: URL(string: "gamepedia://review/new/301"),
    items: [
        .init(
            gameID: 301,
            title: "엘든 링",
            subtitleText: "찜했지만 아직 리뷰를 남기지 않았어요",
            coverImageURL: URL(string: "https://example.com/review-preview-1.jpg"),
            gameTargetURL: URL(string: "gamepedia://game/301"),
            reviewTargetURL: URL(string: "gamepedia://review/new/301")
        ),
        .init(
            gameID: 302,
            title: "하데스 2",
            subtitleText: "플레이 감상을 짧게 남겨보세요",
            coverImageURL: URL(string: "https://example.com/review-preview-2.jpg"),
            gameTargetURL: URL(string: "gamepedia://game/302"),
            reviewTargetURL: URL(string: "gamepedia://review/new/302")
        ),
        .init(
            gameID: 303,
            title: "발더스 게이트 3",
            subtitleText: "지금의 감상이 가장 정확해요",
            coverImageURL: URL(string: "https://example.com/review-preview-3.jpg"),
            gameTargetURL: URL(string: "gamepedia://game/303"),
            reviewTargetURL: URL(string: "gamepedia://review/new/303")
        ),
        .init(
            gameID: 304,
            title: "사이버펑크 2077",
            subtitleText: "최근 플레이 경험을 정리해보세요",
            coverImageURL: URL(string: "https://example.com/review-preview-4.jpg"),
            gameTargetURL: URL(string: "gamepedia://game/304"),
            reviewTargetURL: URL(string: "gamepedia://review/new/304")
        )
    ],
    loggedOutContent: nil
)
#endif
