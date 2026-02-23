import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - App Design System

enum AppTheme {
    // MARK: - Adaptive Color Helper

    private static func adaptive(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        return Color(red: light.0, green: light.1, blue: light.2)
        #endif
    }

    // MARK: - Primary Colors (vibrant & playful — same in both modes)

    static let oceanBlue = Color(red: 0.10, green: 0.45, blue: 0.91)
    static let skyBlue = Color(red: 0.30, green: 0.65, blue: 1.0)
    static let lightBlue = Color(red: 0.56, green: 0.80, blue: 1.0)
    static let teal = Color(red: 0.0, green: 0.74, blue: 0.65)
    static let coral = Color(red: 1.0, green: 0.38, blue: 0.24)
    static let sunshine = Color(red: 1.0, green: 0.80, blue: 0.0)
    static let freshGreen = Color(red: 0.18, green: 0.80, blue: 0.44)
    static let lavender = Color(red: 0.56, green: 0.38, blue: 1.0)
    static let warmPink = Color(red: 1.0, green: 0.34, blue: 0.53)

    // MARK: - Neutral Colors (Adaptive for light / dark mode)

    static let textPrimary = adaptive(
        light: (0.11, 0.11, 0.12),
        dark: (0.93, 0.93, 0.95)
    )
    static let textSecondary = adaptive(
        light: (0.44, 0.44, 0.47),
        dark: (0.62, 0.62, 0.65)
    )
    static let divider = adaptive(
        light: (0.90, 0.91, 0.92),
        dark: (0.22, 0.22, 0.24)
    )
    static let pageBackground = adaptive(
        light: (0.965, 0.97, 0.98),
        dark: (0.07, 0.07, 0.09)
    )
    static let cardBackground = adaptive(
        light: (1.0, 1.0, 1.0),
        dark: (0.14, 0.14, 0.16)
    )
    static let searchBarBackground = adaptive(
        light: (0.94, 0.94, 0.96),
        dark: (0.18, 0.18, 0.20)
    )

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

    // MARK: - Seasonal Colors

    static let winterBlue = Color(red: 0.72, green: 0.84, blue: 0.96)
    static let springGreen = Color(red: 0.55, green: 0.82, blue: 0.68)
    static let autumnOrange = Color(red: 0.90, green: 0.68, blue: 0.42)
    static let autumnRed = Color(red: 0.82, green: 0.42, blue: 0.28)
    static let autumnGold = Color(red: 0.88, green: 0.72, blue: 0.32)

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

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatisch"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
