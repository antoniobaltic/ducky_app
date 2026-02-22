import SwiftUI

struct ShareCardView: View {
    let lake: BathingWater
    let weather: LakeWeather?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                lake.duckState.backgroundGradient
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
                }
            }
        }
    }

    // MARK: - The shareable card

    var shareCard: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Text("flüsse & seen")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Image(systemName: "drop.fill")
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
            .background(lake.duckState.accentColor.opacity(0.6))

            // Main content
            VStack(spacing: 20) {
                // Duck + state
                VStack(spacing: 8) {
                    DuckView(state: lake.duckState, size: 110)

                    Text("\u{201E}\(lake.duckState.line)\u{201C}")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }

                Divider()

                // Lake info
                VStack(spacing: 8) {
                    Text(lake.name)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    if let municipality = lake.municipality {
                        Text(municipality)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Stats row
                HStack(spacing: 0) {
                    statCell(
                        value: lake.waterTemperature.map { String(format: "%.1f°C", $0) } ?? "–",
                        label: "Wassertemp.",
                        color: lake.temperatureColor
                    )

                    Divider().frame(height: 40)

                    if let airTemp = weather?.airTemperature {
                        statCell(
                            value: String(format: "%.0f°C", airTemp),
                            label: "Lufttemp.",
                            color: .orange
                        )
                        Divider().frame(height: 40)
                    }

                    statCell(
                        value: lake.qualityLabel,
                        label: "Qualität",
                        color: lake.qualityColor
                    )
                }
                .frame(maxWidth: .infinity)

                // Verdict sentence
                Text(verdictSentence)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                // Date footer
                Text("Stand: \(lake.measurementDate ?? "aktuell")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
            }
            .padding(24)
            .background(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 8)
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var verdictSentence: String {
        guard let temp = lake.waterTemperature else { return "Aktuelle Daten werden geladen." }
        let tempStr = String(format: "%.1f", temp)
        var parts: [String] = []
        parts.append("\(tempStr)°C Wassertemp.")
        if let air = weather?.airTemperature {
            parts.append(String(format: "%.0f°C Luft", air))
        }
        let stats = parts.joined(separator: " · ")

        switch lake.duckState {
        case .begeistert: return "\(stats) — Perfekte Bedingungen! 🦆💦"
        case .zufrieden:  return "\(stats) — Angenehm zum Baden. 🦆"
        case .zoegernd:   return "\(stats) — Nur für Mutige. 🦆🥶"
        case .frierend:   return "\(stats) — Lieber warten. ❄️🦆"
        case .warnend:    return "Wasserqualität aktuell mangelhaft. Bitte warten. ⚠️🦆"
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        ShareLink(
            item: shareText,
            subject: Text(lake.name),
            message: Text(verdictSentence)
        ) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Als Bild teilen")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(lake.duckState.accentColor, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
    }

    private var shareText: String {
        var lines = [
            "🦆 \(lake.name)",
            verdictSentence,
            "",
            "flüsse & seen — Badegewässer Österreich"
        ]
        return lines.joined(separator: "\n")
    }
}

#Preview {
    ShareCardView(lake: .preview, weather: nil)
}
