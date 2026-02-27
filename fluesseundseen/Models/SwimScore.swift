import Foundation

// MARK: - Swim Score

/// Composite score (0–10) that factors weather, water temperature, and water quality
/// to give users a single "should I swim today?" indicator.
struct SwimScore {
    let total: Double          // 0.0 – 10.0
    let baseScore: Double      // pre-penalty score from weather/water-temp
    let weatherScore: Double   // 0.0 – 10.0
    let waterTempScore: Double? // nil when no current water temp
    let qualityPenalty: Double // 0.0 or negative adjustment from quality band
    let bacteriaPenalty: Double // 0.0 or negative adjustment from live bacteria
    let hasBacteriaData: Bool
    let qualityBand: QualityBand
    let forcedReason: ForcedReason?
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

    enum QualityBand: String {
        case ausgezeichnet
        case gut
        case ausreichend
        case mangelhaft
        case unknown

        var label: String {
            switch self {
            case .ausgezeichnet: return "Ausgezeichnet"
            case .gut: return "Gut"
            case .ausreichend: return "Ausreichend"
            case .mangelhaft: return "Mangelhaft"
            case .unknown: return "Keine Einstufung"
            }
        }
    }

    enum ForcedReason {
        case closed
        case poorQuality
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
    /// Base when all data available: weather 70%, water temp 30%
    /// Base when no water temp:      weather 100%
    /// Quality is a penalty only (never boosts): A 0.0, G -0.4, AU -1.8, unknown 0.0.
    /// Live bacteria values (E.Coli/Enterokokken) add an extra penalty when elevated.
    static func compute(
        weather: LakeWeather?,
        waterTemp: Double?,         // nil = no current measurement
        qualityRating: String?,
        isClosed: Bool,
        eColi: Double? = nil,
        enterococci: Double? = nil
    ) -> SwimScore {
        let wScore = weatherSubScore(weather)
        let qualityBand = qualityBand(for: qualityRating)
        let liveBacteriaPenalty = bacteriaDeduction(eColi: eColi, enterococci: enterococci)
        let hasBacteriaData = eColi != nil || enterococci != nil

        // Forced warning for closed or poor-quality lakes
        if isClosed {
            return SwimScore(
                total: 1.0,
                baseScore: wScore,
                weatherScore: wScore,
                waterTempScore: waterTemp.map { waterTempSubScore($0) },
                qualityPenalty: 0.0,
                bacteriaPenalty: 0.0,
                hasBacteriaData: hasBacteriaData,
                qualityBand: qualityBand,
                forcedReason: .closed,
                level: .warnung
            )
        }

        if qualityBand == .mangelhaft {
            return SwimScore(
                total: 1.5,
                baseScore: wScore,
                weatherScore: wScore,
                waterTempScore: waterTemp.map { waterTempSubScore($0) },
                qualityPenalty: -2.0,
                bacteriaPenalty: 0.0,
                hasBacteriaData: hasBacteriaData,
                qualityBand: qualityBand,
                forcedReason: .poorQuality,
                level: .warnung
            )
        }

        let penalty = qualityPenalty(for: qualityBand)

        let base: Double
        if let waterTemp {
            let wtScore = waterTempSubScore(waterTemp)
            // Base: weather 70%, water 30%
            base = wScore * 0.70 + wtScore * 0.30
            let total = clamp(base + penalty + liveBacteriaPenalty)
            return SwimScore(
                total: total,
                baseScore: base,
                weatherScore: wScore,
                waterTempScore: wtScore,
                qualityPenalty: penalty,
                bacteriaPenalty: liveBacteriaPenalty,
                hasBacteriaData: hasBacteriaData,
                qualityBand: qualityBand,
                forcedReason: nil,
                level: level(for: total)
            )
        } else {
            // Base without water temp: weather only
            base = wScore
            let total = clamp(base + penalty + liveBacteriaPenalty)
            return SwimScore(
                total: total,
                baseScore: base,
                weatherScore: wScore,
                waterTempScore: nil,
                qualityPenalty: penalty,
                bacteriaPenalty: liveBacteriaPenalty,
                hasBacteriaData: hasBacteriaData,
                qualityBand: qualityBand,
                forcedReason: nil,
                level: level(for: total)
            )
        }
    }

    // MARK: - Sub-Score Calculations

    /// Weather sub-score (0–10) based on air temp, feels-like, wind, precip, conditions
    private static func weatherSubScore(_ weather: LakeWeather?) -> Double {
        guard let w = weather else { return 5.0 } // neutral fallback

        var score = 0.0

        // Air temperature component (0–10): warm/hot days are preferred for swimming
        if let airTemp = w.airTemperature {
            if airTemp >= 30 {
                score += 10.0
            } else if airTemp >= 26 {
                score += 8.6 + (airTemp - 26) * 0.35   // 26 -> 8.6, 30 -> 10
            } else if airTemp >= 22 {
                score += 7.0 + (airTemp - 22) * 0.40   // 22 -> 7.0, 26 -> 8.6
            } else if airTemp >= 18 {
                score += 4.2 + (airTemp - 18) * 0.70   // 18 -> 4.2, 22 -> 7.0
            } else if airTemp >= 14 {
                score += 2.2 + (airTemp - 14) * 0.50   // 14 -> 2.2, 18 -> 4.2
            } else if airTemp >= 8 {
                score += 0.8 + (airTemp - 8) * 0.2333  // 8 -> 0.8, 14 -> 2.2
            } else {
                score += max(0, airTemp * 0.1)
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

    private static func qualityBand(for rating: String?) -> QualityBand {
        guard let rating = rating?.uppercased(), !rating.isEmpty else { return .unknown }
        switch rating {
        case "A": return .ausgezeichnet
        case "G": return .gut
        case "AU": return .ausreichend
        case "M": return .mangelhaft
        default:
            let r = rating.lowercased()
            if r.contains("ausgezeichnet") || r.contains("excellent") { return .ausgezeichnet }
            if r.contains("gut") || r.contains("good") { return .gut }
            if r.contains("ausreichend") || r.contains("sufficient") { return .ausreichend }
            if r.contains("mangelhaft") || r.contains("poor") { return .mangelhaft }
            return .unknown
        }
    }

    private static func qualityPenalty(for band: QualityBand) -> Double {
        switch band {
        case .ausgezeichnet: return 0.0
        case .gut: return -0.4
        case .ausreichend: return -1.8
        case .mangelhaft: return -2.0
        case .unknown: return 0.0
        }
    }

    private static func bacteriaDeduction(eColi: Double?, enterococci: Double?) -> Double {
        var deduction = 0.0

        if let eColi {
            if eColi > 1000 {
                deduction -= 1.4
            } else if eColi > 500 {
                deduction -= 0.5
            }
        }

        if let enterococci {
            if enterococci > 400 {
                deduction -= 1.4
            } else if enterococci > 200 {
                deduction -= 0.5
            }
        }

        return max(-2.8, deduction)
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
        max(0.0, min(10.0, value))
    }
}
