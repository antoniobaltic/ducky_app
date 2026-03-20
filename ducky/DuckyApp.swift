import SwiftUI
import SwiftData

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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(tipJarService)
        }
        .modelContainer(for: [FavouriteItem.self, LakeVisit.self, LakeNote.self])
    }
}
