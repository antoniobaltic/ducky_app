import SwiftUI
import SwiftData
import MapKit

struct LakeDetailView: View {
    let lake: BathingWater
    @Environment(\.modelContext) private var modelContext
    @Query var favourites: [FavouriteItem]

    init(lake: BathingWater) {
        self.lake = lake
    }

    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?
    @State private var showShareCard = false
    @State private var showBacteriaValues = false
    @State private var appear = false

    private var isFavourite: Bool {
        favourites.contains { $0.lakeID == lake.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentSection
            }
        }
        .background(AppTheme.pageBackground)
        .ignoresSafeArea(edges: .top)
        .iOSNavigationBarInline()
        .toolbar {
            ToolbarItem(placement: .iOSTopBarTrailing) {
                HStack(spacing: 12) {
                    Button { showShareCard = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    favouriteButton
                }
            }
        }
        .sheet(isPresented: $showShareCard) {
            ShareCardView(lake: lake, weather: weather)
        }
        .task {
            weather = await weatherService.fetchWeather(for: lake)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
            RecentLake.add(RecentLake(id: lake.id, name: lake.name))
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                lake.duckState.backgroundGradient
                    .frame(height: 370)

                // Floating bubbles
                FloatingBubblesView(count: 5, color: .white.opacity(0.25))
                    .frame(height: 370)
            }

            // Wave at bottom of hero
            WaterWaveView(baseColor: AppTheme.pageBackground, height: 30, speed: 0.6)
                .frame(height: 30)
                .offset(y: 14)

            VStack(spacing: 0) {
                Spacer(minLength: 80)

                // Ducky left + quote right
                HStack(alignment: .center, spacing: 14) {
                    DuckView(state: lake.duckState, size: 90)
                        .scaleEffect(appear ? 1 : 0.7)
                        .opacity(appear ? 1 : 0)

                    Text("\u{201E}\(lake.duckState.line)\u{201C}")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .italic()
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.bottom, 12)

                // Name + location
                VStack(spacing: 6) {
                    Text(lake.name)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 6) {
                        if let municipality = lake.municipality {
                            Text(municipality)
                        }
                        if let state = lake.state {
                            Text("·")
                            Text(state)
                        }
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)

                    if lake.isClosed {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Gesperrt")
                            if let reason = lake.closureReason, !reason.isEmpty {
                                Text("– \(reason)")
                            }
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(AppTheme.coral, in: Capsule())
                        .padding(.top, 4)
                    }
                }

                // Temperature display: Air + Water side by side
                HStack(spacing: 0) {
                    // Air temperature
                    if let weather, let airTemp = weather.airTemperature {
                        VStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.coral)
                            HStack(alignment: .top, spacing: 2) {
                                Text(String(format: "%.0f", airTemp))
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AppTheme.coral)
                                Text("°C")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.coral.opacity(0.7))
                                    .padding(.top, 5)
                            }
                            Text("Luft")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Water temperature
                    VStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.oceanBlue)
                        if let temp = lake.waterTemperature {
                            HStack(alignment: .top, spacing: 2) {
                                Text(String(format: "%.1f", temp))
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundStyle(lake.isTemperatureOutdated ? AppTheme.oceanBlue.opacity(0.5) : AppTheme.oceanBlue)
                                Text("°C")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.oceanBlue.opacity(lake.isTemperatureOutdated ? 0.35 : 0.7))
                                    .padding(.top, 5)
                            }
                        } else {
                            Image(systemName: "thermometer.medium.slash")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                        Text("Wasser")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                        if lake.isTemperatureOutdated {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 10))
                                Text("Stand: \(lake.measurementDate ?? "unbekannt")")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 14)

                Spacer(minLength: 28)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(spacing: 16) {
            // Off-season info banner
            if Season.isOffSeason {
                seasonInfoBanner
            }

            // Weather (always try to show)
            if let weather {
                weatherCard(weather)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            qualityCard
            bacteriaCard

            if let depth = lake.visibilityDepth {
                visibilityCard(depth)
            }

            mapCard
            routeButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 40)
    }

    // MARK: - Season Info Banner

    private var seasonInfoBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: Season.current.heroIcon)
                .font(.system(size: 18))
                .foregroundStyle(Season.current == .winter ? AppTheme.winterBlue : AppTheme.autumnOrange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Außerhalb der Badesaison")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Wassertemperaturen werden von Juni bis August gemessen.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .appCard()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(AppTheme.textSecondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Weather Card

    private func weatherCard(_ weather: LakeWeather) -> some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 18))
                        .symbolRenderingMode(.multicolor)
                    Text("Wetter vor Ort")
                        .font(AppTheme.cardTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Aktuell")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.freshGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.freshGreen.opacity(0.12), in: Capsule())
                }
                Spacer()
                Image(systemName: weather.conditionSymbol)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
            }

            HStack(spacing: 0) {
                if let airTemp = weather.airTemperature {
                    weatherStat(
                        icon: "thermometer.medium",
                        value: String(format: "%.0f°C", airTemp),
                        label: "Lufttemperatur",
                        color: AppTheme.coral
                    )
                }
                if let uv = weather.uvIndex {
                    weatherStat(
                        icon: "sun.max.fill",
                        value: "\(uv)",
                        label: "UV-Index",
                        color: AppTheme.sunshine
                    )
                }
                if let feels = weather.feelsLike {
                    weatherStat(
                        icon: "person.fill",
                        value: String(format: "%.0f°C", feels),
                        label: "Gefühlt",
                        color: AppTheme.lavender
                    )
                }
            }

            Text(weather.conditionDescription)
                .font(AppTheme.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .appCard()
    }

    private func weatherStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quality Card

    private var qualityCard: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(lake.qualityColor)
                    Text("Wasserqualität")
                        .font(AppTheme.cardTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                QualityBadge(qualityLabel: lake.qualityLabel, qualityColor: lake.qualityColor)
            }

            if let date = lake.measurementDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Gemessen am \(date)")
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
            }

            // AGES attribution
            HStack(spacing: 4) {
                Image(systemName: "building.columns")
                    .font(.system(size: 10))
                Text("Daten: AGES Badegewässerdatenbank")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
        }
        .appCard()
    }

    // MARK: - Bacteria Card

    private var bacteriaCard: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "allergens")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.teal)
                    Text("Bakteriologie")
                        .font(AppTheme.cardTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                Button {
                    withAnimation(AppTheme.quickSpring) { showBacteriaValues.toggle() }
                } label: {
                    Text(showBacteriaValues ? "Ausblenden" : "Details")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }

            TrafficLightRow(
                label: "E.coli",
                value: lake.eColi.map { String(format: "%.0f KBE/100ml", $0) },
                status: lake.eColiStatus,
                showValue: showBacteriaValues
            )

            Divider()

            TrafficLightRow(
                label: "Enterokokken",
                value: lake.enterococci.map { String(format: "%.0f KBE/100ml", $0) },
                status: lake.enterococciStatus,
                showValue: showBacteriaValues
            )

            if let date = lake.measurementDate {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Gemessen am \(date)")
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .appCard()
    }

    // MARK: - Visibility Card

    private func visibilityCard(_ depth: Double) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.skyBlue)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.skyBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sichttiefe")
                        .font(AppTheme.cardTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(String(format: "%.1f Meter", depth))
                        .font(AppTheme.bodyText)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                // Visual depth bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.divider)
                        .frame(width: 80, height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.skyBlue, AppTheme.oceanBlue],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: min(CGFloat(depth / 8.0) * 80, 80), height: 8)
                }
            }

            if let date = lake.measurementDate {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Gemessen am \(date)")
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .appCard()
    }

    // MARK: - Map Card

    private var mapCard: some View {
        Map {
            Marker(lake.name, coordinate: lake.coordinate)
                .tint(lake.qualityColor)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        .allowsHitTesting(false)
    }

    // MARK: - Route Button

    private var routeButton: some View {
        Button { openInMaps() } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                Text("Route in Apple Maps")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.oceanBlue, in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
            .shadow(color: AppTheme.oceanBlue.opacity(0.3), radius: 10, y: 5)
        }
    }

    // MARK: - Favourite

    private var favouriteButton: some View {
        Button { toggleFavourite() } label: {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFavourite ? AppTheme.warmPink : .primary)
                .symbolEffect(.bounce, value: isFavourite)
        }
    }

    // MARK: - Actions

    private func toggleFavourite() {
        Haptics.medium()
        if let existing = favourites.first(where: { $0.lakeID == lake.id }) {
            modelContext.delete(existing)
        } else {
            let item = FavouriteItem(
                lakeID: lake.id,
                lakeName: lake.name,
                municipalityName: lake.municipality,
                lastKnownTemperature: lake.waterTemperature,
                lastKnownQuality: lake.qualityRating
            )
            modelContext.insert(item)
        }
    }

    private func openInMaps() {
        let coordinate = lake.coordinate
        guard let url = URL(string: "maps://?q=\(lake.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lake.name)&ll=\(coordinate.latitude),\(coordinate.longitude)") else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - Card Container (legacy compat)

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .appCard()
    }
}

#Preview {
    NavigationStack {
        LakeDetailView(lake: .preview)
            .environment(WeatherService.shared)
            .modelContainer(for: FavouriteItem.self, inMemory: true)
    }
}
