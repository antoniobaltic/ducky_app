import SwiftUI

enum DuckState: String, Equatable, CaseIterable {
    case begeistert
    case zufrieden
    case zoegernd
    case frierend
    case warnend
    case columbo

    var title: String {
        switch self {
        case .begeistert: return "Begeistert"
        case .zufrieden:  return "Zufrieden"
        case .zoegernd:   return "Zögernd"
        case .frierend:   return "Angewidert"
        case .warnend:    return "Warnend"
        case .columbo:    return "Columbo"
        }
    }

    var line: String {
        switch self {
        case .begeistert: return "REIN DA! Ducky dreht durch — PERFEKT!"
        case .zufrieden:  return "Schaut gut aus! Ducky nickt zufrieden."
        case .zoegernd:   return "Hm. Ducky ist skeptisch. Traust du dich?"
        case .frierend:   return "Puh. Ducky rümpft die Nase."
        case .warnend:    return "Nein. Einfach nein. Ducky streikt."
        case .columbo:    return "Nur noch eine Sache..."
        }
    }

    var emoji: String {
        switch self {
        case .begeistert: return "🤩"
        case .zufrieden:  return "😊"
        case .zoegernd:   return "🤔"
        case .frierend:   return "🤢"
        case .warnend:    return "⚠️"
        case .columbo:    return "🕵️"
        }
    }

    var bodyColor: Color {
        Color(red: 1.00, green: 0.85, blue: 0.20)
    }

    var billColor: Color {
        Color(red: 1.00, green: 0.55, blue: 0.10)
    }

    var backgroundGradient: LinearGradient {
        let base = AppTheme.scoreColor(for: scoreLevel)
        return LinearGradient(
            colors: [base.opacity(0.22), base.opacity(0.11)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var scoreLevel: SwimScore.Level {
        switch self {
        case .begeistert: return .perfekt
        case .zufrieden:  return .gut
        case .zoegernd:   return .mittel
        case .frierend:   return .schlecht
        case .warnend:    return .warnung
        case .columbo:    return .gut
        }
    }

    var accentColor: Color {
        switch self {
        case .begeistert: return AppTheme.sunshine
        case .zufrieden:  return AppTheme.freshGreen
        case .zoegernd:   return AppTheme.sunshine.opacity(0.8)
        case .frierend:   return AppTheme.freshGreen
        case .warnend:    return AppTheme.coral
        case .columbo:    return Color(red: 0.55, green: 0.45, blue: 0.35)
        }
    }
}
