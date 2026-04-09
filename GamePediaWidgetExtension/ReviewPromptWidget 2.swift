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
        .supportedFamilies([.systemMedium])
    }
}

private struct ReviewPromptWidgetView: View {
    let entry: ReviewPromptWidgetEntry

    var body: some View {
        Group {
            switch entry.snapshot.state {
            case .ready:
                ReviewPromptReadyView(snapshot: entry.snapshot)
            case .empty:
                ReviewPromptMessageView(
                    snapshot: entry.snapshot,
                    accentTitle: "Review",
                    buttonURL: nil
                )
            case .loggedOut:
                ReviewPromptMessageView(
                    snapshot: entry.snapshot,
                    accentTitle: "Login",
                    buttonURL: entry.snapshot.targetURL ?? WidgetDeepLinkURL.login
                )
            }
        }
        .gamePediaWidgetBackground()
        .widgetURL(entry.snapshot.targetURL ?? WidgetDeepLinkURL.trending)
    }
}

private struct ReviewPromptReadyView: View {
    let snapshot: ReviewPromptWidgetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            WidgetArtworkView(url: snapshot.item?.coverImageURL, cornerRadius: 20)
                .frame(width: 104, height: 138)

            VStack(alignment: .leading, spacing: 10) {
                WidgetSectionLabel(title: snapshot.headerTitle)

                Text(snapshot.headlineText)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(2)

                Text(snapshot.bodyText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(3)

                Spacer(minLength: 0)

                if let ctaTitle = snapshot.ctaTitle {
                    Link(destination: snapshot.targetURL ?? WidgetDeepLinkURL.trending) {
                        WidgetCTAButton(title: ctaTitle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
    }
}

private struct ReviewPromptMessageView: View {
    let snapshot: ReviewPromptWidgetSnapshot
    let accentTitle: String
    let buttonURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                WidgetSectionLabel(title: accentTitle)
                Spacer()
            }

            Text(snapshot.headlineText)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(WidgetTheme.textPrimary)
                .lineLimit(2)

            Text(snapshot.bodyText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(3)

            Spacer(minLength: 0)

            if let ctaTitle = snapshot.ctaTitle,
               let buttonURL {
                Link(destination: buttonURL) {
                    WidgetCTAButton(title: ctaTitle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WidgetTheme.surface)
        )
        .padding(10)
    }
}
