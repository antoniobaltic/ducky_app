import SwiftUI

struct LakeCard: View {
    let lake: BathingWater
    var distanceKm: Double? = nil
    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?
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

                    SwimScoreBadge(score: lake.swimScore(weather: weather), size: .small)
                }

                // Temperature row
                HStack(spacing: 5) {
                    if let weather, let airTemp = weather.airTemperature {
                        HStack(spacing: 2) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.coral)
                            Text(String(format: "%.0f°", airTemp))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }

                    if let waterTemp = lake.currentWaterTemperature {
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(AppTheme.skyBlue)
                            Text(String(format: "%.0f°", waterTemp))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }

                    Spacer(minLength: 2)

                    if let dist = distanceKm {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 8))
                            Text(String(format: "%.0f km", dist))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
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
        .task {
            weather = await weatherService.fetchWeather(for: lake)
        }
    }
}

// MARK: - List-style card

struct LakeListRow: View {
    let lake: BathingWater
    var distanceKm: Double? = nil
    var isFavourite: Bool = false
    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?

    var body: some View {
        HStack(spacing: 14) {
            SwimScoreBadge(score: lake.swimScore(weather: weather), size: .medium)

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

                ViewThatFits(in: .horizontal) {
                    metadataLine
                    metadataFallbackStack
                }
            }

            Spacer()

            // Temperatures column: Air first, Water second
            VStack(alignment: .trailing, spacing: 5) {
                if let weather, let airTemp = weather.airTemperature {
                    HStack(spacing: 3) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.coral)
                        Text(String(format: "%.0f°C", airTemp))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }

                if let waterTemp = lake.currentWaterTemperature {
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.skyBlue)
                        Text(String(format: "%.0f°C", waterTemp))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                } else {
                    Text("Wasser: –")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .task {
            weather = await weatherService.fetchWeather(for: lake)
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 4) {
            locationTextLine
            if distanceKm != nil {
                if hasLocationMeta {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                distanceChip
            }
        }
    }

    private var metadataFallbackStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            locationTextLine
            HStack(spacing: 0) {
                distanceChip
                Spacer(minLength: 0)
            }
        }
    }

    private var locationTextLine: some View {
        HStack(spacing: 4) {
            if let municipality = lake.municipality, !municipality.isEmpty {
                Text(municipality)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let state = lake.shortStateLabel, !state.isEmpty {
                if let municipality = lake.municipality, !municipality.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text(state)
                    .font(AppTheme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var hasLocationMeta: Bool {
        let hasMunicipality = !(lake.municipality?.isEmpty ?? true)
        let hasState = !(lake.shortStateLabel?.isEmpty ?? true)
        return hasMunicipality || hasState
    }

    @ViewBuilder
    private var distanceChip: some View {
        if let dist = distanceKm {
            HStack(spacing: 2) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                Text(String(format: "%.0f km", dist))
                    .font(AppTheme.smallCaption)
            }
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: true, vertical: false)
        }
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
    .environment(WeatherService.shared)
}
