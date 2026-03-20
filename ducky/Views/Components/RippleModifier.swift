import SwiftUI

// MARK: - Ripple Effect on Tap

struct RippleModifier: ViewModifier {
    @State private var ripple = false
    @State private var ripplePosition: CGPoint = .zero

    func body(content: Content) -> some View {
        content
            .overlay(
                ZStack {
                    if ripple {
                        Circle()
                            .stroke(AppTheme.skyBlue.opacity(0.3), lineWidth: 2)
                            .frame(width: ripple ? 80 : 0, height: ripple ? 80 : 0)
                            .position(ripplePosition)
                            .opacity(ripple ? 0 : 0.6)
                            .animation(.easeOut(duration: 0.6), value: ripple)
                    }
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        ripplePosition = value.location
                        ripple = true
                        Task {
                            try? await Task.sleep(for: .seconds(0.7))
                            ripple = false
                        }
                    }
            )
    }
}

extension View {
    func rippleOnTap() -> some View { modifier(RippleModifier()) }
}
