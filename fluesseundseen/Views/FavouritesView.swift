import SwiftUI
import SwiftData
import UserNotifications

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
                AppTheme.pageBackground
                    .ignoresSafeArea()

                if favourites.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
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

                    Text("Tippe auf das Herz bei einem See,\num ihn hier zu speichern.")
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

        return NavigationLink(destination: destinationView(for: fav)) {
            FavouriteRowContent(
                fav: fav,
                temp: temp,
                quality: quality,
                duckState: duckState,
                live: live,
                toggleNotifications: { toggleNotifications(for: fav) }
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

    // MARK: - Notifications

    private func toggleNotifications(for fav: FavouriteItem) {
        if fav.notificationsEnabled {
            fav.notificationsEnabled = false
            removeNotification(for: fav)
        } else {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        fav.notificationsEnabled = true
                        scheduleNotification(for: fav)
                    }
                }
            }
        }
    }

    private func scheduleNotification(for fav: FavouriteItem) {
        guard let temp = fav.lastKnownTemperature, temp >= 20 else { return }
        let content = UNMutableNotificationContent()
        content.title = fav.lakeName
        content.body = String(format: "%.1f°C erreicht! Ducky sagt: Spring rein!", temp)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 8, repeats: true)
        let request = UNNotificationRequest(identifier: fav.lakeID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func removeNotification(for fav: FavouriteItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [fav.lakeID])
    }

}

// MARK: - Extracted row content to support weather fetching

private struct FavouriteRowContent: View {
    let fav: FavouriteItem
    let temp: Double?
    let quality: String?
    let duckState: DuckState
    let live: BathingWater?
    let toggleNotifications: () -> Void

    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?

    private var score: SwimScore {
        if let live {
            return live.swimScore(weather: weather)
        }
        return SwimScore.compute(weather: weather, waterTemp: nil, qualityRating: quality, isClosed: false)
    }

    var body: some View {
        HStack(spacing: 14) {
            SwimScoreBadge(score: score, size: .medium)

            VStack(alignment: .leading, spacing: 5) {
                Text(fav.lakeName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                if let municipality = fav.municipalityName {
                    Text(municipality)
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let q = quality {
                    let color = BathingWater.qualityColor(for: q)
                    HStack(spacing: 5) {
                        Circle().fill(color).frame(width: 7, height: 7)
                        Text(BathingWater.qualityLabel(for: q))
                            .font(AppTheme.smallCaption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                // Air temperature first
                if let weather, let airTemp = weather.airTemperature {
                    HStack(spacing: 3) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.coral)
                        Text(String(format: "%.0f°C", airTemp))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }

                // Water temperature second
                if let waterTemp = live?.currentWaterTemperature {
                    HStack(spacing: 3) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.skyBlue)
                        Text(String(format: "%.0f°C", waterTemp))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                } else {
                    Text("Wasser: –")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Button(action: toggleNotifications) {
                    Image(systemName: fav.notificationsEnabled ? "bell.fill" : "bell")
                        .font(.system(size: 14))
                        .foregroundStyle(fav.notificationsEnabled ? AppTheme.sunshine : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        .task {
            if let lake = live {
                weather = await weatherService.fetchWeather(for: lake)
            }
        }
    }

}

#Preview {
    FavouritesView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .environment(WeatherService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
