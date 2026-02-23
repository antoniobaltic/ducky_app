import SwiftUI

// MARK: - App Design System

enum AppTheme {
    // MARK: - Primary Colors (Google-inspired, vibrant & playful)

    static let oceanBlue = Color(red: 0.10, green: 0.45, blue: 0.91)
    static let skyBlue = Color(red: 0.30, green: 0.65, blue: 1.0)
    static let lightBlue = Color(red: 0.56, green: 0.80, blue: 1.0)
    static let teal = Color(red: 0.0, green: 0.74, blue: 0.65)
    static let coral = Color(red: 1.0, green: 0.38, blue: 0.24)
    static let sunshine = Color(red: 1.0, green: 0.80, blue: 0.0)
    static let freshGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let lavender = Color(red: 0.56, green: 0.38, blue: 1.0)
    static let warmPink = Color(red: 1.0, green: 0.34, blue: 0.53)

    // MARK: - Neutral Colors

    static let textPrimary = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let textSecondary = Color(red: 0.44, green: 0.44, blue: 0.47)
    static let divider = Color(red: 0.90, green: 0.91, blue: 0.92)
    static let pageBackground = Color(red: 0.965, green: 0.97, blue: 0.98)
    static let cardBackground = Color.white

    // MARK: - Gradients

    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.25, green: 0.58, blue: 1.0),
            Color(red: 0.10, green: 0.40, blue: 0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let warmGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.62, blue: 0.22),
            Color(red: 1.0, green: 0.38, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let tealGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.82, blue: 0.72),
            Color(red: 0.0, green: 0.65, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Typography

    static let heroTitle = Font.system(size: 34, weight: .heavy, design: .rounded)
    static let sectionTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    static let bodyText = Font.system(size: 15, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 13, weight: .medium, design: .rounded)
    static let smallCaption = Font.system(size: 11, weight: .semibold, design: .rounded)

    // MARK: - Corner Radius

    static let cardRadius: CGFloat = 20
    static let badgeRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 16

    // MARK: - Animations

    static let springAnimation = Animation.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)
    static let gentleSpring = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
    static let quickSpring = Animation.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)
}

// MARK: - Card Style Modifier

struct AppCardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardStyle(padding: padding))
    }
}

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
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .onAppear { phase = 1.5 }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Bubble Animation Background

struct BubbleBackground: View {
    let color: Color
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(color.opacity(Double.random(in: 0.03...0.08)))
                    .frame(width: CGFloat.random(in: 40...120))
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: animate ? CGFloat.random(in: -200...200) : CGFloat.random(in: -200...200)
                    )
                    .blur(radius: CGFloat.random(in: 10...30))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
