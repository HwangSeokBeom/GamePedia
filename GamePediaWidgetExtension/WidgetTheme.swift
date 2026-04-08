import SwiftUI
import WidgetKit

enum WidgetTheme {
    static let background = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let surface = Color(red: 0.12, green: 0.15, blue: 0.20)
    static let surfaceSecondary = Color(red: 0.16, green: 0.19, blue: 0.25)
    static let accent = Color(red: 1.00, green: 0.42, blue: 0.22)
    static let accentSoft = Color(red: 1.00, green: 0.72, blue: 0.56)
    static let border = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textTertiary = Color.white.opacity(0.54)
    static let shadow = Color.black.opacity(0.22)
}

enum WidgetDeepLinkURL {
    static let trending = URL(string: "gamepedia://trending")!
    static let login = URL(string: "gamepedia://login")!
}

struct WidgetArtworkView: View {
    let url: URL?
    let cornerRadius: CGFloat

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

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(WidgetTheme.textTertiary)
                }
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

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(WidgetTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(WidgetTheme.accent)
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
