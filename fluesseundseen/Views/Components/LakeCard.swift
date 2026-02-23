import SwiftUI

struct LakeCard: View {
    let lake: BathingWater
    var distanceKm: Double? = nil
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top colored strip
            HStack(spacing: 6) {
                Circle()
                    .fill(lake.qualityColor)
                    .frame(width: 8, height: 8)
                Text(lake.qualityLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if lake.isClosed {
                    Text("Gesperrt")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.coral.opacity(0.8), in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(lake.qualityColor.opacity(0.85))

            // Content
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lake.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let municipality = lake.municipality {
                            Text(municipality)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    Spacer(minLength: 4)

                    DuckBadge(state: lake.duckState, size: 38)
                }

                // Bottom info
                HStack(spacing: 8) {
                    TemperatureBadge(temperature: lake.waterTemperature, size: .small, isOutdated: lake.isTemperatureOutdated)

                    Spacer()

                    if let dist = distanceKm {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(String(format: "%.0f km", dist))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 200)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
        .scaleEffect(appear ? 1 : 0.92)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(AppTheme.springAnimation.delay(Double.random(in: 0...0.2))) {
                appear = true
            }
        }
    }
}

// MARK: - List-style card

struct LakeListRow: View {
    let lake: BathingWater
    var distanceKm: Double? = nil
    var isFavourite: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            DuckBadge(state: lake.duckState, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(lake.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    if isFavourite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.warmPink)
                    }
                    if lake.isClosed {
                        Text("Gesperrt")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppTheme.coral, in: Capsule())
                    }
                }

                HStack(spacing: 6) {
                    if let municipality = lake.municipality {
                        Text(municipality)
                            .font(AppTheme.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if let state = lake.state {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(state)
                            .font(AppTheme.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if let dist = distanceKm {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(String(format: "%.0f km", dist))
                                .font(AppTheme.smallCaption)
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            TemperatureBadge(temperature: lake.waterTemperature, size: .small, isOutdated: lake.isTemperatureOutdated)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                LakeCard(lake: .preview, distanceKm: 12.4)
                LakeCard(lake: .previewCold, distanceKm: 45.0)
                LakeCard(lake: .previewWarn)
                LakeCard(lake: .previewNoTemp)
            }
            .padding()
        }

        List {
            LakeListRow(lake: .preview, distanceKm: 12, isFavourite: true)
            LakeListRow(lake: .previewCold, distanceKm: 45)
            LakeListRow(lake: .previewNoTemp)
        }
    }
    .background(AppTheme.pageBackground)
}
