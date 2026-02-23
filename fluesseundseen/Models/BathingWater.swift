import Foundation
import CoreLocation
import SwiftUI

struct BathingWater: Identifiable, Hashable {
    let id: String
    let name: String
    let municipality: String?
    let district: String?
    let state: String?
    let latitude: Double
    let longitude: Double
    let waterTemperature: Double?
    let qualityRating: String?
    let eColi: Double?
    let enterococci: Double?
    let visibilityDepth: Double?
    let measurementDate: String?
    let url: String?
    let isClosed: Bool
    let closureReason: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    // MARK: - Computed Properties

    var duckState: DuckState {
        if isClosed { return .warnend }
        if let rating = qualityRating?.uppercased(),
           rating == "M" || rating.contains("MANGELHAFT") || rating.contains("POOR") {
            return .warnend
        }
        guard let temp = waterTemperature else { return .zufrieden }
        if temp > 22 { return .begeistert }
        if temp >= 18 { return .zufrieden }
        if temp >= 14 { return .zoegernd }
        return .frierend
    }

    var qualityColor: Color {
        guard let rating = qualityRating?.uppercased() else { return .gray }
        switch rating {
        case "A": return AppTheme.freshGreen
        case "G": return AppTheme.teal
        case "AU": return .orange
        case "M": return AppTheme.coral
        default:
            let r = rating.lowercased()
            if r.contains("ausgezeichnet") || r.contains("excellent") { return AppTheme.freshGreen }
            if r.contains("gut") || r.contains("good") { return AppTheme.teal }
            if r.contains("ausreichend") || r.contains("sufficient") { return .orange }
            if r.contains("mangelhaft") || r.contains("poor") { return AppTheme.coral }
            return .gray
        }
    }

    var qualityLabel: String {
        guard let rating = qualityRating?.uppercased(), !rating.isEmpty else { return "Keine Einstufung" }
        switch rating {
        case "A": return "Ausgezeichnet"
        case "G": return "Gut"
        case "AU": return "Ausreichend"
        case "M": return "Mangelhaft"
        default:
            let r = rating.lowercased()
            if r.contains("ausgezeichnet") || r.contains("excellent") { return "Ausgezeichnet" }
            if r.contains("gut") || r.contains("good") { return "Gut" }
            if r.contains("ausreichend") || r.contains("sufficient") { return "Ausreichend" }
            if r.contains("mangelhaft") || r.contains("poor") { return "Mangelhaft" }
            return rating
        }
    }

    var temperatureDisplay: String {
        guard let temp = waterTemperature else { return "Nicht verfügbar" }
        return String(format: "%.1f°C", temp)
    }

    var hasTemperature: Bool {
        waterTemperature != nil
    }

    var temperatureColor: Color {
        guard let temp = waterTemperature else { return .gray }
        if temp > 22 { return AppTheme.coral }
        if temp >= 18 { return AppTheme.freshGreen }
        if temp >= 14 { return AppTheme.skyBlue }
        return AppTheme.oceanBlue
    }

    var eColiStatus: TrafficLight {
        guard let val = eColi else { return .unknown }
        if val <= 500 { return .green }
        if val <= 1000 { return .yellow }
        return .red
    }

    var enterococciStatus: TrafficLight {
        guard let val = enterococci else { return .unknown }
        if val <= 200 { return .green }
        if val <= 400 { return .yellow }
        return .red
    }

    func distance(from userLocation: CLLocation) -> Double {
        location.distance(from: userLocation) / 1000.0
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BathingWater, rhs: BathingWater) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Traffic Light

enum TrafficLight {
    case green, yellow, red, unknown

    var color: Color {
        switch self {
        case .green:   return AppTheme.freshGreen
        case .yellow:  return AppTheme.sunshine
        case .red:     return AppTheme.coral
        case .unknown: return .gray
        }
    }

    var label: String {
        switch self {
        case .green:   return "Gut"
        case .yellow:  return "Erhöht"
        case .red:     return "Zu hoch"
        case .unknown: return "–"
        }
    }
}

// MARK: - JSON Decoding (AGES nested format)

extension BathingWater {
    static func decode(from dict: [String: Any], state: String? = nil) -> BathingWater? {
        func string(_ keys: String...) -> String? {
            for key in keys {
                if let v = dict[key] as? String, !v.isEmpty { return v }
            }
            return nil
        }

        func double(_ keys: String...) -> Double? {
            for key in keys {
                if let v = dict[key] as? Double { return v }
                if let v = dict[key] as? Int { return Double(v) }
                if let s = dict[key] as? String {
                    let normalized = s.replacingOccurrences(of: ",", with: ".")
                        .trimmingCharacters(in: .whitespaces)
                    if let v = Double(normalized) { return v }
                }
            }
            return nil
        }

        // Require name and coordinates
        guard
            let name = string("BADEGEWAESSERNAME", "Name", "name", "Bezeichnung"),
            let lat = double("LATITUDE", "Lat", "lat", "latitude", "Breitengrad"),
            let lon = double("LONGITUDE", "Lng", "lng", "Lon", "lon", "longitude", "Laengengrad"),
            lat != 0, lon != 0
        else { return nil }

        let id = string("BADEGEWAESSERID", "BWK_ID", "Id", "id", "ID") ?? "\(lat),\(lon)"

        // Parse latest measurement from MESSWERTE array
        var waterTemp: Double?
        var eColi: Double?
        var enterococci: Double?
        var visibility: Double?
        var measureDate: String?

        if let messwerte = dict["MESSWERTE"] as? [[String: Any]], let latest = messwerte.first {
            waterTemp = (latest["W"] as? Double) ?? (latest["W"] as? Int).map(Double.init)
            eColi = (latest["E_C"] as? Double) ?? (latest["E_C"] as? Int).map(Double.init)
            enterococci = (latest["E"] as? Double) ?? (latest["E"] as? Int).map(Double.init)
            visibility = (latest["S"] as? Double) ?? (latest["S"] as? Int).map(Double.init)
            measureDate = latest["D"] as? String
        }

        // Fall back to top-level fields if MESSWERTE not present
        if waterTemp == nil {
            waterTemp = double("Wassertemperatur", "wassertemperatur", "WasserTemp", "temperature")
        }
        if eColi == nil {
            eColi = double("EColi", "ecoli", "E_Coli", "e_coli", "KBE_EColi")
        }
        if enterococci == nil {
            enterococci = double("Enterokokken", "enterokokken", "KBE_Enterokokken")
        }
        if visibility == nil {
            visibility = double("Sichttiefe", "sichttiefe", "Sichttiefe_m")
        }
        if measureDate == nil {
            measureDate = string("Messdatum", "messdatum", "Datum", "datum", "date", "Aktuell_Datum")
        }

        // Parse quality: prefer current year, fall back to previous years
        let quality = string(
            "QUALITAET_2026", "QUALITAET_2025", "QUALITAET_2024", "QUALITAET_2023",
            "Bewertung", "bewertung", "Einstufung", "einstufung", "quality"
        )

        // Closed status
        let closedStr = string("TGESPERRT")
        let isClosed = closedStr == "1"

        return BathingWater(
            id: id,
            name: name,
            municipality: string("GEMEINDE", "Gemeinde", "gemeinde", "municipality"),
            district: string("BEZIRK", "Bezirk", "bezirk"),
            state: state ?? string("Bundesland", "bundesland", "state", "Bundesland_Name"),
            latitude: lat,
            longitude: lon,
            waterTemperature: waterTemp,
            qualityRating: quality,
            eColi: eColi,
            enterococci: enterococci,
            visibilityDepth: visibility,
            measurementDate: measureDate,
            url: string("URL", "url", "Url", "Link", "link"),
            isClosed: isClosed,
            closureReason: string("SPERRGRUND", "Sperrgrund")
        )
    }
}

// MARK: - Sample Data for Previews

extension BathingWater {
    static let preview = BathingWater(
        id: "AT-BW-001", name: "Grundlsee", municipality: "Bad Aussee",
        district: "Liezen", state: "Steiermark",
        latitude: 47.6264, longitude: 13.7978,
        waterTemperature: 23.5, qualityRating: "A",
        eColi: 50, enterococci: 20, visibilityDepth: 4.0,
        measurementDate: "21.07.2025", url: nil, isClosed: false, closureReason: nil
    )

    static let previewCold = BathingWater(
        id: "AT-BW-002", name: "Wolfgangsee", municipality: "St. Gilgen",
        district: "Salzburg-Umgebung", state: "Salzburg",
        latitude: 47.7411, longitude: 13.3840,
        waterTemperature: 12.0, qualityRating: "G",
        eColi: 80, enterococci: 30, visibilityDepth: 3.5,
        measurementDate: "21.07.2025", url: nil, isClosed: false, closureReason: nil
    )

    static let previewWarn = BathingWater(
        id: "AT-BW-003", name: "Neusiedler See", municipality: "Neusiedl am See",
        district: "Neusiedl am See", state: "Burgenland",
        latitude: 47.8568, longitude: 16.7714,
        waterTemperature: 26.0, qualityRating: "M",
        eColi: 1500, enterococci: 600, visibilityDepth: 0.5,
        measurementDate: "21.07.2025", url: nil, isClosed: false, closureReason: nil
    )

    static let previewNoTemp = BathingWater(
        id: "AT-BW-006", name: "Millstätter See", municipality: "Millstatt",
        district: "Spittal an der Drau", state: "Kärnten",
        latitude: 46.7944, longitude: 13.5803,
        waterTemperature: nil, qualityRating: "A",
        eColi: nil, enterococci: nil, visibilityDepth: nil,
        measurementDate: nil, url: nil, isClosed: false, closureReason: nil
    )

    static let previews: [BathingWater] = [
        .preview, .previewCold, .previewWarn, .previewNoTemp,
        BathingWater(id: "AT-BW-004", name: "Hallstätter See", municipality: "Hallstatt",
                     district: "Gmunden", state: "Oberösterreich",
                     latitude: 47.5622, longitude: 13.6493,
                     waterTemperature: 19.0, qualityRating: "A",
                     eColi: 40, enterococci: 15, visibilityDepth: 5.0,
                     measurementDate: "21.07.2025", url: nil, isClosed: false, closureReason: nil),
        BathingWater(id: "AT-BW-005", name: "Attersee", municipality: "Attersee",
                     district: "Vöcklabruck", state: "Oberösterreich",
                     latitude: 47.8669, longitude: 13.5403,
                     waterTemperature: 21.5, qualityRating: "A",
                     eColi: 60, enterococci: 25, visibilityDepth: 6.0,
                     measurementDate: "21.07.2025", url: nil, isClosed: false, closureReason: nil),
    ]
}
