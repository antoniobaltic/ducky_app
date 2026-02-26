import Foundation

// MARK: - Swim Score

/// Composite score (1–10) that factors weather, water temperature, and water quality
/// to give users a single "should I swim today?" indicator.
struct SwimScore {
    let total: Double          // 1.0 – 10.0
    let weatherScore: Double   // 0.0 – 10.0
    let waterTempScore: Double? // nil when no current water temp
    let qualityScore: Double   // 0.0 – 10.0
    let level: Level

    // MARK: - Score Levels

    enum Level: String, CaseIterable {
        case perfekt      // 8.0 – 10.0
        case gut          // 6.0 – 7.9
        case mittel       // 4.0 – 5.9
        case schlecht     // 2.0 – 3.9
        case warnung      // 0.0 – 1.9 (or forced by closure/poor quality)

        var label: String {
            switch self {
            case .perfekt:  return "Perfekt"
            case .gut:      return "Gut"
            case .mittel:   return "Mittelmäßig"
            case .schlecht: return "Schlecht"
            case .warnung:  return "Warnung"
            }
        }

        var emoji: String {
            switch self {
            case .perfekt:  return "🤩"
            case .gut:      return "😊"
            case .mittel:   return "🤔"
            case .schlecht: return "😕"
            case .warnung:  return "⚠️"
            }
        }
    }

    // MARK: - DuckState Mapping

    var duckState: DuckState {
        switch level {
        case .perfekt:  return .begeistert
        case .gut:      return .zufrieden
        case .mittel:   return .zoegernd
        case .schlecht: return .frierend
        case .warnung:  return .warnend
        }
    }

    /// Whether water temperature was included in the score
    var hasWaterTemp: Bool { waterTempScore != nil }

    /// Label that adapts to data availability
    var scoreLabel: String {
        hasWaterTemp ? "Swim Score" : "Wetter-Score"
    }

    // MARK: - Factory

    /// Compute the composite swim score from available data.
    ///
    /// Weights when all data available: weather 40%, water temp 35%, quality 25%
    /// Weights when no water temp:      weather 65%, quality 35%
    static func compute(
        weather: LakeWeather?,
        waterTemp: Double?,         // nil = no current measurement
        qualityRating: String?,
        isClosed: Bool
    ) -> SwimScore {
        // Forced warning for closed or poor-quality lakes
        if isClosed {
            return SwimScore(
                total: 1.0,
                weatherScore: weatherSubScore(weather),
                waterTempScore: waterTemp.map { waterTempSubScore($0) },
                qualityScore: 0,
                level: .warnung
            )
        }

        if let rating = qualityRating?.uppercased(),
           rating == "M" || rating.contains("MANGELHAFT") || rating.contains("POOR") {
            return SwimScore(
                total: 1.5,
                weatherScore: weatherSubScore(weather),
                waterTempScore: waterTemp.map { waterTempSubScore($0) },
                qualityScore: 1.0,
                level: .warnung
            )
        }

        let wScore = weatherSubScore(weather)
        let qScore = qualitySubScore(qualityRating)

        let total: Double
        if let waterTemp {
            let wtScore = waterTempSubScore(waterTemp)
            // All data: weather 40%, water 35%, quality 25%
            total = wScore * 0.40 + wtScore * 0.35 + qScore * 0.25
            return SwimScore(
                total: clamp(total),
                weatherScore: wScore,
                waterTempScore: wtScore,
                qualityScore: qScore,
                level: level(for: clamp(total))
            )
        } else {
            // No water temp: weather 65%, quality 35%
            total = wScore * 0.65 + qScore * 0.35
            return SwimScore(
                total: clamp(total),
                weatherScore: wScore,
                waterTempScore: nil,
                qualityScore: qScore,
                level: level(for: clamp(total))
            )
        }
    }

    // MARK: - Sub-Score Calculations

    /// Weather sub-score (0–10) based on air temp, feels-like, UV, wind, precip, conditions
    private static func weatherSubScore(_ weather: LakeWeather?) -> Double {
        guard let w = weather else { return 5.0 } // neutral fallback

        var score = 0.0

        // Air temperature component (0–10): optimal 24–28°C
        if let airTemp = w.airTemperature {
            if airTemp >= 24 && airTemp <= 28 {
                score += 10.0
            } else if airTemp > 28 {
                score += max(5.0, 10.0 - (airTemp - 28) * 0.8)
            } else if airTemp >= 20 {
                score += 7.0 + (airTemp - 20) * 0.75
            } else if airTemp >= 15 {
                score += 3.0 + (airTemp - 15) * 0.8
            } else if airTemp >= 10 {
                score += 1.0 + (airTemp - 10) * 0.4
            } else {
                score += max(0, 1.0 + airTemp * 0.1)
            }
        } else {
            score += 5.0 // neutral
        }

        // Feels-like adjustment (-1 to +0.5)
        if let feelsLike = w.feelsLike, let airTemp = w.airTemperature {
            let diff = feelsLike - airTemp
            if diff < -3 {
                score -= 1.0  // feels much colder
            } else if diff < -1 {
                score -= 0.5
            } else if diff > 2 {
                score += 0.5  // feels warmer than actual
            }
        }

        // UV adjustment (-0.5 to +0.5)
        if let uv = w.uvIndex {
            if uv >= 3 && uv <= 6 {
                score += 0.5  // pleasant sun
            } else if uv > 8 {
                score -= 0.5  // dangerous UV
            }
        }

        // Wind speed adjustment (-1.5 to 0)
        if let wind = w.windSpeed {
            if wind > 30 {
                score -= 1.5  // very windy
            } else if wind > 20 {
                score -= 1.0
            } else if wind > 10 {
                score -= 0.3
            }
        }

        // Precipitation probability adjustment (-2 to 0)
        if let precip = w.precipitationProbability {
            if precip > 70 {
                score -= 2.0
            } else if precip > 40 {
                score -= 1.0
            } else if precip > 20 {
                score -= 0.3
            }
        }

        // Weather code adjustment (-3 to +0.5)
        score += weatherCodeAdjustment(w.weatherCode)

        return max(0, min(10, score))
    }

    /// Adjustment based on WMO weather code
    private static func weatherCodeAdjustment(_ code: Int?) -> Double {
        guard let code else { return 0 }
        switch code {
        case 0:                    return 0.5   // clear sky
        case 1:                    return 0.3   // mainly clear
        case 2:                    return 0.0   // partly cloudy
        case 3:                    return -0.3  // overcast
        case 45, 48:               return -1.0  // fog
        case 51, 53, 55:           return -1.5  // drizzle
        case 61, 63, 65:           return -2.5  // rain
        case 80, 81, 82:           return -2.0  // rain showers
        case 71, 73, 75, 77:       return -3.0  // snow
        case 85, 86:               return -3.0  // snow showers
        case 95, 96, 99:           return -3.0  // thunderstorm
        case 56, 57, 66, 67:       return -3.0  // freezing precip
        default:                   return 0
        }
    }

    /// Water temperature sub-score (0–10): optimal 20–24°C
    private static func waterTempSubScore(_ temp: Double) -> Double {
        if temp >= 20 && temp <= 24 {
            return 10.0
        } else if temp > 24 && temp <= 28 {
            return 10.0 - (temp - 24) * 0.5  // 8–10
        } else if temp > 28 {
            return max(5.0, 8.0 - (temp - 28) * 0.5)
        } else if temp >= 18 {
            return 7.0 + (temp - 18) * 1.5   // 7–10
        } else if temp >= 14 {
            return 3.0 + (temp - 14) * 1.0   // 3–7
        } else if temp >= 10 {
            return 1.0 + (temp - 10) * 0.5   // 1–3
        } else {
            return max(0, temp * 0.1)
        }
    }

    /// Quality sub-score (0–10) based on EU bathing water quality classification
    private static func qualitySubScore(_ rating: String?) -> Double {
        guard let rating = rating?.uppercased(), !rating.isEmpty else { return 5.0 } // unknown → neutral
        switch rating {
        case "A":  return 10.0  // Ausgezeichnet
        case "G":  return 7.0   // Gut
        case "AU": return 4.0   // Ausreichend
        case "M":  return 1.0   // Mangelhaft (handled above as warnung, but just in case)
        default:
            let r = rating.lowercased()
            if r.contains("ausgezeichnet") || r.contains("excellent") { return 10.0 }
            if r.contains("gut") || r.contains("good") { return 7.0 }
            if r.contains("ausreichend") || r.contains("sufficient") { return 4.0 }
            if r.contains("mangelhaft") || r.contains("poor") { return 1.0 }
            return 5.0 // unknown
        }
    }

    // MARK: - Helpers

    private static func level(for score: Double) -> Level {
        switch score {
        case 8.0...10.0: return .perfekt
        case 6.0..<8.0:  return .gut
        case 4.0..<6.0:  return .mittel
        case 2.0..<4.0:  return .schlecht
        default:          return .warnung
        }
    }

    private static func clamp(_ value: Double) -> Double {
        max(1.0, min(10.0, value))
    }
}
