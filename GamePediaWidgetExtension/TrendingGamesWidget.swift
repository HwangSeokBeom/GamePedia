import SwiftUI
import WidgetKit

struct TrendingGamesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: GameWidgetKind.trendingGames,
            provider: TrendingGamesWidgetProvider()
        ) { entry in
            TrendingGamesWidgetView(entry: entry)
        }
        .configurationDisplayName("인기/추천 게임")
        .description("인기 게임을 홈 화면에서 바로 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TrendingGamesWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TrendingGamesWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                TrendingGamesSmallView(item: entry.snapshot.items.first)
            default:
                TrendingGamesMediumView(items: entry.snapshot.items)
            }
        }
        .gamePediaWidgetBackground()
    }
}

private struct TrendingGamesSmallView: View {
    let item: TrendingGamesWidgetSnapshot.Item?

    var body: some View {
        let primaryItem = item ?? TrendingGamesWidgetSnapshot.placeholder.items[0]

        ZStack(alignment: .bottomLeading) {
            WidgetArtworkView(url: primaryItem.coverImageURL, cornerRadius: 22)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.14),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    RankBadge(rank: primaryItem.rank)
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryItem.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(2)

                    Text(primaryItem.genreText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WidgetTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
        }
        .widgetURL(primaryItem.targetURL ?? WidgetDeepLinkURL.trending)
    }
}

private struct TrendingGamesMediumView: View {
    let items: [TrendingGamesWidgetSnapshot.Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                WidgetSectionLabel(title: "Trending")
                Spacer()
                Text("TOP 3")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.accentSoft)
            }

            VStack(spacing: 10) {
                ForEach(items.isEmpty ? TrendingGamesWidgetSnapshot.placeholder.items : items, id: \.gameID) { item in
                    Link(destination: item.targetURL ?? WidgetDeepLinkURL.trending) {
                        TrendingGameRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .widgetURL(WidgetDeepLinkURL.trending)
    }
}

private struct TrendingGameRow: View {
    let item: TrendingGamesWidgetSnapshot.Item

    var body: some View {
        HStack(spacing: 10) {
            RankBadge(rank: item.rank)

            WidgetArtworkView(url: item.coverImageURL, cornerRadius: 12)
                .frame(width: 42, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)

                Text(item.genreText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let ratingText = item.ratingText, ratingText.isEmpty == false {
                Text("★ \(ratingText)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.accentSoft)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

private struct RankBadge: View {
    let rank: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: rank == 1 ? "flame.fill" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 11, weight: .bold))
            Text("#\(rank)")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(WidgetTheme.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(rank == 1 ? WidgetTheme.accent : WidgetTheme.surfaceSecondary)
        )
    }
}
