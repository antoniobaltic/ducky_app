import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.4), .clear],
                    startPoint: .init(x: phase, y: 0.5),
                    endPoint: .init(x: phase + 0.5, y: 0.5)
                )
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: phase)
                .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .onAppear { phase = 1.5 }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
