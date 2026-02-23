import SwiftUI

struct TemperatureBadge: View {
    let temperature: Double?
    var size: BadgeSize = .medium

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
                HStack(alignment: .top, spacing: 2) {
                    Text(String(format: "%.1f", temp))
                        .font(size.font)
                        .foregroundStyle(color)
                    Text("°C")
                        .font(size.unitFont)
                        .foregroundStyle(color.opacity(0.7))
                        .padding(.top, 8)
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "thermometer.medium.slash")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Nicht verfügbar")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var badgeView: some View {
        HStack(spacing: 2) {
            Text(String(format: "%.1f", temperature ?? 0))
                .font(size.font)
            Text("°C")
                .font(size.unitFont)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(size.padding)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(color)
                .shadow(color: color.opacity(0.35), radius: 4, y: 2)
        )
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

#Preview {
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
