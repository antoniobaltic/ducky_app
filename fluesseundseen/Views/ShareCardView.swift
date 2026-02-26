import SwiftUI

struct ShareCardView: View {
    let lake: BathingWater
    let weather: LakeWeather?
    @Environment(\.dismiss) private var dismiss

    private var score: SwimScore {
        lake.swimScore(weather: weather)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    shareCard
                        .padding(.horizontal, 24)
                    Spacer()
                    shareButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                }
            }
            .navigationTitle("Teilen")
            .iOSNavigationBarInline()
            .toolbar {
                ToolbarItem(placement: .iOSTopBarLeading) {
                    Button("Fertig") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
        }
    }

    // MARK: - Share Card

    var shareCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                    Text("Flüsse & Seen")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text(score.level.emoji)
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppTheme.scoreColor(for: score.level))

            // Content
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    SwimScoreBadge(score: score, size: .hero)

                    Text("\u{201E}\(duckQuote)\u{201C}")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .italic()
                        .multilineTextAlignment(.center)
                }

                Divider()

                VStack(spacing: 6) {
                    Text(lake.name)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    if let municipality = lake.municipality {
                        Text(municipality + (lake.state.map { ", \($0)" } ?? ""))
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                // Stats
                HStack(spacing: 0) {
                    statCell(
                        value: String(format: "%.1f/10", score.total),
                        label: score.scoreLabel,
                        color: AppTheme.scoreColor(for: score.level)
                    )
                    Divider().frame(height: 36)
                    if let airTemp = weather?.airTemperature {
                        statCell(
                            value: String(format: "%.0f°C", airTemp),
                            label: "Lufttemp.",
                            color: AppTheme.coral
                        )
                        Divider().frame(height: 36)
                    }
                    if let waterTemp = lake.currentWaterTemperature {
                        statCell(
                            value: String(format: "%.1f°C", waterTemp),
                            label: "Wasser",
                            color: AppTheme.oceanBlue
                        )
                        Divider().frame(height: 36)
                    }
                    statCell(
                        value: lake.qualityLabel,
                        label: "Qualität",
                        color: lake.qualityColor
                    )
                }

                Text(verdictSentence)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                if lake.isTemperatureOutdated {
                    Text("Letzte Messung: \(lake.measurementDate ?? "unbekannt") · Daten: AGES")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                } else if let date = lake.measurementDate {
                    Text("Stand: \(date)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(24)
            .background(AppTheme.cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var duckQuote: String {
        if lake.isTemperatureOutdated && lake.waterTemperature != nil {
            switch Season.current {
            case .winter: return "Winterpause — bis zum Sommer!"
            case .spring: return "Bald geht's wieder los!"
            case .autumn: return "Saison vorbei — bis nächstes Jahr!"
            case .summer: return lake.duckState.line
            }
        }
        return lake.duckState.line
    }

    private var verdictSentence: String {
        let scoreStr = String(format: "%.1f/10", score.total)
        switch score.level {
        case .perfekt:  return "\(score.scoreLabel) \(scoreStr) — Perfekte Bedingungen!"
        case .gut:      return "\(score.scoreLabel) \(scoreStr) — Gute Bedingungen zum Baden."
        case .mittel:   return "\(score.scoreLabel) \(scoreStr) — Durchwachsen."
        case .schlecht: return "\(score.scoreLabel) \(scoreStr) — Eher nicht ideal."
        case .warnung:  return "\(score.scoreLabel) \(scoreStr) — Lieber nicht ins Wasser."
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        ShareLink(
            item: shareText,
            subject: Text(lake.name),
            message: Text(verdictSentence)
        ) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Teilen")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.scoreColor(for: score.level), in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
            .shadow(color: AppTheme.scoreColor(for: score.level).opacity(0.3), radius: 10, y: 5)
        }
    }

    private var shareText: String {
        [
            "🦆 \(lake.name)",
            verdictSentence,
            "",
            "Flüsse & Seen — Badegewässer Österreich"
        ].joined(separator: "\n")
    }
}

#Preview {
    ShareCardView(lake: .preview, weather: nil)
}
