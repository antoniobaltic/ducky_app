import SwiftUI

// MARK: - Score Breakdown View

/// Card showing score composition: weather/water base plus quality penalty.
struct ScoreBreakdownView: View {
    let score: SwimScore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.scoreColor(for: score.level))

                Text("Score-Details")
                    .font(AppTheme.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()
            }

            VStack(spacing: 10) {
                if let forcedReason = score.forcedReason {
                    forcedReasonRow(forcedReason)
                }

                scoreRow(
                    icon: "wind",
                    label: score.hasWaterTemp ? "Wetter & Lufttemp. (70%)" : "Wetter & Lufttemp. (100%)",
                    value: score.weatherScore,
                    color: AppTheme.airTempGreen
                )

                if let waterScore = score.waterTempScore {
                    scoreRow(
                        icon: "drop.fill",
                        label: "Wassertemp. (30%)",
                        value: waterScore,
                        color: AppTheme.oceanBlue
                    )
                } else {
                    unavailableRow(
                        icon: "drop.fill",
                        label: "Wassertemp. (30%)",
                        message: "Messungen: Juni bis August"
                    )
                }

                qualityPenaltyRow
                if score.hasBacteriaData {
                    bacteriaPenaltyRow
                } else {
                    unavailableRow(
                        icon: "allergens",
                        label: "Bakterienabzug",
                        message: "Nicht in Berechnung (keine Messwerte)"
                    )
                }

                formulaRow
            }
        }
        .appCard()
    }

    // MARK: - Score Row

    private func scoreRow(
        icon: String,
        label: String,
        value: Double,
        color: Color
    ) -> some View {
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
                    .foregroundStyle(AppTheme.textPrimary)
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

    private var qualityPenaltyRow: some View {
        let deduction = abs(score.qualityPenalty)
        let magnitude = min(1.0, deduction / 2.0)
        let color: Color = deduction > 0 ? AppTheme.coral : AppTheme.freshGreen
        let valueText = String(format: "%.1f", deduction)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 18)

                Text("Qualitätsabzug (\(score.qualityBand.label))")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Text(valueText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * magnitude), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var bacteriaPenaltyRow: some View {
        let deduction = abs(score.bacteriaPenalty)
        let magnitude = min(1.0, deduction / 2.8)
        let color: Color = deduction > 0 ? AppTheme.coral : AppTheme.freshGreen
        let valueText = String(format: "%.1f", deduction)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "allergens")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 18)

                Text("Bakterienabzug (E.Coli/Enterokokken)")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Text(valueText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * magnitude), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var formulaRow: some View {
        let qualityDeduction = abs(score.qualityPenalty)
        let bacteriaDeduction = score.hasBacteriaData ? abs(score.bacteriaPenalty) : 0.0
        let totalDeduction = qualityDeduction + bacteriaDeduction
        let unclamped = score.baseScore - totalDeduction
        let equation: String = {
            if score.hasBacteriaData {
                return String(
                    format: "%.1f − %.1f − %.1f = %.1f",
                    score.baseScore,
                    qualityDeduction,
                    bacteriaDeduction,
                    score.total
                )
            } else {
                return String(
                    format: "%.1f − %.1f = %.1f",
                    score.baseScore,
                    qualityDeduction,
                    score.total
                )
            }
        }()
        let wasClamped = abs(unclamped - score.total) > 0.05

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "function")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 18)

                Text("Formel")
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Text(equation)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if wasClamped {
                Text("Ergebnis wird auf mindestens 0.0 begrenzt.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
            }
        }
    }

    private func forcedReasonRow(_ reason: SwimScore.ForcedReason) -> some View {
        let message: String
        switch reason {
        case .closed:
            message = "Gewässer ist gesperrt: Score wurde auf Warnung gesetzt."
        case .poorQuality:
            message = "Wasserqualität ist mangelhaft: Score wurde auf Warnung gesetzt."
        }

        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.coral)
            Text(message)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
