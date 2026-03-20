import SwiftUI

// MARK: - Card Style Modifier

struct AppCardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(AppTheme.cardStroke.opacity(0.45), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.glowOverlay.opacity(0.18),
                                Color(red: 0.80, green: 0.85, blue: 1.0).opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            )
            .shadow(color: Color(red: 0.55, green: 0.60, blue: 0.85).opacity(0.14), radius: 16, x: 0, y: 6)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardStyle(padding: padding))
    }
}
