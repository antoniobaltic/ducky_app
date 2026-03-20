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
    static let airTempGreen = Color(red: 0.16, green: 0.46, blue: 0.24)
    static let lavender = Color(red: 0.56, green: 0.38, blue: 1.0)
    static let warmPink = Color(red: 1.0, green: 0.34, blue: 0.53)

    // MARK: - Neutral Colors (Adaptive for light / dark mode)

    static let textPrimary = adaptive(
        light: (0.11, 0.11, 0.12),
        dark: (0.93, 0.93, 0.95)
    )
    static let textSecondary = adaptive(
        light: (0.38, 0.40, 0.48),
        dark: (0.62, 0.62, 0.65)
    )
    static let divider = adaptive(
        light: (0.88, 0.90, 0.95),
        dark: (0.22, 0.22, 0.24)
    )
    static let pageBackground = adaptive(
        light: (0.95, 0.96, 0.98),
        dark: (0.07, 0.07, 0.09)
    )
    static let cardBackground = adaptive(
        light: (0.99, 0.98, 1.0),
        dark: (0.14, 0.14, 0.16)
    )
    static let searchBarBackground = adaptive(
        light: (0.93, 0.95, 0.98),
        dark: (0.18, 0.18, 0.20)
    )
    static let cardStroke = adaptive(
        light: (0.84, 0.88, 0.96),
        dark: (0.26, 0.27, 0.30)
    )
    static let glowOverlay = adaptive(
        light: (0.94, 0.96, 1.0),
        dark: (0.38, 0.42, 0.52)
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

    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                pageBackground,
                oceanBlue.opacity(0.10),
                teal.opacity(0.07)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let homeGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.94, blue: 0.90),
            Color(red: 0.88, green: 0.94, blue: 1.0),
            Color(red: 0.90, green: 0.98, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let favouritesGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.92, blue: 0.90),
            Color(red: 0.93, green: 0.90, blue: 1.0),
            Color(red: 0.88, green: 0.94, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let settingsGradient = LinearGradient(
        colors: [
            Color(red: 0.91, green: 0.98, blue: 0.95),
            Color(red: 0.92, green: 0.95, blue: 1.0),
            Color(red: 0.95, green: 0.92, blue: 1.0)
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

    // MARK: - Score Colors

    static let scorePerfekt = adaptive(
        light: (0.13, 0.75, 0.39),   // vibrant green
        dark: (0.20, 0.82, 0.48)
    )
    static let scoreGut = adaptive(
        light: (0.40, 0.78, 0.35),   // lime-green
        dark: (0.48, 0.85, 0.42)
    )
    static let scoreMittel = adaptive(
        light: (0.95, 0.75, 0.10),   // amber
        dark: (1.0, 0.82, 0.20)
    )
    static let scoreSchlecht = adaptive(
        light: (0.95, 0.50, 0.15),   // orange
        dark: (1.0, 0.58, 0.22)
    )
    static let scoreWarnung = adaptive(
        light: (0.92, 0.28, 0.20),   // red
        dark: (1.0, 0.38, 0.30)
    )

    static func scoreColor(for level: SwimScore.Level) -> Color {
        switch level {
        case .perfekt:  return scorePerfekt
        case .gut:      return scoreGut
        case .mittel:   return scoreMittel
        case .schlecht: return scoreSchlecht
        case .warnung:  return scoreWarnung
        }
    }

    static func scoreGradient(for level: SwimScore.Level) -> LinearGradient {
        let base = scoreColor(for: level)
        return LinearGradient(
            colors: [base.opacity(0.8), base],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func detailPageGradient(for level: SwimScore.Level, isDark: Bool) -> LinearGradient {
        let base = scoreColor(for: level)
        return LinearGradient(
            colors: [
                base.opacity(isDark ? 0.44 : 0.32),
                base.opacity(isDark ? 0.28 : 0.22),
                pageBackground.opacity(isDark ? 0.96 : 0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func detailHeroGradient(for level: SwimScore.Level, isDark: Bool) -> LinearGradient {
        let base = scoreColor(for: level)
        return LinearGradient(
            colors: [
                base.opacity(isDark ? 0.56 : 0.40),
                base.opacity(isDark ? 0.42 : 0.30),
                base.opacity(isDark ? 0.18 : 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

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
    static let entranceSpring = Animation.spring(response: 0.52, dampingFraction: 0.84, blendDuration: 0.05)
    static let smoothEase = Animation.easeInOut(duration: 0.9)
}
