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

    private var displayItems: [TrendingGamesWidgetSnapshot.Item] {
        items.isEmpty ? TrendingGamesWidgetSnapshot.placeholder.items : items
    }

    var body: some View {
        let headerSpacing: CGFloat = 6

        VStack(alignment: .leading, spacing: headerSpacing) {
            TrendingGamesMediumHeader()

            GeometryReader { proxy in
                let rowSpacing: CGFloat = 4
                let bottomInset: CGFloat = 8
                let rowHeight = max(30, floor((proxy.size.height - bottomInset - (rowSpacing * 2)) / 3))

                VStack(spacing: rowSpacing) {
                    ForEach(displayItems) { item in
                        Link(destination: item.targetURL ?? WidgetDeepLinkURL.trending) {
                            TrendingGameRow(item: item)
                                .frame(height: rowHeight)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, bottomInset)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 15)
        .padding(.horizontal, 9)
        .widgetURL(WidgetDeepLinkURL.trending)
    }
}

private struct TrendingGameRow: View {
    let item: TrendingGamesWidgetSnapshot.Item

    var body: some View {
        HStack(spacing: 10) {
            Text("\(item.rank)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(item.rank == 1 ? WidgetTheme.accent : WidgetTheme.textTertiary)
                .frame(minWidth: 12, alignment: .center)

            WidgetArtworkView(url: item.coverImageURL, cornerRadius: 10)
                .frame(width: 54)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)

                TrendingGameRowSubtitle(item: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.trailing, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(WidgetTheme.surface)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

private struct TrendingGamesMediumHeader: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetTheme.accent)

                Text("인기 게임")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
            }

            Spacer(minLength: 0)

            Text("G")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WidgetTheme.textPrimary)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(red: 0.39, green: 0.40, blue: 0.95))
                )
        }
    }
}

private struct TrendingGameRowSubtitle: View {
    let item: TrendingGamesWidgetSnapshot.Item

    var body: some View {
        if let ratingText = item.ratingText, ratingText.isEmpty == false {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.71, blue: 0.28))

                Text(ratingText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetTheme.accentSoft)
                    .lineLimit(1)
            }
        } else {
            Text(item.genreText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(1)
        }
    }
}
