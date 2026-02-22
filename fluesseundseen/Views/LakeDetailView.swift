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

    private var isFavourite: Bool {
        favourites.contains { $0.lakeID == lake.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero
                heroSection

                // Content
                VStack(spacing: 16) {
                    qualitySection
                    if let weather { weatherSection(weather) }
                    bacteriaSection
                    if let depth = lake.visibilityDepth { visibilitySection(depth) }
                    verdictCard
                    routeButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .iOSNavigationBarInline()
        .toolbar {
            ToolbarItem(placement: .iOSTopBarTrailing) {
                favouriteButton
            }
        }
        .sheet(isPresented: $showShareCard) {
            ShareCardView(lake: lake, weather: weather)
        }
        .task {
            weather = await weatherService.fetchWeather(for: lake)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            lake.duckState.backgroundGradient
                .frame(height: 340)

            VStack(spacing: 0) {
                Spacer()

                // Duck
                DuckView(state: lake.duckState, size: 140)
                    .padding(.bottom, 8)

                // Lake name
                Text(lake.name)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                if let municipality = lake.municipality {
                    Text(municipality + (lake.state.map { ", \($0)" } ?? ""))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Temperature big
                TemperatureBadge(temperature: lake.waterTemperature, size: .hero)
                    .padding(.top, 8)

                // Duck quote
                Text("\u{201E}\(lake.duckState.line)\u{201C}")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(.top, 4)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Quality Section

    private var qualitySection: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Text("Wasserqualität")
                        .font(.headline)
                    Spacer()
                    QualityBadge(qualityLabel: lake.qualityLabel, qualityColor: lake.qualityColor)
                }

                if let date = lake.measurementDate {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text("Gemessen am \(date)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Weather Section

    private func weatherSection(_ weather: LakeWeather) -> some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Text("Wetter vor Ort")
                        .font(.headline)
                    Spacer()
                    Image(systemName: weather.conditionSymbol)
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)
                }

                HStack(spacing: 24) {
                    if let airTemp = weather.airTemperature {
                        weatherStat(
                            icon: "thermometer.medium",
                            value: String(format: "%.0f°C", airTemp),
                            label: "Luft"
                        )
                    }
                    if let uv = weather.uvIndex {
                        weatherStat(
                            icon: "sun.max.fill",
                            value: "\(uv)",
                            label: "UV-Index"
                        )
                    }
                    if let feels = weather.feelsLike {
                        weatherStat(
                            icon: "figure.walk",
                            value: String(format: "%.0f°C", feels),
                            label: "Gefühlt"
                        )
                    }
                    Spacer()
                }
            }
        }
    }

    private func weatherStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bacteria Section

    private var bacteriaSection: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Text("Bakteriologie")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation { showBacteriaValues.toggle() }
                    } label: {
                        Text(showBacteriaValues ? "Werte ausblenden" : "Werte anzeigen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            }
        }
    }

    // MARK: - Visibility Section

    private func visibilitySection(_ depth: Double) -> some View {
        CardView {
            HStack {
                Image(systemName: "eye.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sichttiefe")
                        .font(.headline)
                    Text(String(format: "%.1f Meter", depth))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Visual depth bar
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 80, height: 8)
                    Capsule()
                        .fill(.blue)
                        .frame(width: min(CGFloat(depth / 8.0) * 80, 80), height: 8)
                }
            }
        }
    }

    // MARK: - Verdict Card

    private var verdictCard: some View {
        Button {
            showShareCard = true
        } label: {
            CardView {
                HStack(spacing: 16) {
                    DuckBadge(state: lake.duckState, size: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lohnt es sich?")
                            .font(.headline)
                        Text(verdictSentence)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var verdictSentence: String {
        guard let temp = lake.waterTemperature else {
            return "Keine aktuellen Temperaturdaten."
        }
        let tempStr = String(format: "%.1f°C", temp)
        switch lake.duckState {
        case .begeistert:
            return "\(tempStr) Wassertemperatur — perfekte Bedingungen!"
        case .zufrieden:
            return "\(tempStr) Wassertemperatur — angenehm für die meisten."
        case .zoegernd:
            return "\(tempStr) Wassertemperatur — nur für Mutige."
        case .frierend:
            return "\(tempStr) Wassertemperatur — besser warten."
        case .warnend:
            return "Die Wasserqualität ist aktuell mangelhaft."
        }
    }

    // MARK: - Route Button

    private var routeButton: some View {
        Button {
            openInMaps()
        } label: {
            HStack {
                Image(systemName: "map.fill")
                Text("Route via Apple Maps")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.blue, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
    }

    // MARK: - Favourite Toggle

    private var favouriteButton: some View {
        Button {
            toggleFavourite()
        } label: {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isFavourite ? .pink : .primary)
                .font(.title3)
        }
    }

    // MARK: - Actions

    private func toggleFavourite() {
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

// MARK: - Card container

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack {
        LakeDetailView(lake: .preview)
            .environment(WeatherService.shared)
            .modelContainer(for: FavouriteItem.self, inMemory: true)
    }
}
