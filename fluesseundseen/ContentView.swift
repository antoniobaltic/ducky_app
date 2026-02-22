import SwiftUI
import SwiftData

struct ContentView: View {
    private let dataService = DataService.shared
    private let locationService = LocationService.shared
    private let weatherService = WeatherService.shared

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Entdecken", systemImage: "water.waves")
                }

            MapView()
                .tabItem {
                    Label("Karte", systemImage: "map.fill")
                }

            FavouritesView()
                .tabItem {
                    Label("Favoriten", systemImage: "heart.fill")
                }
        }
        .environment(dataService)
        .environment(locationService)
        .environment(weatherService)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
