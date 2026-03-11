import Foundation

enum PreviewFixtures {
    struct AppEnvironment {
        let dataService: DataService
        let locationService: LocationService
        let weatherService: WeatherService
        let lakeContentService: LakeContentService
        let lakePlaceService: LakePlaceService
        let tipJarService: TipJarService
    }

    @MainActor
    static func makeEnvironment(useFixtures: Bool = false) -> AppEnvironment {
        let environment = AppEnvironment(
            dataService: DataService.previewInstance(),
            locationService: LocationService.previewInstance(),
            weatherService: WeatherService.previewInstance(),
            lakeContentService: LakeContentService.previewInstance(),
            lakePlaceService: LakePlaceService.previewInstance(),
            tipJarService: TipJarService.previewInstance()
        )

        if useFixtures {
            installAppPreviewState(
                dataService: environment.dataService,
                weatherService: environment.weatherService
            )
        }

        return environment
    }

    @MainActor
    static func installAppPreviewState(
        dataService: DataService,
        weatherService: WeatherService
    ) {
        dataService.isPreviewStubbed = true
        dataService.isLoading = false
        dataService.error = nil
        dataService.lakes = BathingWater.previews

        weatherService.isPreviewStubbed = true
        weatherService.weatherCache = Dictionary(
            uniqueKeysWithValues: BathingWater.previews.map { lake in
                (lake.id, previewWeather(for: lake))
            }
        )
        weatherService.hydrationTotal = dataService.lakes.count
        weatherService.hydrationCompleted = dataService.lakes.count
        weatherService.isHydratingAll = false
        weatherService.isUsingStaleCache = false
        weatherService.cacheRevision &+= 1
    }

    private static func previewWeather(for lake: BathingWater) -> LakeWeather {
        switch lake.id {
        case BathingWater.preview.id:
            return LakeWeather(
                airTemperature: 27,
                uvIndex: 7,
                conditionSymbol: "sun.max.fill",
                conditionDescription: "Klar",
                feelsLike: 28,
                windSpeed: 5,
                precipitationProbability: 0,
                weatherCode: 0
            )
        case BathingWater.previewCold.id:
            return LakeWeather(
                airTemperature: 18,
                uvIndex: 3,
                conditionSymbol: "wind",
                conditionDescription: "Windig",
                feelsLike: 16,
                windSpeed: 24,
                precipitationProbability: 15,
                weatherCode: 3
            )
        case BathingWater.previewWarn.id:
            return LakeWeather(
                airTemperature: 19,
                uvIndex: 2,
                conditionSymbol: "cloud.bolt.rain.fill",
                conditionDescription: "Gewitter",
                feelsLike: 17,
                windSpeed: 32,
                precipitationProbability: 90,
                weatherCode: 95
            )
        case BathingWater.previewNoTemp.id:
            return LakeWeather(
                airTemperature: 23,
                uvIndex: 5,
                conditionSymbol: "cloud.sun.fill",
                conditionDescription: "Teilweise bewölkt",
                feelsLike: 24,
                windSpeed: 9,
                precipitationProbability: 10,
                weatherCode: 2
            )
        default:
            return LakeWeather(
                airTemperature: 24,
                uvIndex: 5,
                conditionSymbol: "cloud.sun.fill",
                conditionDescription: "Freundlich",
                feelsLike: 25,
                windSpeed: 8,
                precipitationProbability: 5,
                weatherCode: 1
            )
        }
    }
}
