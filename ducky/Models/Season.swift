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

    /// Screenshot mode: treats last year's summer measurements as fresh
    nonisolated(unsafe) static var _screenshotMode = false
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

        #if DEBUG
        if _screenshotMode {
            // Accept previous year's summer data too
            let isFromRecentSummer = (measureYear == currentYear || measureYear == currentYear - 1) && (6...8).contains(measureMonth)
            return !(isSwimmingSeason && isFromRecentSummer)
        }
        #endif

        return !(isSwimmingSeason && isFromCurrentSummer)
    }

    /// Extract the year from a measurement date string, e.g. "2025"
    static func measurementYear(from dateString: String?) -> String? {
        guard let date = parseMeasurementDate(dateString) else { return nil }
        return String(Calendar.current.component(.year, from: date))
    }

}
