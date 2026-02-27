import Foundation
import CoreLocation
import MapKit
import Observation

@MainActor
@Observable
final class LakePlaceService {
    static let shared = LakePlaceService()

    var placeCache: [String: MKMapItem] = [:]
    var cacheRevision = 0

    private init() {}

    func fetchPlace(for lake: BathingWater, forceRefresh: Bool = false) async -> MKMapItem? {
        if !forceRefresh, let cached = placeCache[lake.id] {
            return cached
        }

        let resolved = await resolveBestPlace(for: lake)
        if let resolved {
            placeCache[lake.id] = resolved
        } else {
            placeCache.removeValue(forKey: lake.id)
        }
        cacheRevision &+= 1
        return resolved
    }
}

// MARK: - Matching

extension LakePlaceService {
    private struct ScoredCandidate {
        let item: MKMapItem
        let distanceKm: Double
        let nameStrength: Int
        let score: Int
    }

    private func resolveBestPlace(for lake: BathingWater) async -> MKMapItem? {
        var collectedItems: [MKMapItem] = []

        for query in queryCandidates(for: lake) {
            let items = await searchItems(query: query, around: lake.coordinate)
            guard !items.isEmpty else { continue }
            collectedItems.append(contentsOf: items)
        }

        return bestCandidate(from: collectedItems, for: lake)?.item
    }

    private func searchItems(query: String, around coordinate: CLLocationCoordinate2D) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 45_000,
            longitudinalMeters: 45_000
        )
        request.resultTypes = [.address, .pointOfInterest]
        if #available(iOS 18.0, macOS 15.0, visionOS 2.0, tvOS 18.0, watchOS 11.0, *) {
            request.resultTypes.insert(.physicalFeature)
            request.regionPriority = .required
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
        } catch {
            return []
        }
    }

    private func bestCandidate(from items: [MKMapItem], for lake: BathingWater) -> ScoredCandidate? {
        let lakeLocation = lake.location
        let lakeName = canonicalBaseName(from: lake.name)
        var seen: Set<String> = []
        var best: ScoredCandidate?

        for item in items {
            guard let mapName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !mapName.isEmpty else {
                continue
            }

            let coordinate = item.placemark.coordinate
            let key = "\(normalize(mapName))|\(Int(coordinate.latitude * 10_000))|\(Int(coordinate.longitude * 10_000))"
            guard seen.insert(key).inserted else { continue }

            let mapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distanceKm = mapLocation.distance(from: lakeLocation) / 1_000
            guard distanceKm <= 32 else { continue }

            let nameStrength = nameMatchStrength(lakeName: lakeName, candidateName: mapName)
            guard nameStrength >= 2 else { continue }

            let metadataBonus = (item.url != nil || item.phoneNumber != nil) ? 16 : 0
            let score = (nameStrength * 100) + metadataBonus - Int(distanceKm * 2.4)
            let candidate = ScoredCandidate(item: item, distanceKm: distanceKm, nameStrength: nameStrength, score: score)

            if let currentBest = best {
                if candidate.score > currentBest.score {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        guard let best else { return nil }
        let strictEnough =
            (best.nameStrength >= 4 && best.distanceKm <= 20) ||
            (best.nameStrength >= 3 && best.distanceKm <= 10)
        return strictEnough ? best : nil
    }

    private func queryCandidates(for lake: BathingWater) -> [String] {
        let fullName = lake.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = canonicalBaseName(from: fullName)
        var seen: Set<String> = []
        var result: [String] = []

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard seen.insert(trimmed).inserted else { return }
            result.append(trimmed)
        }

        add(fullName)
        add(baseName)

        let lower = baseName.lowercased()
        if lower.hasSuffix("see"), !lower.hasSuffix(" see") {
            let prefix = String(baseName.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty {
                add("\(prefix) See")
            }
        }

        if let municipality = lake.municipality, !municipality.isEmpty {
            add("\(baseName) \(municipality)")
        }

        return result
    }

    private func nameMatchStrength(lakeName: String, candidateName: String) -> Int {
        let normalizedLake = normalize(lakeName)
        let normalizedCandidate = normalize(candidateName)
        guard !normalizedLake.isEmpty, !normalizedCandidate.isEmpty else { return 0 }

        if normalizedLake == normalizedCandidate { return 5 }
        if normalizedCandidate.hasPrefix(normalizedLake) || normalizedLake.hasPrefix(normalizedCandidate) {
            return 4
        }
        if normalizedCandidate.contains(normalizedLake) || normalizedLake.contains(normalizedCandidate) {
            return 3
        }

        let lakeTokens = tokenSet(from: normalizedLake)
        let candidateTokens = tokenSet(from: normalizedCandidate)
        let overlap = lakeTokens.intersection(candidateTokens)
        if overlap.count >= 2 { return 3 }
        if overlap.count == 1, let first = overlap.first, first.count >= 5 { return 2 }
        return 0
    }

    private func canonicalBaseName(from value: String) -> String {
        guard let first = value.split(separator: ",", maxSplits: 1).first else { return value }
        return String(first).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenSet(from normalizedValue: String) -> Set<String> {
        Set(
            normalizedValue
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 3 }
        )
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_AT"))
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
