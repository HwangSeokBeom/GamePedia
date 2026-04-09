import SwiftUI
import WidgetKit

struct RecentViewedGamesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: GameWidgetKind.recentViewed,
            provider: RecentViewedWidgetProvider()
        ) { entry in
            RecentViewedWidgetView(entry: entry)
        }
        .configurationDisplayName("최근 본 게임")
        .description("최근 본 게임을 홈 화면에서 빠르게 다시 엽니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct RecentViewedWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: RecentViewedWidgetEntry

    var body: some View {
        Group {
            if entry.snapshot.state == .empty {
                WidgetMessageCard(
                    headerTitle: entry.snapshot.headerTitle,
                    systemImageName: "clock",
                    headlineText: entry.snapshot.headlineText,
                    bodyText: entry.snapshot.bodyText,
                    targetURL: entry.snapshot.targetURL ?? WidgetDeepLinkURL.trending
                )
            } else {
                switch family {
                case .systemSmall:
                    RecentViewedSmallView(item: displayItems.first)
                case .systemMedium:
                    RecentViewedMediumView(items: Array(displayItems.prefix(2)))
                default:
                    RecentViewedLargeView(snapshot: entry.snapshot, items: Array(displayItems.prefix(4)))
                }
            }
        }
        .gamePediaWidgetBackground()
    }

    private var displayItems: [RecentViewedWidgetSnapshot.Item] {
        entry.snapshot.items.isEmpty ? RecentViewedWidgetSnapshot.placeholder.items : entry.snapshot.items
    }
}

private struct RecentViewedSmallView: View {
    let item: RecentViewedWidgetSnapshot.Item?

    var body: some View {
        let item = item ?? RecentViewedWidgetSnapshot.placeholder.items[0]

        ZStack(alignment: .bottomLeading) {
            WidgetArtworkView(imageKey: item.coverImageKey, cornerRadius: 22)

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.2),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    WidgetBrandBadge()
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.genreText.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WidgetTheme.textSecondary)
                        .lineLimit(1)

                    Text(item.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(2)

                    RecentViewedRatingRow(ratingText: item.ratingText)
                }
            }
            .padding(12)
        }
        .widgetURL(item.targetURL ?? WidgetDeepLinkURL.trending)
    }
}

private struct RecentViewedMediumView: View {
    let items: [RecentViewedWidgetSnapshot.Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: "최근 본 게임", systemImageName: "clock")

            HStack(spacing: 10) {
                ForEach(items) { item in
                    Link(destination: item.targetURL ?? WidgetDeepLinkURL.trending) {
                        RecentViewedMediumCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct RecentViewedLargeView: View {
    let snapshot: RecentViewedWidgetSnapshot
    let items: [RecentViewedWidgetSnapshot.Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: snapshot.headerTitle, systemImageName: "clock")

            VStack(spacing: 8) {
                ForEach(items) { item in
                    Link(destination: item.targetURL ?? WidgetDeepLinkURL.trending) {
                        RecentViewedLargeRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

private struct RecentViewedMediumCard: View {
    let item: RecentViewedWidgetSnapshot.Item

    var body: some View {
        HStack(spacing: 10) {
            WidgetArtworkView(imageKey: item.coverImageKey, cornerRadius: 14)
                .frame(width: 74, height: 106)

            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)

                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(2)

                Text(item.genreText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)

                RecentViewedRatingRow(ratingText: item.ratingText)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

private struct RecentViewedLargeRow: View {
    let item: RecentViewedWidgetSnapshot.Item

    var body: some View {
        HStack(spacing: 10) {
            WidgetArtworkView(imageKey: item.coverImageKey, cornerRadius: 12)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)

                Text(item.genreText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)

                RecentViewedRatingRow(ratingText: item.ratingText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.viewedRelativeText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetTheme.textTertiary)
                .multilineTextAlignment(.trailing)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

private struct RecentViewedRatingRow: View {
    let ratingText: String?

    var body: some View {
        if let ratingText, ratingText.isEmpty == false {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.73, blue: 0.31))

                Text(ratingText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.accentSoft)
                    .lineLimit(1)
            }
        }
    }
}

#if DEBUG
#Preview("Recent Viewed Empty", as: .systemMedium) {
    RecentViewedGamesWidget()
} timeline: {
    RecentViewedWidgetEntry(date: .now, snapshot: .empty)
}

#Preview("Recent Viewed Populated", as: .systemLarge) {
    RecentViewedGamesWidget()
} timeline: {
    RecentViewedWidgetEntry(date: .now, snapshot: .placeholder)
}
#endif
