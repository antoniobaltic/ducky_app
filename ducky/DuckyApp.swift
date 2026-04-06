import SwiftUI
import SwiftData
import RevenueCat

@main
struct DuckyApp: App {
    private let tipJarService = TipJarService.shared

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-screenshotMode") {
            Season._previewOverride = .summer
            Season._screenshotMode = true
            WeatherService.shared.isScreenshotMode = true
        }
        #endif

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: "appl_DdxBtpWoeADYapLDIVrhZGbReYr")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(tipJarService)
        }
        .modelContainer(for: [FavouriteItem.self, LakeVisit.self, LakeNote.self])
    }
}
