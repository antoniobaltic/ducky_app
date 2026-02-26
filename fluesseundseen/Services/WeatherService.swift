import Foundation
import CoreLocation
import Observation

struct LakeWeather {
    let airTemperature: Double?
    let uvIndex: Int?
    let conditionSymbol: String
    let conditionDescription: String
    let feelsLike: Double?
    let windSpeed: Double?               // km/h
    let precipitationProbability: Int?   // 0–100%
    let weatherCode: Int?                // WMO code
}

// @MainActor ensures all cache reads/writes are serialized on the main thread,
// preventing dictionary race conditions from concurrent task group fetches.
@MainActor
@Observable
final class WeatherService {
    var weatherCache: [String: LakeWeather] = [:]

    static let shared = WeatherService()
    private let cacheTTL: TimeInterval = 30 * 60 // 30 minutes

    private var saveCacheTask: Task<Void, Never>?

    private init() {
        // Clean up legacy UserDefaults cache entries
        UserDefaults.standard.removeObject(forKey: "weatherCache_v2")
        UserDefaults.standard.removeObject(forKey: "weatherCache_v2_timestamp")
        loadDiskCache()
    }

    // MARK: - Public API

    /// Fetch weather for a single lake. Cache-first; network only if missing.
    func fetchWeather(for lake: BathingWater) async -> LakeWeather? {
        if let cached = weatherCache[lake.id] { return cached }

        // networkFetch is nonisolated (static), so it runs off the MainActor
        // while this function suspends here — MainActor stays free.
        guard let weather = await Self.networkFetch(for: lake) else { return nil }
        weatherCache[lake.id] = weather
        scheduleSave()
        return weather
    }

    /// Prefetch weather for multiple lakes with at most 10 concurrent network requests.
    /// Results are written to cache in a single batch after all fetches complete.
    func prefetchWeather(for lakes: [BathingWater]) async {
        let toFetch = lakes.filter { weatherCache[$0.id] == nil }
        guard !toFetch.isEmpty else { return }

        // All network work happens off-MainActor (static nonisolated func).
        // TaskGroup collects results, then we write to cache once on MainActor.
        let results = await withTaskGroup(of: (String, LakeWeather?).self) { group in
            var pending = toFetch.makeIterator()
            var active = 0
            let maxConcurrent = 10

            // Seed initial batch
            while active < maxConcurrent, let lake = pending.next() {
                group.addTask { await (lake.id, Self.networkFetch(for: lake)) }
                active += 1
            }

            var collected: [(String, LakeWeather?)] = []
            for await result in group {
                collected.append(result)
                // Feed next item as a slot opens up
                if let next = pending.next() {
                    group.addTask { await (next.id, Self.networkFetch(for: next)) }
                }
            }
            return collected
        }

        for (id, weather) in results {
            if let weather { weatherCache[id] = weather }
        }
        scheduleSave()
    }

    // MARK: - Nonisolated Network Fetch

    /// Static so it's nonisolated and can run truly off the MainActor in task groups.
    private static func networkFetch(for lake: BathingWater) async -> LakeWeather? {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lake.latitude)&longitude=\(lake.longitude)&current=temperature_2m,apparent_temperature,weather_code,uv_index,wind_speed_10m,precipitation&timezone=auto"
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

            return LakeWeather(
                airTemperature: airTemp,
                uvIndex: uvDouble.map { Int($0.rounded()) },
                conditionSymbol: symbolForWMOCode(weatherCode),
                conditionDescription: descriptionForWMOCode(weatherCode),
                feelsLike: feelsLike,
                windSpeed: windSpeed,
                precipitationProbability: precipitation.map { $0 > 0 ? 80 : 0 },
                weatherCode: weatherCode
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
            serializable[key] = dict
        }
        let payload: [String: Any] = [
            "timestamp": Date().timeIntervalSinceReferenceDate,
            "data": serializable
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: Self.cacheFileURL, options: .atomic)
        }
    }

    private func loadDiskCache() {
        guard let data = try? Data(contentsOf: Self.cacheFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let timestamp = json["timestamp"] as? Double,
              let dict = json["data"] as? [String: [String: Any]]
        else { return }

        let age = Date().timeIntervalSinceReferenceDate - timestamp
        guard age < cacheTTL else { return }

        for (key, d) in dict {
            weatherCache[key] = LakeWeather(
                airTemperature: d["airTemp"] as? Double,
                uvIndex: d["uv"] as? Int,
                conditionSymbol: d["symbol"] as? String ?? "cloud.fill",
                conditionDescription: d["desc"] as? String ?? "Unbekannt",
                feelsLike: d["feelsLike"] as? Double,
                windSpeed: d["windSpeed"] as? Double,
                precipitationProbability: d["precip"] as? Int,
                weatherCode: d["weatherCode"] as? Int
            )
        }
    }

    private static var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("weather_cache_v3.json")
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
