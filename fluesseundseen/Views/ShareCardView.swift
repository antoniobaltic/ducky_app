import SwiftUI

struct ShareCardView: View {
    let lake: BathingWater
    let weather: LakeWeather?
    @Environment(\.dismiss) private var dismiss

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
                Text(lake.duckState.emoji)
                    .font(.system(size: 16))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(lake.duckState.accentColor)

            // Content
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    DuckView(state: lake.duckState, size: 100)

                    Text("\u{201E}\(lake.duckState.line)\u{201C}")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
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
                        value: lake.temperatureDisplay,
                        label: "Wassertemp.",
                        color: lake.hasTemperature ? lake.temperatureColor : .gray
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

    private var verdictSentence: String {
        // Outdated: don't present stale data as current conditions
        if lake.isTemperatureOutdated {
            if let temp = lake.waterTemperature {
                return "Letzte Messung: \(String(format: "%.1f", temp))°C. Neue Daten ab Juni."
            }
            return "Daten vom letzten Sommer. Neue Messungen ab Juni."
        }

        guard let temp = lake.waterTemperature else { return "Temperaturdaten momentan nicht verfügbar." }
        let tempStr = String(format: "%.1f", temp)
        var parts: [String] = ["\(tempStr)°C Wasser"]
        if let air = weather?.airTemperature {
            parts.append(String(format: "%.0f°C Luft", air))
        }
        let stats = parts.joined(separator: " · ")

        switch lake.duckState {
        case .begeistert: return "\(stats) — Perfekte Bedingungen!"
        case .zufrieden:  return "\(stats) — Angenehm zum Baden."
        case .zoegernd:   return "\(stats) — Nur für Mutige."
        case .frierend:   return "\(stats) — Lieber warten."
        case .warnend:    return "Wasserqualität aktuell mangelhaft."
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
            .background(lake.duckState.accentColor, in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
            .shadow(color: lake.duckState.accentColor.opacity(0.3), radius: 10, y: 5)
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
