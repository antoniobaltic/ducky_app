import SwiftUI

struct TemperatureBadge: View {
    let temperature: Double?
    var size: BadgeSize = .medium
    var isOutdated: Bool = false
    var measurementDate: String? = nil

    enum BadgeSize {
        case small, medium, large, hero

        var font: Font {
            switch self {
            case .small:  return .system(size: 14, weight: .bold, design: .rounded)
            case .medium: return .system(size: 20, weight: .bold, design: .rounded)
            case .large:  return .system(size: 28, weight: .heavy, design: .rounded)
            case .hero:   return .system(size: 52, weight: .heavy, design: .rounded)
            }
        }

        var unitFont: Font {
            switch self {
            case .small:  return .system(size: 10, weight: .semibold, design: .rounded)
            case .medium: return .system(size: 12, weight: .semibold, design: .rounded)
            case .large:  return .system(size: 16, weight: .semibold, design: .rounded)
            case .hero:   return .system(size: 22, weight: .semibold, design: .rounded)
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small:  return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            case .large:  return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .hero:   return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small:  return 8
            case .medium: return 12
            case .large:  return 16
            case .hero:   return 0
            }
        }
    }

    private var color: Color {
        guard let temp = temperature else { return .gray }
        if temp > 22 { return AppTheme.coral }
        if temp >= 18 { return AppTheme.freshGreen }
        if temp >= 14 { return AppTheme.skyBlue }
        return AppTheme.oceanBlue
    }

    var body: some View {
        if size == .hero {
            heroView
        } else if temperature != nil {
            badgeView
        } else {
            unavailableBadge
        }
    }

    private var heroView: some View {
        Group {
            if let temp = temperature {
                VStack(spacing: 4) {
                    HStack(alignment: .top, spacing: 2) {
                        Text(temp.formatted(.number.precision(.fractionLength(1))))
                            .font(size.font)
                            .foregroundStyle(isOutdated ? color.opacity(0.5) : color)
                        Text("°C")
                            .font(size.unitFont)
                            .foregroundStyle(color.opacity(isOutdated ? 0.35 : 0.7))
                            .padding(.top, 8)
                    }

                    if isOutdated {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                            Text("Stand: \(measurementDate ?? "unbekannt")")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "thermometer.medium.slash")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Nicht verfügbar")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("(Messungen: Juni bis August)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var badgeView: some View {
        HStack(spacing: 2) {
            Text((temperature ?? 0).formatted(.number.precision(.fractionLength(1))))
                .font(size.font)
            Text("°C")
                .font(size.unitFont)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(size.padding)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(color.opacity(isOutdated ? 0.45 : 1.0))
                .shadow(color: color.opacity(isOutdated ? 0.15 : 0.35), radius: 4, y: 2)
        )
        .overlay(alignment: .topTrailing) {
            if isOutdated {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: size == .small ? 7 : 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(2.5)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .offset(x: 4, y: -4)
            }
        }
    }

    private var unavailableBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "thermometer.medium.slash")
                .font(.system(size: size == .small ? 10 : 12))
            Text("n/a")
                .font(size == .small ?
                    .system(size: 11, weight: .medium, design: .rounded) :
                    .system(size: 13, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary)
        .padding(size.padding)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
    }
}

#Preview("Standard") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            TemperatureBadge(temperature: 24.5, size: .small)
            TemperatureBadge(temperature: 20.0, size: .small)
            TemperatureBadge(temperature: nil, size: .small)
        }
        HStack(spacing: 12) {
            TemperatureBadge(temperature: 24.5, size: .medium)
            TemperatureBadge(temperature: nil, size: .medium)
        }
        TemperatureBadge(temperature: 24.5, size: .large)
        TemperatureBadge(temperature: nil, size: .hero)
        TemperatureBadge(temperature: 22.3, size: .hero)
    }
    .padding()
    .background(AppTheme.pageBackground)
}

#Preview("Outdated") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            TemperatureBadge(temperature: 24.5, size: .small, isOutdated: true)
            TemperatureBadge(temperature: 18.2, size: .small, isOutdated: true)
        }
        HStack(spacing: 12) {
            TemperatureBadge(temperature: 24.5, size: .medium, isOutdated: true)
            TemperatureBadge(temperature: 15.0, size: .medium, isOutdated: true)
        }
        TemperatureBadge(temperature: 24.5, size: .large, isOutdated: true)
        TemperatureBadge(temperature: 22.3, size: .hero, isOutdated: true, measurementDate: "29.08.2025")
    }
    .padding()
    .background(AppTheme.pageBackground)
}
