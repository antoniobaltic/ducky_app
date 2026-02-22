import SwiftUI

struct LakeCard: View {
    let lake: BathingWater
    var distanceKm: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lake.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let municipality = lake.municipality {
                        Text(municipality)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if let dist = distanceKm {
                        Text(String(format: "%.0f km", dist))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                DuckBadge(state: lake.duckState, size: 44)
            }

            Spacer(minLength: 12)

            // Bottom row
            HStack(alignment: .center, spacing: 8) {
                TemperatureBadge(temperature: lake.waterTemperature, size: .medium)

                Spacer(minLength: 4)

                // Quality dot only (spec: "coloured dot")
                Circle()
                    .fill(lake.qualityColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: lake.qualityColor.opacity(0.6), radius: 4)
            }
        }
        .padding(16)
        .frame(width: 180, height: 140)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private var shortQualityLabel: String {
        guard let rating = lake.qualityRating?.lowercased() else { return "–" }
        if rating.contains("ausgezeichnet") { return "Ausgezeichnet" }
        if rating.contains("gut") { return "Gut" }
        if rating.contains("ausreichend") { return "Ausreichend" }
        if rating.contains("mangelhaft") { return "Mangelhaft" }
        return lake.qualityRating ?? "–"
    }
}

// MARK: - List-style card

struct LakeListRow: View {
    let lake: BathingWater
    var distanceKm: Double? = nil
    var isFavourite: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            DuckBadge(state: lake.duckState, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lake.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    if isFavourite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                }

                HStack(spacing: 8) {
                    if let municipality = lake.municipality {
                        Text(municipality)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let dist = distanceKm {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(String(format: "%.0f km", dist))
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(lake.qualityColor)
                        .frame(width: 7, height: 7)
                    Text(lake.qualityLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            TemperatureBadge(temperature: lake.waterTemperature, size: .medium)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            LakeCard(lake: .preview, distanceKm: 12.4)
            LakeCard(lake: .previewCold, distanceKm: 45.0)
            LakeCard(lake: .previewWarn)
        }
        .padding()
    }
    .background(
        LinearGradient(
            colors: [Color(red: 0.55, green: 0.80, blue: 1.00), Color(red: 0.35, green: 0.60, blue: 0.90)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    )
}
