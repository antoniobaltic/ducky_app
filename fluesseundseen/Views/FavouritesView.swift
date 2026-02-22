import SwiftUI
import SwiftData
import UserNotifications

struct FavouritesView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavouriteItem.addedAt, order: .reverse) var favourites: [FavouriteItem]
    @State private var notificationsRequested = false

    init() {
        _favourites = Query(sort: \FavouriteItem.addedAt, order: .reverse)
    }

    private func liveData(for fav: FavouriteItem) -> BathingWater? {
        dataService.lake(withID: fav.lakeID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.48, green: 0.78, blue: 1.00), Color(red: 0.30, green: 0.58, blue: 0.92)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if favourites.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(favourites) { fav in
                                favouriteRow(fav)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Favoriten")
            .iOSNavigationBarStyle()
            .task {
                await dataService.loadData()
                // Sync cached data for favourites
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
        VStack(spacing: 20) {
            DuckView(state: .zufrieden, size: 120)
            Text("Noch keine Favoriten")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Tippe das ❤️ auf einem See,\num ihn hier zu speichern.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Favourite Row

    private func favouriteRow(_ fav: FavouriteItem) -> some View {
        let live = liveData(for: fav)
        let lake = live
        let temp = live?.waterTemperature ?? fav.lastKnownTemperature
        let quality = live?.qualityRating ?? fav.lastKnownQuality
        let duckState = live?.duckState ?? .zufrieden

        return NavigationLink(destination: destinationView(for: fav)) {
            HStack(spacing: 14) {
                DuckBadge(state: duckState, size: 52)

                VStack(alignment: .leading, spacing: 5) {
                    Text(fav.lakeName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if let municipality = fav.municipalityName {
                        Text(municipality)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let q = quality {
                        let color = qualityColor(for: q)
                        HStack(spacing: 5) {
                            Circle().fill(color).frame(width: 7, height: 7)
                            Text(qualityLabel(for: q))
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    TemperatureBadge(temperature: temp, size: .small)

                    // Notification toggle
                    Button {
                        toggleNotifications(for: fav)
                    } label: {
                        Image(systemName: fav.notificationsEnabled ? "bell.fill" : "bell")
                            .font(.callout)
                            .foregroundStyle(fav.notificationsEnabled ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
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
            Text("Keine aktuellen Daten verfügbar")
                .foregroundStyle(.secondary)
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
        content.body = String(format: "%.1f°C erreicht! 🦆 Spring rein!", temp)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 8, repeats: true)
        let request = UNNotificationRequest(identifier: fav.lakeID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func removeNotification(for fav: FavouriteItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [fav.lakeID])
    }

    // MARK: - Helpers

    private func qualityColor(for rating: String) -> Color {
        let r = rating.lowercased()
        if r.contains("ausgezeichnet") { return .green }
        if r.contains("gut") { return Color(red: 0.6, green: 0.85, blue: 0.2) }
        if r.contains("ausreichend") { return .orange }
        return .red
    }

    private func qualityLabel(for rating: String) -> String {
        let r = rating.lowercased()
        if r.contains("ausgezeichnet") { return "Ausgezeichnet" }
        if r.contains("gut") { return "Gut" }
        if r.contains("ausreichend") { return "Ausreichend" }
        if r.contains("mangelhaft") { return "Mangelhaft" }
        return rating
    }
}

#Preview {
    FavouritesView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
