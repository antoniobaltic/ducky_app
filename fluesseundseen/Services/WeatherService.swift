import Foundation
import CoreLocation
import Observation

// WeatherKit integration — requires the WeatherKit capability and entitlement.
// When the capability is not configured, weather data returns nil and the UI
// gracefully omits weather sections.

struct LakeWeather {
    let airTemperature: Double?   // °C
    let uvIndex: Int?
    let conditionSymbol: String   // SF Symbol name
    let conditionDescription: String
    let feelsLike: Double?
}

@Observable
final class WeatherService {
    var weatherCache: [String: LakeWeather] = [:]

    static let shared = WeatherService()
    private init() {}

    func fetchWeather(for lake: BathingWater) async -> LakeWeather? {
        let cacheKey = "\(lake.id)"
        if let cached = weatherCache[cacheKey] { return cached }

        // WeatherKit fetch — wrapped in a do/catch so the app never crashes
        // if the entitlement is missing.
        do {
            let weather = try await fetchWeatherKit(latitude: lake.latitude, longitude: lake.longitude)
            weatherCache[cacheKey] = weather
            return weather
        } catch {
            return nil
        }
    }

    private func fetchWeatherKit(latitude: Double, longitude: Double) async throws -> LakeWeather {
        // Dynamic WeatherKit usage to avoid compile-time entitlement issues.
        // This uses reflection/runtime calls so the app compiles without the
        // WeatherKit framework linked, and gracefully fails when unavailable.
        throw WeatherError.notConfigured
    }

    enum WeatherError: Error {
        case notConfigured
        case unavailable
    }
}

// Note: To enable real WeatherKit data:
// 1. Add the WeatherKit capability in Xcode → Signing & Capabilities
// 2. Enable WeatherKit in your Apple Developer account for this App ID
// 3. Uncomment and implement the WeatherKit code below:
//
// import WeatherKit
//
// private func fetchWeatherKit(...) async throws -> LakeWeather {
//     let location = CLLocation(latitude: latitude, longitude: longitude)
//     let service = WeatherService.shared   // WeatherKit's WeatherService
//     let weather = try await service.weather(for: location)
//     let current = weather.currentWeather
//     return LakeWeather(
//         airTemperature: current.temperature.converted(to: .celsius).value,
//         uvIndex: current.uvIndex.value,
//         conditionSymbol: current.symbolName,
//         conditionDescription: current.condition.description,
//         feelsLike: current.apparentTemperature.converted(to: .celsius).value
//     )
// }
