import Foundation
import CoreLocation
import Observation

struct LakeWeather {
    let airTemperature: Double?
    let uvIndex: Int?
    let conditionSymbol: String
    let conditionDescription: String
    let feelsLike: Double?
}

@Observable
final class WeatherService {
    var weatherCache: [String: LakeWeather] = [:]

    static let shared = WeatherService()
    private init() {}

    func fetchWeather(for lake: BathingWater) async -> LakeWeather? {
        let cacheKey = lake.id
        if let cached = weatherCache[cacheKey] { return cached }

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lake.latitude)&longitude=\(lake.longitude)&current=temperature_2m,apparent_temperature,weather_code,uv_index&timezone=auto"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any] else { return nil }

            let airTemp = current["temperature_2m"] as? Double
            let feelsLike = current["apparent_temperature"] as? Double
            let weatherCode = (current["weather_code"] as? Int) ?? (current["weather_code"] as? Double).map(Int.init) ?? 0
            let uvDouble = current["uv_index"] as? Double

            let weather = LakeWeather(
                airTemperature: airTemp,
                uvIndex: uvDouble.map { Int($0.rounded()) },
                conditionSymbol: symbolForWMOCode(weatherCode),
                conditionDescription: descriptionForWMOCode(weatherCode),
                feelsLike: feelsLike
            )

            weatherCache[cacheKey] = weather
            return weather
        } catch {
            return nil
        }
    }

    // MARK: - WMO Weather Code Mapping

    private func symbolForWMOCode(_ code: Int) -> String {
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

    private func descriptionForWMOCode(_ code: Int) -> String {
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
