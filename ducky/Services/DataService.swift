import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class DataService {
    var lakes: [BathingWater] = [] {
        didSet { _cachedAvailableStates = nil }
    }
    var isLoading = false
    var error: String?
    var lastFetch: Date?
    var cacheTimestamp: Date?

    var lastUpdated: Date? {
        [lastFetch, cacheTimestamp].compactMap { $0 }.max()
    }

    /// Cached result of availableStates — invalidated whenever `lakes` changes.
    @ObservationIgnored
    private var _cachedAvailableStates: [String]? = nil

    /// Preview-only guard so design-time fixtures never trigger real app loading logic.
    @ObservationIgnored
    var isPreviewStubbed = false

    /// All unique states from the loaded data (O(1) on repeat access).
    var availableStates: [String] {
        if let cached = _cachedAvailableStates { return cached }
        let result = Array(Set(lakes.compactMap(\.state))).sorted()
        _cachedAvailableStates = result
        return result
    }

    private let cacheExpirySeconds: TimeInterval = 24 * 60 * 60
    private let apiURL = URL(string: "https://www.ages.at/typo3temp/badegewaesser_db.json")!

    static let shared = DataService()

    static func previewInstance() -> DataService {
        DataService()
    }

    private init() {
        // Clean up legacy UserDefaults cache entries to free space
        UserDefaults.standard.removeObject(forKey: "cached_badegewaesser")
        UserDefaults.standard.removeObject(forKey: "cached_badegewaesser_timestamp")
        cacheTimestamp = Self.readCacheTimestamp()
    }

    // MARK: - Public

    func loadData() async {
        guard !isPreviewStubbed else { return }

        if let cached = await loadFromCache() {
            lakes = cached
            if lastFetch == nil {
                lastFetch = cacheTimestamp
            }
            return
        }
        await fetchFromNetwork()
    }

    func refresh() async {
        guard !isPreviewStubbed else { return }
        await fetchFromNetwork()
    }

    func clearCache() {
        try? FileManager.default.removeItem(at: Self.cacheDataURL)
        try? FileManager.default.removeItem(at: Self.cacheTimestampURL)
        cacheTimestamp = nil
        lastFetch = nil
    }

    // MARK: - Network

    private func fetchFromNetwork() async {
        isLoading = true; error = nil

        do {
            var request = URLRequest(url: apiURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            // Parse off the main thread
            let parsed = try await Self.parseAsync(data: data)

            lakes = parsed
            lastFetch = Date()
            cacheTimestamp = lastFetch
            isLoading = false
            await saveToCacheAsync(data: data)
        } catch {
            if let cached = await loadFromCache(ignoreExpiry: true) {
                lakes = cached
                isLoading = false
                self.error = "Daten könnten veraltet sein."
            } else {
                self.error = "Keine Verbindung möglich."
                isLoading = false
            }
        }
    }

    // MARK: - Async Parsing (off MainActor via @concurrent)

    @concurrent
    nonisolated private static func parseAsync(data: Data) async throws -> [BathingWater] {
        try Self.parse(data: data)
    }

    // MARK: - Parsing (AGES nested format)

    nonisolated private static func parse(data: Data) throws -> [BathingWater] {
        let json = try JSONSerialization.jsonObject(with: data)

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

    // MARK: - File-based Cache (avoids storing large JSON in UserDefaults)

    private func saveToCacheAsync(data: Data) async {
        let timestamp = "\(Date().timeIntervalSinceReferenceDate)"
        await Self.writeCacheFiles(data: data, dataURL: Self.cacheDataURL, tsURL: Self.cacheTimestampURL, timestamp: timestamp)
    }

    @concurrent
    nonisolated private static func writeCacheFiles(data: Data, dataURL: URL, tsURL: URL, timestamp: String) async {
        try? data.write(to: dataURL, options: .atomic)
        try? timestamp.data(using: .utf8)?.write(to: tsURL, options: .atomic)
    }

    private func loadFromCache(ignoreExpiry: Bool = false) async -> [BathingWater]? {
        if !ignoreExpiry {
            guard let tsData = try? Data(contentsOf: Self.cacheTimestampURL),
                  let tsStr = String(data: tsData, encoding: .utf8),
                  let timestamp = Double(tsStr)
            else { return nil }
            let cacheDate = Date(timeIntervalSinceReferenceDate: timestamp)
            cacheTimestamp = cacheDate
            let age = Date().timeIntervalSinceReferenceDate - timestamp
            guard age < cacheExpirySeconds else { return nil }
        } else {
            let cacheDate = Self.readCacheTimestamp()
            cacheTimestamp = cacheDate
        }

        let dataURL = Self.cacheDataURL
        guard (try? dataURL.checkResourceIsReachable()) == true else { return nil }

        return try? await Self.readAndParseCache(dataURL: dataURL)
    }

    @concurrent
    nonisolated private static func readAndParseCache(dataURL: URL) async throws -> [BathingWater] {
        let data = try Data(contentsOf: dataURL)
        return try Self.parse(data: data)
    }

    private static var cacheDataURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("badegewaesser_cache.json")
    }

    private static var cacheTimestampURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("badegewaesser_cache_ts.txt")
    }

    private static func readCacheTimestamp() -> Date? {
        guard let tsData = try? Data(contentsOf: cacheTimestampURL),
              let tsStr = String(data: tsData, encoding: .utf8),
              let timestamp = Double(tsStr)
        else { return nil }
        return Date(timeIntervalSinceReferenceDate: timestamp)
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

    func sortedByScore(weatherService: WeatherService) -> [BathingWater] {
        lakes.sorted { a, b in
            let scoreA = a.swimScore(weather: weatherService.weatherCache[a.id]).total
            let scoreB = b.swimScore(weather: weatherService.weatherCache[b.id]).total
            return scoreA > scoreB
        }
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
