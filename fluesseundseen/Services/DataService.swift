import Foundation
import CoreLocation
import Observation

@Observable
final class DataService {
    var lakes: [BathingWater] = []
    var isLoading = false
    var error: String?
    var lastFetch: Date?

    /// All unique states from the loaded data
    var availableStates: [String] {
        Array(Set(lakes.compactMap(\.state))).sorted()
    }

    private let cacheKey = "cached_badegewaesser"
    private let cacheTimestampKey = "cached_badegewaesser_timestamp"
    private let cacheExpirySeconds: TimeInterval = 24 * 60 * 60
    private let apiURL = URL(string: "https://www.ages.at/typo3temp/badegewaesser_db.json")!

    static let shared = DataService()

    private init() {}

    // MARK: - Public

    func loadData() async {
        if let cached = loadFromCache() {
            lakes = cached
            return
        }
        await fetchFromNetwork()
    }

    func refresh() async {
        await fetchFromNetwork()
    }

    // MARK: - Network

    private func fetchFromNetwork() async {
        await MainActor.run { isLoading = true; error = nil }

        do {
            var request = URLRequest(url: apiURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            let parsed = try parse(data: data)

            await MainActor.run {
                lakes = parsed
                lastFetch = Date()
                isLoading = false
            }
            saveToCache(data: data)
        } catch {
            if let cached = loadFromCache(ignoreExpiry: true) {
                await MainActor.run {
                    lakes = cached
                    isLoading = false
                    self.error = "Daten könnten veraltet sein."
                }
            } else {
                await MainActor.run {
                    self.error = "Keine Verbindung möglich."
                    isLoading = false
                    lakes = BathingWater.previews
                }
            }
        }
    }

    // MARK: - Parsing (AGES nested format)

    private func parse(data: Data) throws -> [BathingWater] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? Any else {
            throw DataError.invalidFormat
        }

        var allEntries: [BathingWater] = []

        if let obj = json as? [String: Any] {
            // AGES format: { BUNDESLAENDER: [{ BUNDESLAND: "...", BADEGEWAESSER: [...] }] }
            if let bundeslaender = obj["BUNDESLAENDER"] as? [[String: Any]] {
                for stateObj in bundeslaender {
                    let stateName = stateObj["BUNDESLAND"] as? String
                    if let badegewaesser = stateObj["BADEGEWAESSER"] as? [[String: Any]] {
                        for entry in badegewaesser {
                            if let bw = BathingWater.decode(from: entry, state: stateName) {
                                allEntries.append(bw)
                            }
                        }
                    }
                }
            } else {
                // Fallback: try common wrapper keys
                let wrapperKeys = ["badegewaesser", "data", "features", "items", "results"]
                var found: [[String: Any]]?
                for key in wrapperKeys {
                    if let arr = obj[key] as? [[String: Any]] {
                        found = arr
                        break
                    }
                }
                if let arr = found {
                    allEntries = arr.compactMap { BathingWater.decode(from: $0) }
                }
            }
        } else if let arr = json as? [[String: Any]] {
            allEntries = arr.compactMap { BathingWater.decode(from: $0) }
        }

        guard !allEntries.isEmpty else { throw DataError.emptyResponse }
        return allEntries
    }

    // MARK: - Cache

    private func saveToCache(data: Data) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate, forKey: cacheTimestampKey)
    }

    private func loadFromCache(ignoreExpiry: Bool = false) -> [BathingWater]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }

        if !ignoreExpiry {
            let timestamp = UserDefaults.standard.double(forKey: cacheTimestampKey)
            let age = Date().timeIntervalSinceReferenceDate - timestamp
            guard age < cacheExpirySeconds else { return nil }
        }

        return try? parse(data: data)
    }

    enum DataError: Error {
        case invalidFormat
        case emptyResponse
    }
}

// MARK: - Filtering & Sorting

extension DataService {
    func sortedByDistance(from userLocation: CLLocation?) -> [BathingWater] {
        guard let loc = userLocation else { return lakes }
        return lakes.sorted { $0.distance(from: loc) < $1.distance(from: loc) }
    }

    func sortedByTemperature() -> [BathingWater] {
        lakes
            .filter { $0.waterTemperature != nil }
            .sorted { ($0.waterTemperature ?? 0) > ($1.waterTemperature ?? 0) }
    }

    func filtered(by state: String?) -> [BathingWater] {
        guard let state else { return lakes }
        return lakes.filter { $0.state == state }
    }

    func search(_ query: String) -> [BathingWater] {
        guard !query.isEmpty else { return lakes }
        let lowered = query.lowercased()
        return lakes.filter {
            $0.name.lowercased().contains(lowered) ||
            ($0.municipality?.lowercased().contains(lowered) ?? false) ||
            ($0.state?.lowercased().contains(lowered) ?? false)
        }
    }

    func lake(withID id: String) -> BathingWater? {
        lakes.first { $0.id == id }
    }
}
