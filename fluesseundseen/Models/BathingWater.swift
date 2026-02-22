import Foundation
import CoreLocation
import SwiftUI

struct BathingWater: Identifiable, Hashable {
    let id: String
    let name: String
    let municipality: String?
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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    // MARK: - Computed Properties

    var duckState: DuckState {
        if let rating = qualityRating?.lowercased(),
           rating.contains("mangelhaft") || rating.contains("poor") || rating.contains("schlecht") {
            return .warnend
        }
        guard let temp = waterTemperature else { return .zufrieden }
        if temp > 22 { return .begeistert }
        if temp >= 18 { return .zufrieden }
        if temp >= 14 { return .zoegernd }
        return .frierend
    }

    var qualityColor: Color {
        guard let rating = qualityRating?.lowercased() else { return .gray }
        if rating.contains("ausgezeichnet") || rating.contains("excellent") { return .green }
        if rating.contains("gut") || rating.contains("good") { return Color(red: 0.6, green: 0.85, blue: 0.2) }
        if rating.contains("ausreichend") || rating.contains("sufficient") { return .orange }
        if rating.contains("mangelhaft") || rating.contains("poor") { return .red }
        return .gray
    }

    var qualityLabel: String {
        guard let rating = qualityRating?.lowercased() else { return "Unbekannt" }
        if rating.contains("ausgezeichnet") || rating.contains("excellent") { return "Ausgezeichnet ✓" }
        if rating.contains("gut") || rating.contains("good") { return "Gut ✓" }
        if rating.contains("ausreichend") || rating.contains("sufficient") { return "Ausreichend" }
        if rating.contains("mangelhaft") || rating.contains("poor") { return "Mangelhaft ✗" }
        return qualityRating ?? "Unbekannt"
    }

    var temperatureColor: Color {
        guard let temp = waterTemperature else { return .gray }
        if temp > 22 { return Color(red: 1.0, green: 0.40, blue: 0.15) }
        if temp >= 18 { return Color(red: 0.15, green: 0.72, blue: 0.38) }
        if temp >= 14 { return Color(red: 0.15, green: 0.58, blue: 0.85) }
        return Color(red: 0.28, green: 0.38, blue: 0.90)
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
        case .green:   return .green
        case .yellow:  return .yellow
        case .red:     return .red
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

// MARK: - JSON Decoding

extension BathingWater {
    // Flexible decoder for the AGES JSON which may use various field name conventions
    static func decode(from dict: [String: Any]) -> BathingWater? {
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

        // Require at minimum a name and coordinates
        guard
            let name = string("Name", "name", "Bezeichnung", "bezeichnung", "BEZEICHNUNG"),
            let lat = double("Lat", "lat", "latitude", "Latitude", "Breitengrad", "breitengrad", "BREITENGRAD"),
            let lon = double("Lng", "lng", "Lon", "lon", "longitude", "Longitude", "Laengengrad", "laengengrad", "LAENGENGRAD"),
            lat != 0, lon != 0
        else { return nil }

        let id = string("BWK_ID", "Id", "id", "ID", "bwk_id", "BwkId") ?? "\(lat),\(lon)"

        return BathingWater(
            id: id,
            name: name,
            municipality: string("Gemeinde", "gemeinde", "GEMEINDE", "municipality"),
            state: string("Bundesland", "bundesland", "BUNDESLAND", "state", "Bundesland_Name"),
            latitude: lat,
            longitude: lon,
            waterTemperature: double("Wassertemperatur", "wassertemperatur", "WasserTemp", "temperature", "Temperature", "Temperatur"),
            qualityRating: string("Bewertung", "bewertung", "Einstufung", "einstufung", "quality", "Quality", "Qualitaet", "qualitaet"),
            eColi: double("EColi", "ecoli", "E_Coli", "e_coli", "Ecoli", "KBE_EColi"),
            enterococci: double("Enterokokken", "enterokokken", "ENTEROKOKKEN", "KBE_Enterokokken"),
            visibilityDepth: double("Sichttiefe", "sichttiefe", "SICHTTIEFE", "visibility", "Sichttiefe_m"),
            measurementDate: string("Messdatum", "messdatum", "Datum", "datum", "date", "Date", "Aktuell_Datum"),
            url: string("URL", "url", "Url", "Link", "link")
        )
    }
}

// MARK: - Sample Data for Previews

extension BathingWater {
    static let preview = BathingWater(
        id: "AT-BW-001",
        name: "Grundlsee",
        municipality: "Bad Aussee",
        state: "Steiermark",
        latitude: 47.6264,
        longitude: 13.7978,
        waterTemperature: 23.5,
        qualityRating: "ausgezeichnet",
        eColi: 50,
        enterococci: 20,
        visibilityDepth: 4.0,
        measurementDate: "21.07.2025",
        url: nil
    )

    static let previewCold = BathingWater(
        id: "AT-BW-002",
        name: "Wolfgangsee",
        municipality: "St. Gilgen",
        state: "Salzburg",
        latitude: 47.7411,
        longitude: 13.3840,
        waterTemperature: 12.0,
        qualityRating: "gut",
        eColi: 80,
        enterococci: 30,
        visibilityDepth: 3.5,
        measurementDate: "21.07.2025",
        url: nil
    )

    static let previewWarn = BathingWater(
        id: "AT-BW-003",
        name: "Neusiedler See",
        municipality: "Neusiedl am See",
        state: "Burgenland",
        latitude: 47.8568,
        longitude: 16.7714,
        waterTemperature: 26.0,
        qualityRating: "mangelhaft",
        eColi: 1500,
        enterococci: 600,
        visibilityDepth: 0.5,
        measurementDate: "21.07.2025",
        url: nil
    )

    static let previews: [BathingWater] = [
        .preview,
        .previewCold,
        .previewWarn,
        BathingWater(id: "AT-BW-004", name: "Hallstätter See", municipality: "Hallstatt", state: "Oberösterreich", latitude: 47.5622, longitude: 13.6493, waterTemperature: 19.0, qualityRating: "ausgezeichnet", eColi: 40, enterococci: 15, visibilityDepth: 5.0, measurementDate: "21.07.2025", url: nil),
        BathingWater(id: "AT-BW-005", name: "Attersee", municipality: "Attersee", state: "Oberösterreich", latitude: 47.8669, longitude: 13.5403, waterTemperature: 21.5, qualityRating: "ausgezeichnet", eColi: 60, enterococci: 25, visibilityDepth: 6.0, measurementDate: "21.07.2025", url: nil)
    ]
}
