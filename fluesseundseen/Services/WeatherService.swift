import Foundation
import CoreLocation
import Observation

struct ForecastDay {
    let date: String              // "2026-02-27"
    let weatherCode: Int
    let conditionSymbol: String
    let conditionDescription: String
    let tempMax: Double
    let tempMin: Double
}

struct LakeWeather {
    let airTemperature: Double?
    let uvIndex: Int?
    let conditionSymbol: String
    let conditionDescription: String
    let feelsLike: Double?
    let windSpeed: Double?               // km/h
    let precipitationProbability: Int?   // 0–100%
    let weatherCode: Int?                // WMO code
    let forecast: [ForecastDay]          // up to 5 days starting today

    init(
        airTemperature: Double? = nil,
        uvIndex: Int? = nil,
        conditionSymbol: String,
        conditionDescription: String,
        feelsLike: Double? = nil,
        windSpeed: Double? = nil,
        precipitationProbability: Int? = nil,
        weatherCode: Int? = nil,
        forecast: [ForecastDay] = []
    ) {
        self.airTemperature = airTemperature
        self.uvIndex = uvIndex
        self.conditionSymbol = conditionSymbol
        self.conditionDescription = conditionDescription
        self.feelsLike = feelsLike
        self.windSpeed = windSpeed
        self.precipitationProbability = precipitationProbability
        self.weatherCode = weatherCode
        self.forecast = forecast
    }
}

// @MainActor ensures all cache reads/writes are serialized on the main thread,
// preventing dictionary race conditions from concurrent task group fetches.
@MainActor
@Observable
final class WeatherService {
    var weatherCache: [String: LakeWeather] = [:]
    var cacheRevision = 0
    var hydrationTotal = 0
    var hydrationCompleted = 0
    var isHydratingAll = false
    var isUsingStaleCache = false
    var lastCacheUpdate: Date? { cacheTimestamp }

    static let shared = WeatherService()
    private let cacheTTL: TimeInterval = 30 * 60 // 30 minutes
    private let maxConcurrentFetches = 24
    private let maxHydrationAttempts = 3

    private var saveCacheTask: Task<Void, Never>?
    private var hydrationTask: Task<Void, Never>?
    private var inFlightFetches: [String: Task<LakeWeather?, Never>] = [:]
    private var cacheTimestamp: Date?

    var hydrationProgress: Double {
        guard hydrationTotal > 0 else { return 0 }
        return Double(hydrationCompleted) / Double(hydrationTotal)
    }

    var isCacheFresh: Bool {
        guard let cacheTimestamp else { return false }
        return Date().timeIntervalSince(cacheTimestamp) < cacheTTL
    }

    private init() {
        // Clean up legacy cache entries
        UserDefaults.standard.removeObject(forKey: "weatherCache_v2")
        UserDefaults.standard.removeObject(forKey: "weatherCache_v2_timestamp")
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: caches.appendingPathComponent("weather_cache_v3.json"))
        loadDiskCache()
    }

    // MARK: - Public API

    func hasCompleteWeather(for lakes: [BathingWater]) -> Bool {
        let unique = uniqueLakes(lakes)
        guard !unique.isEmpty else { return true }
        return unique.allSatisfy { weatherCache[$0.id] != nil }
    }

    /// Startup strategy:
    /// - If complete cache exists, allow instant score ranking.
    /// - If cache is stale, refresh in background without blocking launch.
    /// - If incomplete, block once and fetch missing weather for all lakes.
    func bootstrapWeather(for lakes: [BathingWater]) async {
        let unique = uniqueLakes(lakes)
        guard !unique.isEmpty else {
            hydrationTotal = 0
            hydrationCompleted = 0
            return
        }

        hydrationTotal = unique.count
        hydrationCompleted = unique.filter { weatherCache[$0.id] != nil }.count

        if hasCompleteWeather(for: unique) {
            if !isCacheFresh {
                isUsingStaleCache = true
                refreshAllWeatherInBackground(for: unique)
            } else {
                isUsingStaleCache = false
            }
            return
        }

        await hydrateAllWeather(for: unique, forceRefresh: false)
        isUsingStaleCache = !isCacheFresh
    }

    /// Background full refresh for existing complete caches.
    func refreshAllWeatherInBackground(for lakes: [BathingWater]) {
        let unique = uniqueLakes(lakes)
        guard !unique.isEmpty else { return }
        guard hydrationTask == nil else { return }
        Task { await hydrateAllWeather(for: unique, forceRefresh: true) }
    }

    /// Ensure all requested lakes have weather. Used by startup flow.
    func hydrateAllWeather(for lakes: [BathingWater], forceRefresh: Bool) async {
        if let running = hydrationTask {
            await running.value
            return
        }

        let unique = uniqueLakes(lakes)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runHydration(for: unique, forceRefresh: forceRefresh)
        }
        hydrationTask = task
        await task.value
        hydrationTask = nil
    }

    /// Fetch weather for a single lake. Cache-first by default, deduped by in-flight tasks.
    func fetchWeather(for lake: BathingWater, forceRefresh: Bool = false) async -> LakeWeather? {
        if !forceRefresh, let cached = weatherCache[lake.id] { return cached }
        if let inFlight = inFlightFetches[lake.id] { return await inFlight.value }

        let task = Task { await Self.networkFetch(for: lake) }
        inFlightFetches[lake.id] = task
        defer { inFlightFetches[lake.id] = nil }

        guard let weather = await task.value else { return nil }
        weatherCache[lake.id] = weather
        cacheRevision &+= 1
        scheduleSave()
        return weather
    }

    /// Prefetch weather for multiple lakes with at most 10 concurrent network requests.
    /// Results are written to cache in a single batch after all fetches complete.
    func prefetchWeather(for lakes: [BathingWater]) async {
        await runHydration(for: uniqueLakes(lakes), forceRefresh: false, showProgress: false)
    }

    func clearCache() {
        saveCacheTask?.cancel()
        saveCacheTask = nil
        hydrationTask?.cancel()
        hydrationTask = nil
        inFlightFetches.removeAll()

        weatherCache.removeAll()
        cacheTimestamp = nil
        hydrationTotal = 0
        hydrationCompleted = 0
        isHydratingAll = false
        isUsingStaleCache = false
        cacheRevision &+= 1

        try? FileManager.default.removeItem(at: Self.cacheFileURL)
    }

    private func runHydration(
        for lakes: [BathingWater],
        forceRefresh: Bool,
        showProgress: Bool = true
    ) async {
        guard !lakes.isEmpty else { return }

        let toFetch = forceRefresh ? lakes : lakes.filter { weatherCache[$0.id] == nil }
        if showProgress {
            hydrationTotal = lakes.count
            hydrationCompleted = lakes.count - toFetch.count
            isHydratingAll = !toFetch.isEmpty
        }

        guard !toFetch.isEmpty else {
            if showProgress { isHydratingAll = false }
            if forceRefresh { scheduleSave() }
            isUsingStaleCache = !isCacheFresh
            return
        }

        var remaining = toFetch
        for attempt in 1...maxHydrationAttempts {
            guard !remaining.isEmpty else { break }

            await fetchBatchWeather(for: remaining, forceRefresh: forceRefresh)
            remaining = remaining.filter { weatherCache[$0.id] == nil }

            if showProgress {
                hydrationCompleted = lakes.count - remaining.count
            }

            // Auto-retry transient failures (timeouts/rate limits) before showing manual retry.
            if !remaining.isEmpty && attempt < maxHydrationAttempts {
                try? await Task.sleep(for: .milliseconds(350 * attempt))
            }
        }

        if showProgress {
            hydrationCompleted = lakes.filter { weatherCache[$0.id] != nil }.count
            isHydratingAll = false
        }
        isUsingStaleCache = !isCacheFresh
        scheduleSave()
    }

    private func fetchBatchWeather(for lakes: [BathingWater], forceRefresh: Bool) async {
        guard !lakes.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            var pending = lakes.makeIterator()
            let initial = min(maxConcurrentFetches, lakes.count)

            for _ in 0..<initial {
                if let lake = pending.next() {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        _ = await self.fetchWeather(for: lake, forceRefresh: forceRefresh)
                    }
                }
            }

            while await group.next() != nil {
                if let next = pending.next() {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        _ = await self.fetchWeather(for: next, forceRefresh: forceRefresh)
                    }
                }
            }
        }
    }

    private func uniqueLakes(_ lakes: [BathingWater]) -> [BathingWater] {
        var seen: Set<String> = []
        var result: [BathingWater] = []
        result.reserveCapacity(lakes.count)

        for lake in lakes where !seen.contains(lake.id) {
            seen.insert(lake.id)
            result.append(lake)
        }
        return result
    }

    // MARK: - Nonisolated Network Fetch

    /// Static so it's nonisolated and can run truly off the MainActor in task groups.
    private static func networkFetch(for lake: BathingWater) async -> LakeWeather? {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lake.latitude)&longitude=\(lake.longitude)&current=temperature_2m,apparent_temperature,weather_code,uv_index,wind_speed_10m,precipitation&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5&timezone=auto"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any] else { return nil }

            let airTemp = current["temperature_2m"] as? Double
            let feelsLike = current["apparent_temperature"] as? Double
            let weatherCode = (current["weather_code"] as? Int)
                ?? (current["weather_code"] as? Double).map(Int.init)
                ?? 0
            let uvDouble = current["uv_index"] as? Double
            let windSpeed = current["wind_speed_10m"] as? Double
            let precipitation = current["precipitation"] as? Double

            // Parse 5-day daily forecast
            var forecastDays: [ForecastDay] = []
            if let daily = json["daily"] as? [String: Any],
               let times = daily["time"] as? [String] {
                let codes = (daily["weather_code"] as? [Int])
                    ?? (daily["weather_code"] as? [Double])?.map(Int.init)
                    ?? []
                let maxTemps = daily["temperature_2m_max"] as? [Double] ?? []
                let minTemps = daily["temperature_2m_min"] as? [Double] ?? []
                let count = min(times.count, 5)
                for i in 0..<count {
                    let code = i < codes.count ? codes[i] : 0
                    forecastDays.append(ForecastDay(
                        date: times[i],
                        weatherCode: code,
                        conditionSymbol: symbolForWMOCode(code),
                        conditionDescription: descriptionForWMOCode(code),
                        tempMax: i < maxTemps.count ? maxTemps[i] : 0,
                        tempMin: i < minTemps.count ? minTemps[i] : 0
                    ))
                }
            }

            return LakeWeather(
                airTemperature: airTemp,
                uvIndex: uvDouble.map { Int($0.rounded()) },
                conditionSymbol: symbolForWMOCode(weatherCode),
                conditionDescription: descriptionForWMOCode(weatherCode),
                feelsLike: feelsLike,
                windSpeed: windSpeed,
                precipitationProbability: precipitation.map { $0 > 0 ? 80 : 0 },
                weatherCode: weatherCode,
                forecast: forecastDays
            )
        } catch {
            return nil
        }
    }

    // MARK: - Debounced Disk Cache

    /// Schedule a disk save, cancelling any pending one — coalesces rapid cache updates
    /// (e.g. many individual lake weather fetches) into a single write after 3 seconds.
    private func scheduleSave() {
        saveCacheTask?.cancel()
        saveCacheTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.saveDiskCache()
        }
    }

    private func saveDiskCache() {
        let now = Date()
        var serializable: [String: [String: Any]] = [:]
        for (key, w) in weatherCache {
            var dict: [String: Any] = [:]
            if let t = w.airTemperature { dict["airTemp"] = t }
            if let u = w.uvIndex { dict["uv"] = u }
            dict["symbol"] = w.conditionSymbol
            dict["desc"] = w.conditionDescription
            if let f = w.feelsLike { dict["feelsLike"] = f }
            if let ws = w.windSpeed { dict["windSpeed"] = ws }
            if let pp = w.precipitationProbability { dict["precip"] = pp }
            if let wc = w.weatherCode { dict["weatherCode"] = wc }
            if !w.forecast.isEmpty {
                dict["forecast"] = w.forecast.map { day -> [String: Any] in
                    ["date": day.date, "wc": day.weatherCode,
                     "sym": day.conditionSymbol, "fdesc": day.conditionDescription,
                     "max": day.tempMax, "min": day.tempMin]
                }
            }
            serializable[key] = dict
        }
        let payload: [String: Any] = [
            "timestamp": now.timeIntervalSinceReferenceDate,
            "data": serializable
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: Self.cacheFileURL, options: .atomic)
        }
        cacheTimestamp = now
        isUsingStaleCache = false
    }

    private func loadDiskCache() {
        guard let data = try? Data(contentsOf: Self.cacheFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = json["timestamp"] as? Double,
              let dict = json["data"] as? [String: [String: Any]]
        else { return }

        cacheTimestamp = Date(timeIntervalSinceReferenceDate: timestamp)

        for (key, d) in dict {
            var forecastDays: [ForecastDay] = []
            if let fArr = d["forecast"] as? [[String: Any]] {
                forecastDays = fArr.compactMap { f -> ForecastDay? in
                    guard let date = f["date"] as? String,
                          let wc   = f["wc"]   as? Int,
                          let sym  = f["sym"]  as? String,
                          let desc = f["fdesc"] as? String,
                          let max  = f["max"]  as? Double,
                          let min  = f["min"]  as? Double
                    else { return nil }
                    return ForecastDay(date: date, weatherCode: wc,
                                       conditionSymbol: sym, conditionDescription: desc,
                                       tempMax: max, tempMin: min)
                }
            }
            weatherCache[key] = LakeWeather(
                airTemperature: d["airTemp"] as? Double,
                uvIndex: d["uv"] as? Int,
                conditionSymbol: d["symbol"] as? String ?? "cloud.fill",
                conditionDescription: d["desc"] as? String ?? "Unbekannt",
                feelsLike: d["feelsLike"] as? Double,
                windSpeed: d["windSpeed"] as? Double,
                precipitationProbability: d["precip"] as? Int,
                weatherCode: d["weatherCode"] as? Int,
                forecast: forecastDays
            )
        }
        cacheRevision &+= 1
        isUsingStaleCache = !isCacheFresh
    }

    private static var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("weather_cache_v4.json")
    }

    // MARK: - WMO Weather Code Mapping (static for nonisolated access)

    private static func symbolForWMOCode(_ code: Int) -> String {
        switch code {
        case 0:           return "sun.max.fill"
        case 1:           return "sun.min.fill"
        case 2:           return "cloud.sun.fill"
        case 3:           return "cloud.fill"
        case 45, 48:      return "cloud.fog.fill"
        case 51, 53, 55:  return "cloud.drizzle.fill"
        case 56, 57:      return "cloud.sleet.fill"
        case 61, 63, 65:  return "cloud.rain.fill"
        case 66, 67:      return "cloud.sleet.fill"
        case 71, 73, 75:  return "cloud.snow.fill"
        case 77:          return "cloud.snow.fill"
        case 80, 81, 82:  return "cloud.heavyrain.fill"
        case 85, 86:      return "cloud.snow.fill"
        case 95, 96, 99:  return "cloud.bolt.rain.fill"
        default:          return "cloud.fill"
        }
    }

    private static func descriptionForWMOCode(_ code: Int) -> String {
        switch code {
        case 0:           return "Klar"
        case 1:           return "Überwiegend klar"
        case 2:           return "Teilweise bewölkt"
        case 3:           return "Bewölkt"
        case 45, 48:      return "Nebel"
        case 51, 53, 55:  return "Nieselregen"
        case 56, 57:      return "Gefrierender Nieselregen"
        case 61:          return "Leichter Regen"
        case 63:          return "Regen"
        case 65:          return "Starker Regen"
        case 66, 67:      return "Gefrierender Regen"
        case 71:          return "Leichter Schneefall"
        case 73:          return "Schneefall"
        case 75:          return "Starker Schneefall"
        case 77:          return "Schneegriesel"
        case 80, 81, 82:  return "Regenschauer"
        case 85, 86:      return "Schneeschauer"
        case 95:          return "Gewitter"
        case 96, 99:      return "Gewitter mit Hagel"
        default:          return "Unbekannt"
        }
    }
}
