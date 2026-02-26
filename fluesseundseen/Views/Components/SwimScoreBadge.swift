import SwiftUI

// MARK: - Swim Score Badge

/// Reusable badge showing the composite swim score with level-colored background.
struct SwimScoreBadge: View {
    let score: SwimScore
    let size: BadgeSize

    enum BadgeSize {
        case small   // horizontal card overlay
        case medium  // list rows
        case large   // detail sections
        case hero    // detail hero centerpiece

        var diameter: CGFloat {
            switch self {
            case .small:  return 36
            case .medium: return 44
            case .large:  return 56
            case .hero:   return 90
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small:  return 13
            case .medium: return 16
            case .large:  return 20
            case .hero:   return 32
            }
        }

        var showLabel: Bool {
            switch self {
            case .small, .medium: return false
            case .large, .hero:   return true
            }
        }
    }

    var body: some View {
        if size == .hero {
            heroLayout
        } else {
            compactLayout
        }
    }

    // MARK: - Compact (small / medium / large)

    private var compactLayout: some View {
        ZStack {
            Circle()
                .fill(AppTheme.scoreColor(for: score.level))
                .frame(width: size.diameter, height: size.diameter)

            Text(scoreText)
                .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .overlay {
            if size == .large {
                VStack(spacing: 0) {
                    Spacer()
                    Text(score.level.label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.scoreColor(for: score.level))
                }
                .offset(y: size.diameter / 2 + 8)
            }
        }
    }

    // MARK: - Hero

    private var heroLayout: some View {
        VStack(spacing: 6) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(AppTheme.scoreColor(for: score.level).opacity(0.2))
                    .frame(width: size.diameter + 16, height: size.diameter + 16)

                Circle()
                    .fill(AppTheme.scoreGradient(for: score.level))
                    .frame(width: size.diameter, height: size.diameter)

                VStack(spacing: -2) {
                    Text(scoreText)
                        .font(.system(size: size.fontSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("/10")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text(score.level.label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.scoreColor(for: score.level))

            Text(score.scoreLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var scoreText: String {
        if score.total == 10.0 {
            return "10"
        }
        return String(format: "%.1f", score.total)
    }
}

// MARK: - Score Pin for Map

struct ScorePinView: View {
    let score: SwimScore

    var body: some View {
        ZStack {
            // Pin shape
            Circle()
                .fill(AppTheme.scoreColor(for: score.level))
                .frame(width: 32, height: 32)
                .shadow(color: AppTheme.scoreColor(for: score.level).opacity(0.4), radius: 4, y: 2)

            Text(String(format: "%.0f", score.total))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Preview

#Preview("Badge Sizes") {
    let sampleScore = SwimScore.compute(
        weather: LakeWeather(
            airTemperature: 26, uvIndex: 5,
            conditionSymbol: "sun.max.fill", conditionDescription: "Klar",
            feelsLike: 27, windSpeed: 8, precipitationProbability: 5, weatherCode: 0
        ),
        waterTemp: 22,
        qualityRating: "A",
        isClosed: false
    )
    let mediumScore = SwimScore.compute(
        weather: LakeWeather(
            airTemperature: 18, uvIndex: 3,
            conditionSymbol: "cloud.sun.fill", conditionDescription: "Teilweise bewölkt",
            feelsLike: 16, windSpeed: 15, precipitationProbability: 30, weatherCode: 2
        ),
        waterTemp: 16,
        qualityRating: "G",
        isClosed: false
    )

    VStack(spacing: 30) {
        HStack(spacing: 20) {
            SwimScoreBadge(score: sampleScore, size: .small)
            SwimScoreBadge(score: sampleScore, size: .medium)
            SwimScoreBadge(score: sampleScore, size: .large)
        }

        SwimScoreBadge(score: sampleScore, size: .hero)

        Divider()

        SwimScoreBadge(score: mediumScore, size: .hero)
    }
    .padding()
}
