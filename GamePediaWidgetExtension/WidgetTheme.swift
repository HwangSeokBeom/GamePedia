import SwiftUI
import UIKit
import WidgetKit

enum WidgetTheme {
    static let background = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let surface = Color(red: 0.12, green: 0.15, blue: 0.20)
    static let surfaceSecondary = Color(red: 0.16, green: 0.19, blue: 0.25)
    static let accent = Color(red: 1.00, green: 0.42, blue: 0.22)
    static let accentSoft = Color(red: 1.00, green: 0.72, blue: 0.56)
    static let indigo = Color(red: 0.39, green: 0.40, blue: 0.95)
    static let emerald = Color(red: 0.12, green: 0.84, blue: 0.56)
    static let coral = Color(red: 0.98, green: 0.39, blue: 0.33)
    static let border = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textTertiary = Color.white.opacity(0.54)
    static let shadow = Color.black.opacity(0.22)
}

enum WidgetDeepLinkURL {
    static let trending = URL(string: "gamepedia://trending")!
    static let profile = URL(string: "gamepedia://profile")!
    static let login = URL(string: "gamepedia://login")!
}

struct WidgetArtworkView: View {
    let imageKey: String?
    let cornerRadius: CGFloat

    private var uiImage: UIImage? {
        guard let fileURL = GameWidgetSnapshotStore.shared.imageFileURL(forKey: imageKey) else {
            return nil
        }

        return UIImage(contentsOfFile: fileURL.path)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WidgetTheme.surfaceSecondary,
                            WidgetTheme.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textTertiary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WidgetTheme.border, lineWidth: 1)
        )
    }
}

struct WidgetSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(WidgetTheme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

struct WidgetCTAButton: View {
    let title: String
    var fill: Color = WidgetTheme.accent
    var compact: Bool = false

    var body: some View {
        Text(title)
            .font(.system(size: compact ? 11 : 13, weight: .semibold))
            .foregroundStyle(WidgetTheme.textPrimary)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 7 : 8)
            .background(
                RoundedRectangle(cornerRadius: compact ? 8 : 999, style: .continuous)
                    .fill(fill)
            )
    }
}

struct WidgetBrandBadge: View {
    var body: some View {
        Text("G")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(WidgetTheme.textPrimary)
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(WidgetTheme.indigo)
            )
    }
}

struct WidgetHeader: View {
    let title: String
    let systemImageName: String

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: systemImageName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WidgetTheme.indigo)

                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WidgetTheme.textPrimary)
            }

            Spacer(minLength: 0)

            WidgetBrandBadge()
        }
    }
}

struct WidgetMessageCard: View {
    let headerTitle: String
    let systemImageName: String
    let headlineText: String
    let bodyText: String
    let targetURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(title: headerTitle, systemImageName: systemImageName)

            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 6) {
                Image(systemName: systemImageName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textTertiary)

                Text(headlineText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Text(bodyText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .widgetURL(targetURL)
    }
}

struct LoggedOutWidgetCard: View {
    let content: WidgetLoggedOutContent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    WidgetBrandBadge()
                    Text(content.brandTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WidgetTheme.textPrimary)
                }

                Spacer(minLength: 0)

                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WidgetTheme.indigo)
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Text(content.headlineText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WidgetTheme.textSecondary)

                Text(content.bodyText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(WidgetTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            if let targetURL = content.targetURL {
                HStack {
                    Spacer(minLength: 0)

                    Link(destination: targetURL) {
                        WidgetCTAButton(
                            title: content.ctaTitle,
                            fill: WidgetTheme.indigo,
                            compact: false
                        )
                        .frame(width: 120)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct WidgetStatCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(WidgetTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WidgetTheme.surface)
        )
    }
}

extension View {
    func gamePediaWidgetBackground() -> some View {
        containerBackground(for: .widget) {
            WidgetTheme.background
        }
    }
}
