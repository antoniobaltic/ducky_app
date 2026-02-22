import SwiftUI

enum DuckState: String, Equatable {
    case begeistert
    case zufrieden
    case zoegernd
    case frierend
    case warnend

    var title: String {
        switch self {
        case .begeistert: return "Begeistert"
        case .zufrieden:  return "Zufrieden"
        case .zoegernd:   return "Zögernd"
        case .frierend:   return "Frierend"
        case .warnend:    return "Warnend"
        }
    }

    var line: String {
        switch self {
        case .begeistert: return "Spring rein!"
        case .zufrieden:  return "Eigentlich sehr angenehm."
        case .zoegernd:   return "Mutige schaffen das."
        case .frierend:   return "Absolut nicht."
        case .warnend:    return "Ich würd's lassen."
        }
    }

    var bodyColor: Color {
        switch self {
        case .begeistert: return Color(red: 1.0, green: 0.85, blue: 0.20)
        case .zufrieden:  return Color(red: 0.98, green: 0.80, blue: 0.28)
        case .zoegernd:   return Color(red: 0.90, green: 0.75, blue: 0.38)
        case .frierend:   return Color(red: 0.72, green: 0.87, blue: 1.00)
        case .warnend:    return Color(red: 1.00, green: 0.72, blue: 0.60)
        }
    }

    var billColor: Color {
        switch self {
        case .frierend: return Color(red: 0.80, green: 0.70, blue: 1.00)
        default:        return Color(red: 1.00, green: 0.52, blue: 0.08)
        }
    }

    var backgroundGradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .begeistert: colors = [Color(red: 0.88, green: 0.97, blue: 1.00), Color(red: 0.65, green: 0.88, blue: 1.00)]
        case .zufrieden:  colors = [Color(red: 0.88, green: 0.97, blue: 0.95), Color(red: 0.62, green: 0.87, blue: 0.88)]
        case .zoegernd:   colors = [Color(red: 0.95, green: 0.95, blue: 0.82), Color(red: 0.78, green: 0.85, blue: 0.70)]
        case .frierend:   colors = [Color(red: 0.82, green: 0.90, blue: 1.00), Color(red: 0.55, green: 0.72, blue: 0.95)]
        case .warnend:    colors = [Color(red: 1.00, green: 0.90, blue: 0.85), Color(red: 0.95, green: 0.72, blue: 0.65)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var accentColor: Color {
        switch self {
        case .begeistert: return .orange
        case .zufrieden:  return Color(red: 0.20, green: 0.75, blue: 0.40)
        case .zoegernd:   return Color(red: 0.60, green: 0.55, blue: 0.20)
        case .frierend:   return Color(red: 0.30, green: 0.45, blue: 0.90)
        case .warnend:    return Color(red: 0.85, green: 0.20, blue: 0.20)
        }
    }
}
