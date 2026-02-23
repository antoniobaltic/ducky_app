import SwiftUI

// MARK: - Season Model

enum Season: String, CaseIterable {
    case winter    // Dec, Jan, Feb
    case spring    // Mar, Apr, May
    case summer    // Jun, Jul, Aug
    case autumn    // Sep, Oct, Nov

    // MARK: - Current Season

    #if DEBUG
    /// Override for previews/testing. Set to nil for real behavior.
    nonisolated(unsafe) static var _previewOverride: Season?
    #endif

    static var current: Season {
        #if DEBUG
        if let override = _previewOverride { return override }
        #endif
        return season(for: Date())
    }

    static func season(for date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 12, 1, 2:  return .winter
        case 3, 4, 5:   return .spring
        case 6, 7, 8:   return .summer
        case 9, 10, 11: return .autumn
        default:         return .summer
        }
    }

    /// True only during June–August when AGES actively measures water temperature
    static var isSwimmingSeason: Bool { current == .summer }

    /// True outside the measurement season (Sep–May)
    static var isOffSeason: Bool { !isSwimmingSeason }

    // MARK: - Measurement Date Parsing

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        f.locale = Locale(identifier: "de_AT")
        return f
    }()

    /// Parse "DD.MM.YYYY" format from AGES API
    static func parseMeasurementDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        return dateFormatter.date(from: dateString)
    }

    /// Check if a measurement date is outdated.
    /// Outdated = outside current year's Jun–Aug, or no date at all.
    static func isMeasurementOutdated(_ dateString: String?) -> Bool {
        guard let date = parseMeasurementDate(dateString) else {
            // No measurement date → outdated unless we're in summer and there's data
            return true
        }

        let calendar = Calendar.current
        let now = Date()
        let measureYear = calendar.component(.year, from: date)
        let measureMonth = calendar.component(.month, from: date)
        let currentYear = calendar.component(.year, from: now)

        // Fresh only if: measurement is from current year's Jun–Aug AND we're currently in summer
        let isFromCurrentSummer = measureYear == currentYear && (6...8).contains(measureMonth)
        return !(isSwimmingSeason && isFromCurrentSummer)
    }

    /// Extract the year from a measurement date string, e.g. "2025"
    static func measurementYear(from dateString: String?) -> String? {
        guard let date = parseMeasurementDate(dateString) else { return nil }
        return String(Calendar.current.component(.year, from: date))
    }

    // MARK: - Seasonal Hero Appearance

    var heroGradient: LinearGradient {
        LinearGradient(colors: heroGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var heroGradientColors: [Color] {
        switch self {
        case .winter:
            return [
                Color(red: 0.72, green: 0.84, blue: 0.96),
                Color(red: 0.45, green: 0.60, blue: 0.82)
            ]
        case .spring:
            return [
                Color(red: 0.55, green: 0.82, blue: 0.68),
                Color(red: 0.35, green: 0.68, blue: 0.55)
            ]
        case .summer:
            return [
                Color(red: 0.25, green: 0.58, blue: 1.0),
                Color(red: 0.10, green: 0.40, blue: 0.90)
            ]
        case .autumn:
            return [
                Color(red: 0.90, green: 0.68, blue: 0.42),
                Color(red: 0.75, green: 0.48, blue: 0.30)
            ]
        }
    }

    var waveColor: Color {
        switch self {
        case .winter: return Color(red: 0.72, green: 0.84, blue: 0.96)
        case .spring: return AppTheme.freshGreen
        case .summer: return .white
        case .autumn: return Color(red: 0.90, green: 0.68, blue: 0.42)
        }
    }

    var duckState: DuckState {
        switch self {
        case .winter:  return .frierend
        case .spring:  return .zoegernd
        case .summer:  return .zufrieden
        case .autumn:  return .zoegernd
        }
    }

    var heroTitle: String {
        switch self {
        case .winter:  return "Winterpause"
        case .spring:  return "Bald geht's los!"
        case .summer:  return "" // Summer uses dynamic time-of-day greeting
        case .autumn:  return "Saison vorbei"
        }
    }

    var heroMessage: String {
        switch self {
        case .winter:
            return "Die Seen ruhen. Wassertemperaturen werden von Juni bis August gemessen."
        case .spring:
            return "Noch zu frisch zum Baden — aber es wird! Neue Messdaten gibt es ab Juni."
        case .summer:
            return "" // Summer uses data-driven messaging
        case .autumn:
            return "Die Badesaison ist vorbei. Die angezeigten Temperaturen sind vom letzten Sommer."
        }
    }

    var heroIcon: String {
        switch self {
        case .winter:  return "snowflake"
        case .spring:  return "leaf.fill"
        case .summer:  return "sun.max.fill"
        case .autumn:  return "leaf.fill"
        }
    }
}
