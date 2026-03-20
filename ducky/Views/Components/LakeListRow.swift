import SwiftUI

// MARK: - List-style card

struct LakeListRow: View {
    let lake: BathingWater
    var distanceKm: Double? = nil
    var isFavourite: Bool = false
    var isVisited: Bool = false
    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?

    var body: some View {
        HStack(spacing: 14) {
            SwimScoreBadge(score: lake.swimScore(weather: weather), size: .medium, isVisited: isVisited)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(lake.displayName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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

                metadataLine

                weatherRow
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .task {
            weather = await weatherService.fetchWeather(for: lake)
        }
    }

    private var weatherRow: some View {
        HStack(spacing: 6) {
            weatherConditionPill
            temperatureChip(
                icon: "wind",
                iconColor: AppTheme.airTempGreen,
                value: weather?.airTemperature.map { "\($0.formatted(.number.precision(.fractionLength(0))))°C" } ?? "-"
            )
            temperatureChip(
                icon: "drop.fill",
                iconColor: AppTheme.oceanBlue,
                value: lake.currentWaterTemperature.map { "\($0.formatted(.number.precision(.fractionLength(0))))°C" } ?? "-"
            )
            Spacer(minLength: 0)
        }
    }

    private var weatherConditionPill: some View {
        Group {
            if let weather {
                quickConditionChip(
                    icon: weather.conditionSymbol,
                    value: weather.conditionDescription,
                    color: weatherConditionChipStyle(for: weather)
                )
            } else {
                quickConditionChip(
                    icon: "cloud.fill",
                    value: "Unbekannt",
                    color: AppTheme.textSecondary
                )
            }
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

    private func temperatureChip(icon: String, iconColor: Color, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(iconColor.opacity(0.10), in: Capsule())
    }

    private func weatherConditionChipStyle(for weather: LakeWeather) -> Color {
        guard let code = weather.weatherCode else {
            return AppTheme.textSecondary
        }

        switch code {
        case 0, 1:
            return AppTheme.sunshine
        case 2, 3:
            return AppTheme.textSecondary
        case 45, 48:
            return AppTheme.textSecondary
        case 51, 53, 55:
            return AppTheme.skyBlue
        case 56, 57, 66, 67:
            return AppTheme.lavender
        case 61, 63, 65, 80, 81, 82:
            return AppTheme.oceanBlue
        case 71, 73, 75, 77, 85, 86:
            return AppTheme.lightBlue
        case 95, 96, 99:
            return AppTheme.coral
        default:
            return AppTheme.textSecondary
        }
    }

    private func quickConditionChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
    }

    @ViewBuilder
    private var distanceChip: some View {
        if let dist = distanceKm {
            HStack(spacing: 2) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                Text("\(dist.formatted(.number.precision(.fractionLength(0)))) km")
                    .font(AppTheme.smallCaption)
            }
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

#Preview("Lake List Row") {
    List {
        LakeListRow(lake: .preview, distanceKm: 12, isFavourite: true)
        LakeListRow(lake: .previewCold, distanceKm: 45)
        LakeListRow(lake: .previewNoTemp)
    }
    .background(AppTheme.pageBackground)
    .environment(WeatherService.shared)
}
