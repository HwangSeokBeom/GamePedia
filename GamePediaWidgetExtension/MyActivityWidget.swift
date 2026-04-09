import SwiftUI
import WidgetKit

struct MyActivityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: GameWidgetKind.myActivity,
            provider: MyActivityWidgetProvider()
        ) { entry in
            MyActivityWidgetView(entry: entry)
        }
        .configurationDisplayName("내 활동")
        .description("작성 리뷰, 찜, 좋아요와 최근 리뷰를 홈 화면에서 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct MyActivityWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: MyActivityWidgetEntry

    var body: some View {
        Group {
            switch entry.snapshot.state {
            case .loggedOut:
                LoggedOutWidgetCard(content: entry.snapshot.loggedOutContent ?? .placeholder)
            case .empty:
                WidgetMessageCard(
                    headerTitle: entry.snapshot.headerTitle,
                    systemImageName: "person.crop.circle",
                    headlineText: entry.snapshot.headlineText,
                    bodyText: entry.snapshot.bodyText,
                    targetURL: entry.snapshot.targetURL ?? WidgetDeepLinkURL.trending
                )
            case .ready:
                switch family {
                case .systemSmall:
                    MyActivitySmallView(snapshot: entry.snapshot)
                case .systemMedium:
                    MyActivityMediumView(snapshot: entry.snapshot)
                default:
                    MyActivityLargeView(snapshot: entry.snapshot)
                }
            }
        }
        .gamePediaWidgetBackground()
    }
}

private struct MyActivitySmallView: View {
    let snapshot: MyActivityWidgetSnapshot

    private var primaryStat: MyActivityWidgetSnapshot.StatItem? {
        snapshot.stats.first(where: { $0.kind == .reviews })
    }

    private var reviewCount: String {
        primaryStat?.valueText ?? "0"
    }

    private var primaryStatTitle: String {
        primaryStat?.labelText ?? "작성 리뷰"
    }

    private var wishlistCount: String {
        snapshot.stats.first(where: { $0.kind == .wishlist })?.valueText ?? "0"
    }

    private var likeCount: String {
        snapshot.stats.first(where: { $0.kind == .likes })?.valueText ?? "0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: snapshot.headerTitle, systemImageName: "person.crop.circle")

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(reviewCount)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)

                Text(primaryStatTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                MyActivityMiniStat(
                    systemImageName: "bookmark",
                    value: wishlistCount,
                    title: "찜",
                    tint: WidgetTheme.emerald
                )
                MyActivityMiniStat(
                    systemImageName: "heart",
                    value: likeCount,
                    title: "좋아요",
                    tint: WidgetTheme.coral
                )
            }
        }
        .padding(16)
        .widgetURL(snapshot.targetURL ?? WidgetDeepLinkURL.profile)
    }
}

private struct MyActivityMediumView: View {
    let snapshot: MyActivityWidgetSnapshot

    private var primaryStat: MyActivityWidgetSnapshot.StatItem? {
        snapshot.stats.first(where: { $0.kind == .reviews })
    }

    private var reviewCount: String {
        primaryStat?.valueText ?? "0"
    }

    private var primaryStatTitle: String {
        primaryStat?.labelText ?? "작성 리뷰"
    }

    private var wishlistCount: String {
        snapshot.stats.first(where: { $0.kind == .wishlist })?.valueText ?? "0"
    }

    private var likeCount: String {
        snapshot.stats.first(where: { $0.kind == .likes })?.valueText ?? "0"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                MyActivityMediumPrimaryStat(value: reviewCount, title: primaryStatTitle)

                MyActivityMediumSecondaryStat(
                    wishlistCount: wishlistCount,
                    likeCount: likeCount
                )
            }
            .frame(maxWidth: .infinity)

            if let review = snapshot.featuredReview {
                Link(destination: review.targetURL ?? WidgetDeepLinkURL.profile) {
                    MyActivityFeaturedReviewCard(review: review)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            } else {
                MyActivityNoReviewCard()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .topLeading) {
            WidgetHeader(title: snapshot.headerTitle, systemImageName: "person.crop.circle")
                .padding(.horizontal, 16)
                .padding(.top, 14)
        }
        .padding(.top, 18)
        .widgetURL(snapshot.targetURL ?? WidgetDeepLinkURL.profile)
    }
}

private struct MyActivityLargeView: View {
    let snapshot: MyActivityWidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: snapshot.headerTitle, systemImageName: "person.crop.circle")

            HStack(spacing: 8) {
                ForEach(snapshot.stats) { stat in
                    WidgetStatCard(
                        title: stat.labelText,
                        value: stat.valueText,
                        tint: tint(for: stat.kind)
                    )
                    .frame(height: 58)
                }
            }

            Divider()
                .overlay(WidgetTheme.border)

            Text("최근 리뷰")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)

            VStack(spacing: 8) {
                if snapshot.recentReviews.isEmpty {
                    MyActivityNoReviewCard()
                } else {
                    ForEach(snapshot.recentReviews.prefix(2)) { review in
                        Link(destination: review.targetURL ?? WidgetDeepLinkURL.profile) {
                            MyActivityReviewRow(review: review)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .widgetURL(snapshot.targetURL ?? WidgetDeepLinkURL.profile)
    }

    private func tint(for kind: MyActivityWidgetSnapshot.StatItem.Kind) -> Color {
        switch kind {
        case .reviews:
            return WidgetTheme.textPrimary
        case .wishlist:
            return WidgetTheme.emerald
        case .likes:
            return WidgetTheme.coral
        }
    }
}

private struct MyActivityMiniStat: View {
    let systemImageName: String
    let value: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImageName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textTertiary)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textTertiary)
        }
    }
}

private struct MyActivityMediumPrimaryStat: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetTheme.indigo)

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

private struct MyActivityMediumSecondaryStat: View {
    let wishlistCount: String
    let likeCount: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark")
                    .foregroundStyle(WidgetTheme.emerald)
                Text("\(wishlistCount) 찜")
            }

            HStack(spacing: 6) {
                Image(systemName: "heart")
                    .foregroundStyle(WidgetTheme.coral)
                Text("\(likeCount) 좋아요")
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(WidgetTheme.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

private struct MyActivityFeaturedReviewCard: View {
    let review: MyActivityWidgetSnapshot.ReviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("최근 리뷰")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.textTertiary)

            Text(review.gameTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.73, blue: 0.31))
                Text(review.ratingText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WidgetTheme.accentSoft)
            }

            Text(review.reviewText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text(review.relativeDateText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WidgetTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

private struct MyActivityReviewRow: View {
    let review: MyActivityWidgetSnapshot.ReviewItem

    var body: some View {
        HStack(spacing: 10) {
            WidgetArtworkView(url: review.coverImageURL, cornerRadius: 10)
                .frame(width: 50, height: 68)

            VStack(alignment: .leading, spacing: 4) {
                Text(review.gameTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.73, blue: 0.31))
                    Text(review.ratingText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WidgetTheme.accentSoft)
                }

                Text(review.reviewText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(2)

                Text(review.relativeDateText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WidgetTheme.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

#if DEBUG
#Preview("My Activity Logged Out", as: .systemMedium) {
    MyActivityWidget()
} timeline: {
    MyActivityWidgetEntry(
        date: .now,
        snapshot: MyActivityWidgetSnapshot(
            generatedAt: .now,
            state: .loggedOut,
            headerTitle: "내 활동",
            headlineText: WidgetLoggedOutContent.placeholder.headlineText,
            bodyText: WidgetLoggedOutContent.placeholder.bodyText,
            targetURL: WidgetDeepLinkURL.login,
            stats: [],
            recentReviews: [],
            loggedOutContent: .placeholder
        )
    )
}

#Preview("My Activity Ready", as: .systemLarge) {
    MyActivityWidget()
} timeline: {
    MyActivityWidgetEntry(date: .now, snapshot: .placeholder)
}
#endif

private struct MyActivityNoReviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("최근 리뷰")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.textTertiary)

            Spacer(minLength: 0)

            Text("아직 작성한 리뷰가 없어요")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WidgetTheme.textSecondary)

            Text("게임을 플레이하고 첫 리뷰를 남겨보세요")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textTertiary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}
