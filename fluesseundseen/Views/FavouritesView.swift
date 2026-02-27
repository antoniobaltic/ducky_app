import SwiftUI
import SwiftData

struct FavouritesView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(WeatherService.self) private var weatherService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavouriteItem.addedAt, order: .reverse) var favourites: [FavouriteItem]

    init() {
        _favourites = Query(sort: \FavouriteItem.addedAt, order: .reverse)
    }

    private func liveData(for fav: FavouriteItem) -> BathingWater? {
        dataService.lake(withID: fav.lakeID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageGradient
                    .ignoresSafeArea()

                BubbleBackground(color: AppTheme.warmPink)
                    .opacity(0.32)
                    .ignoresSafeArea()

                if favourites.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            favouritesHero

                            // Subtle wave header
                            WaveDivider(color: AppTheme.warmPink, height: 20)
                                .opacity(0.5)
                                .padding(.bottom, 4)

                            LazyVStack(spacing: 12) {
                                ForEach(favourites) { fav in
                                    favouriteRow(fav)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .refreshable {
                        await dataService.refresh()
                        Haptics.success()
                        for fav in favourites {
                            if let live = liveData(for: fav) {
                                fav.lastKnownTemperature = live.waterTemperature
                                fav.lastKnownQuality = live.qualityRating
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favoriten")
            .task {
                await dataService.loadData()
                for fav in favourites {
                    if let live = liveData(for: fav) {
                        fav.lastKnownTemperature = live.waterTemperature
                        fav.lastKnownQuality = live.qualityRating
                    }
                }
            }
        }
    }

    private var favouritesHero: some View {
        HStack(spacing: 12) {
            DuckView(state: .begeistert, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Deine Bade-Favoriten")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(favourites.count) gespeichert")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ZStack {
            // Subtle water background
            VStack {
                Spacer()
                WaterWaveView(baseColor: AppTheme.skyBlue, height: 50, speed: 0.5)
                    .frame(height: 50)
                    .opacity(0.25)
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppTheme.warmPink.opacity(0.08))
                        .frame(width: 160, height: 160)

                    FloatingBubblesView(count: 4, color: AppTheme.warmPink.opacity(0.2))
                        .frame(width: 180, height: 180)

                    DuckView(state: .zufrieden, size: 120)
                }

                VStack(spacing: 8) {
                    Text("Noch keine Favoriten")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Füge einen See zu deinen Favoriten hinzu,\num ihn hier zu sehen!")
                        .font(AppTheme.bodyText)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.warmPink.opacity(0.3))
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding()
        }
    }

    // MARK: - Favourite Row

    private func favouriteRow(_ fav: FavouriteItem) -> some View {
        let live = liveData(for: fav)
        let temp = live?.waterTemperature ?? fav.lastKnownTemperature
        let quality = live?.qualityRating ?? fav.lastKnownQuality
        let duckState = live?.duckState ?? .zufrieden
        let distanceKm = live.flatMap { lake in
            locationService.userLocation.map { lake.distance(from: $0) }
        }

        return NavigationLink(destination: destinationView(for: fav)) {
            FavouriteRowContent(
                fav: fav,
                temp: temp,
                quality: quality,
                duckState: duckState,
                live: live,
                distanceKm: distanceKm
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Haptics.medium()
                modelContext.delete(fav)
            } label: {
                Label("Entfernen", systemImage: "heart.slash.fill")
            }
        }
    }

    @ViewBuilder
    private func destinationView(for fav: FavouriteItem) -> some View {
        if let live = liveData(for: fav) {
            LakeDetailView(lake: live)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Keine aktuellen Daten verfügbar")
                    .font(AppTheme.bodyText)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

}

// MARK: - Extracted row content to support weather fetching

private struct FavouriteRowContent: View {
    let fav: FavouriteItem
    let temp: Double?
    let quality: String?
    let duckState: DuckState
    let live: BathingWater?
    let distanceKm: Double?

    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?
    @State private var appear = false

    private var score: SwimScore {
        if let live {
            return live.swimScore(weather: weather)
        }
        return SwimScore.compute(weather: weather, waterTemp: nil, qualityRating: quality, isClosed: false)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(duckState.accentColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                DuckView(state: duckState, size: 34)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(fav.lakeName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    SwimScoreBadge(score: score, size: .small)
                }

                HStack(spacing: 5) {
                    if let municipality = fav.municipalityName {
                        Text(municipality)
                    }
                    if let distanceKm {
                        Text("·")
                        Text(String(format: "%.1f km", distanceKm))
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 6) {
                    if let weather, let airTemp = weather.airTemperature {
                        tempChip(icon: "sun.max.fill", text: String(format: "%.0f°C", airTemp), color: AppTheme.coral)
                    }
                    if let waterTemp = live?.currentWaterTemperature ?? temp {
                        tempChip(icon: "drop.fill", text: String(format: "%.0f°C", waterTemp), color: AppTheme.skyBlue)
                    } else {
                        tempChip(icon: "drop.fill", text: "Wasser –", color: AppTheme.textSecondary)
                    }
                    if let quality, quality.uppercased() == "AU" || quality.uppercased() == "M" {
                        Text(BathingWater.qualityLabel(for: quality))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.coral)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppTheme.coral.opacity(0.12), in: Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 10)
        .scaleEffect(appear ? 1 : 0.98)
        .task {
            if let lake = live {
                weather = await weatherService.fetchWeather(for: lake)
            }
        }
        .onAppear {
            withAnimation(AppTheme.entranceSpring.delay(Double.random(in: 0...0.08))) {
                appear = true
            }
        }
    }

    private func tempChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.10), in: Capsule())
    }

}

#Preview("Empty") {
    FavouritesView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .environment(WeatherService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}

#Preview("With Favorites") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FavouriteItem.self, configurations: config)
    let context = container.mainContext

    let one = FavouriteItem(
        lakeID: "preview_1",
        lakeName: "Grundlsee",
        municipalityName: "Bad Aussee",
        lastKnownTemperature: 20.8,
        lastKnownQuality: "A"
    )
    let two = FavouriteItem(
        lakeID: "preview_2",
        lakeName: "Wörthersee",
        municipalityName: "Klagenfurt",
        lastKnownTemperature: 23.2,
        lastKnownQuality: "A"
    )
    context.insert(one)
    context.insert(two)

    return FavouritesView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .environment(WeatherService.shared)
        .modelContainer(container)
}
