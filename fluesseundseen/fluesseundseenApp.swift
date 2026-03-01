import SwiftUI
import SwiftData

@main
struct fluesseundseenApp: App {
    private let tipJarService = TipJarService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(tipJarService)
        }
        .modelContainer(for: FavouriteItem.self)
    }
}
