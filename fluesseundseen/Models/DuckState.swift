import SwiftUI

enum DuckState: String, Equatable, CaseIterable {
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
        case .begeistert: return "Perfekter Badetag! Ab ins Wasser!"
        case .zufrieden:  return "Gute Bedingungen — Ducky freut sich!"
        case .zoegernd:   return "Geht so — vielleicht nur kurz rein?"
        case .frierend:   return "Eher ein Tag für Kakao am Ufer."
        case .warnend:    return "Lieber nicht ins Wasser heute!"
        }
    }

    var emoji: String {
        switch self {
        case .begeistert: return "🤩"
        case .zufrieden:  return "😊"
        case .zoegernd:   return "🤔"
        case .frierend:   return "🥶"
        case .warnend:    return "⚠️"
        }
    }

    var bodyColor: Color {
        switch self {
        case .begeistert: return Color(red: 1.0, green: 0.85, blue: 0.20)
        case .zufrieden:  return Color(red: 0.98, green: 0.82, blue: 0.30)
        case .zoegernd:   return Color(red: 0.92, green: 0.78, blue: 0.38)
        case .frierend:   return Color(red: 0.75, green: 0.88, blue: 1.00)
        case .warnend:    return Color(red: 1.00, green: 0.75, blue: 0.62)
        }
    }

    var billColor: Color {
        switch self {
        case .frierend: return Color(red: 0.80, green: 0.70, blue: 1.00)
        default:        return Color(red: 1.00, green: 0.55, blue: 0.10)
        }
    }

    var backgroundGradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .begeistert: colors = [Color(red: 0.93, green: 0.98, blue: 1.00), Color(red: 0.72, green: 0.91, blue: 1.00)]
        case .zufrieden:  colors = [Color(red: 0.92, green: 0.98, blue: 0.95), Color(red: 0.68, green: 0.90, blue: 0.88)]
        case .zoegernd:   colors = [Color(red: 0.97, green: 0.96, blue: 0.88), Color(red: 0.82, green: 0.88, blue: 0.75)]
        case .frierend:   colors = [Color(red: 0.88, green: 0.93, blue: 1.00), Color(red: 0.62, green: 0.78, blue: 0.97)]
        case .warnend:    colors = [Color(red: 1.00, green: 0.93, blue: 0.88), Color(red: 0.97, green: 0.78, blue: 0.70)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var accentColor: Color {
        switch self {
        case .begeistert: return AppTheme.sunshine
        case .zufrieden:  return AppTheme.freshGreen
        case .zoegernd:   return AppTheme.sunshine.opacity(0.8)
        case .frierend:   return AppTheme.oceanBlue
        case .warnend:    return AppTheme.coral
        }
    }
}
