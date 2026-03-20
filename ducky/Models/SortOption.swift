import SwiftUI

enum SortOption: String, CaseIterable {
    case bestScore, nearest, alphabetical, airTemperature, waterTemperature

    static let displayOrder: [SortOption] = [
        .bestScore,
        .nearest,
        .alphabetical,
        .airTemperature,
        .waterTemperature
    ]

    var label: String {
        switch self {
        case .bestScore:    return "Bester Score"
        case .nearest:      return "Entfernung"
        case .alphabetical: return "A–Z"
        case .airTemperature: return "Lufttemperatur"
        case .waterTemperature: return "Wassertemperatur"
        }
    }

    var icon: String {
        switch self {
        case .bestScore:    return "star.fill"
        case .nearest:      return "location.fill"
        case .alphabetical: return "textformat.abc"
        case .airTemperature: return "wind"
        case .waterTemperature: return "drop.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .bestScore:        return AppTheme.sunshine
        case .nearest:          return AppTheme.teal
        case .alphabetical:     return AppTheme.oceanBlue
        case .airTemperature:   return AppTheme.airTempGreen
        case .waterTemperature: return AppTheme.skyBlue
        }
    }

    var shortLabel: String {
        switch self {
        case .bestScore: return "Score"
        case .nearest: return "Entfernung"
        case .alphabetical: return "A-Z"
        case .airTemperature: return "Luft"
        case .waterTemperature: return "Wasser"
        }
    }

    var defaultDirection: SortDirection {
        switch self {
        case .nearest, .alphabetical: return .ascending
        case .bestScore, .airTemperature, .waterTemperature: return .descending
        }
    }
}

enum SortDirection {
    case ascending
    case descending

    var symbol: String {
        switch self {
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}
