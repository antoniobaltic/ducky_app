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
            case .hero:   return .system(size: 56, weight: .heavy, design: .rounded)
            }
        }

        var unitFont: Font {
            switch self {
            case .small:  return .system(size: 10, weight: .semibold, design: .rounded)
            case .medium: return .system(size: 12, weight: .semibold, design: .rounded)
            case .large:  return .system(size: 16, weight: .semibold, design: .rounded)
            case .hero:   return .system(size: 24, weight: .semibold, design: .rounded)
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
        if temp > 22 { return Color(red: 1.0, green: 0.40, blue: 0.15) }
        if temp >= 18 { return Color(red: 0.15, green: 0.72, blue: 0.38) }
        if temp >= 14 { return Color(red: 0.15, green: 0.58, blue: 0.85) }
        return Color(red: 0.28, green: 0.38, blue: 0.90)
    }

    var body: some View {
        if size == .hero {
            heroView
        } else {
            badgeView
        }
    }

    private var heroView: some View {
        HStack(alignment: .top, spacing: 2) {
            Text(formattedTemp)
                .font(size.font)
                .foregroundStyle(color)
            Text("°C")
                .font(size.unitFont)
                .foregroundStyle(color.opacity(0.8))
                .padding(.top, 10)
        }
    }

    private var badgeView: some View {
        HStack(spacing: 2) {
            Text(formattedTemp)
                .font(size.font)
            Text("°C")
                .font(size.unitFont)
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(size.padding)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(color)
                .shadow(color: color.opacity(0.4), radius: 4, y: 2)
        )
    }

    private var formattedTemp: String {
        guard let temp = temperature else { return "–" }
        return String(format: "%.1f", temp)
    }
}

#Preview {
    HStack(spacing: 16) {
        VStack(spacing: 12) {
            TemperatureBadge(temperature: 24.5, size: .small)
            TemperatureBadge(temperature: 20.0, size: .small)
            TemperatureBadge(temperature: 16.0, size: .small)
            TemperatureBadge(temperature: 11.0, size: .small)
            TemperatureBadge(temperature: nil, size: .small)
        }
        VStack(spacing: 12) {
            TemperatureBadge(temperature: 24.5, size: .medium)
            TemperatureBadge(temperature: 20.0, size: .medium)
            TemperatureBadge(temperature: 16.0, size: .medium)
            TemperatureBadge(temperature: 11.0, size: .medium)
        }
        VStack(spacing: 12) {
            TemperatureBadge(temperature: 24.5, size: .large)
            TemperatureBadge(temperature: 20.0, size: .large)
        }
    }
    .padding()
    .background(Color(white: 0.95))
}
