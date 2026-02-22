import SwiftUI
import SwiftData

@main
struct fluesseundseenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FavouriteItem.self)
    }
}
