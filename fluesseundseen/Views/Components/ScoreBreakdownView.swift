import SwiftUI

// MARK: - Score Breakdown View

/// Card showing the three sub-score components as horizontal progress bars.
struct ScoreBreakdownView: View {
    let score: SwimScore
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with toggle
            Button {
                withAnimation(AppTheme.quickSpring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.scoreColor(for: score.level))

                    Text("Score-Details")
                        .font(AppTheme.cardTitle)
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    scoreRow(
                        icon: "sun.max.fill",
                        label: "Wetter",
                        value: score.weatherScore,
                        color: barColor(for: score.weatherScore)
                    )

                    if let waterScore = score.waterTempScore {
                        scoreRow(
                            icon: "thermometer.medium",
                            label: "Wassertemperatur",
                            value: waterScore,
                            color: barColor(for: waterScore)
                        )
                    } else {
                        unavailableRow(
                            icon: "thermometer.medium",
                            label: "Wassertemperatur",
                            message: "Verfügbar Juni – August"
                        )
                    }

                    scoreRow(
                        icon: "drop.fill",
                        label: "Wasserqualität",
                        value: score.qualityScore,
                        color: barColor(for: score.qualityScore)
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .appCard()
    }

    // MARK: - Score Row

    private func scoreRow(icon: String, label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 18)

                Text(label)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Text(String(format: "%.1f", value))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * (value / 10.0)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Unavailable Row

    private func unavailableRow(icon: String, label: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 18)

                Text(label)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
            }

            Capsule()
                .fill(AppTheme.textSecondary.opacity(0.1))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    // Striped pattern to indicate "unavailable"
                    HStack(spacing: 4) {
                        ForEach(0..<8, id: \.self) { _ in
                            Capsule()
                                .fill(AppTheme.textSecondary.opacity(0.15))
                                .frame(width: 12, height: 6)
                        }
                    }
                }
                .clipShape(Capsule())
        }
    }

    private func barColor(for value: Double) -> Color {
        switch value {
        case 8...10: return AppTheme.scorePerfekt
        case 6..<8:  return AppTheme.scoreGut
        case 4..<6:  return AppTheme.scoreMittel
        case 2..<4:  return AppTheme.scoreSchlecht
        default:     return AppTheme.scoreWarnung
        }
    }
}

// MARK: - Preview

#Preview("Score Breakdown") {
    let fullScore = SwimScore.compute(
        weather: LakeWeather(
            airTemperature: 26, uvIndex: 5,
            conditionSymbol: "sun.max.fill", conditionDescription: "Klar",
            feelsLike: 27, windSpeed: 8, precipitationProbability: 5, weatherCode: 0
        ),
        waterTemp: 22,
        qualityRating: "A",
        isClosed: false
    )
    let noWaterScore = SwimScore.compute(
        weather: LakeWeather(
            airTemperature: 18, uvIndex: 3,
            conditionSymbol: "cloud.sun.fill", conditionDescription: "Teilweise bewölkt",
            feelsLike: 16, windSpeed: 15, precipitationProbability: 30, weatherCode: 2
        ),
        waterTemp: nil,
        qualityRating: "G",
        isClosed: false
    )

    ScrollView {
        VStack(spacing: 20) {
            ScoreBreakdownView(score: fullScore)
            ScoreBreakdownView(score: noWaterScore)
        }
        .padding()
    }
}
