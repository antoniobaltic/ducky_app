import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @State private var selectedLake: BathingWater?
    @State private var searchText = ""
    @State private var showAllLakes = false
    @State private var selectedState: String?
    @State private var heroAppear = false

    private var nearbyLakes: [BathingWater] {
        Array(dataService.sortedByDistance(from: locationService.userLocation).prefix(20))
    }

    private var warmestLakes: [BathingWater] {
        Array(dataService.sortedByTemperature().prefix(20))
    }

    private var filteredLakes: [BathingWater] {
        var lakes = dataService.search(searchText)
        if let state = selectedState {
            lakes = lakes.filter { $0.state == state }
        }
        return lakes
    }

    // MARK: - Contextual hero data

    private var warmLakeCount: Int {
        dataService.lakes.filter { ($0.waterTemperature ?? 0) >= 20 }.count
    }

    private var lakesWithTemperature: Int {
        dataService.lakes.filter { $0.waterTemperature != nil }.count
    }

    private var season: Season { .current }

    private var heroState: DuckState {
        if dataService.isLoading { return .zufrieden }
        // Off-season: use seasonal duck state
        if Season.isOffSeason { return season.duckState }
        // In-season: data-driven
        if warmLakeCount > 10 { return .begeistert }
        if warmLakeCount > 0 { return .zufrieden }
        if lakesWithTemperature > 0 {
            let anyWarm = dataService.lakes.contains { ($0.waterTemperature ?? 0) >= 14 }
            return anyWarm ? .zoegernd : .frierend
        }
        return .zufrieden
    }

    private var heroGreeting: String {
        // Off-season: use seasonal title
        if Season.isOffSeason { return season.heroTitle }
        // In-season: time-of-day greeting
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "Gute Nacht!" }
        if hour < 12 { return "Guten Morgen!" }
        if hour < 18 { return "Hallo!" }
        return "Guten Abend!"
    }

    private var heroMessage: String {
        if dataService.isLoading {
            return "Ducky checkt die Wassertemperaturen..."
        }

        // Off-season: seasonal message
        if Season.isOffSeason {
            return season.heroMessage
        }

        let total = dataService.lakes.count

        if total == 0 {
            return "Entdecke Österreichs schönste Badegewässer!"
        }

        // In-season: no temperature data yet
        if lakesWithTemperature == 0 {
            return "\(total) Gewässer geladen. Temperaturdaten werden aktualisiert."
        }

        // In-season: data-driven messages
        if warmLakeCount > 10 {
            if let warmest = warmestLakes.first, let temp = warmest.waterTemperature {
                return "Super Badewetter! \(warmLakeCount) Seen über 20°C. \(warmest.name) führt mit \(String(format: "%.0f", temp))°C!"
            }
            return "Super Badewetter! \(warmLakeCount) Seen haben über 20°C!"
        }

        if warmLakeCount > 0 {
            return "\(warmLakeCount) von \(lakesWithTemperature) Seen sind warm genug zum Baden."
        }

        let mildCount = dataService.lakes.filter { ($0.waterTemperature ?? 0) >= 14 }.count
        if mildCount > 0 {
            return "Die Seen sind noch frisch — \(mildCount) haben über 14°C. Nur für Mutige!"
        }

        return "Brr! Die Seen sind noch kalt. Ducky empfiehlt: Warten."
    }

    /// Year of the last measurement data, e.g. "2025"
    private var lastMeasurementYear: String {
        warmestLakes.first?.measurementYear ?? ""
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        contentSections
                    }
                }
                .refreshable {
                    await dataService.refresh()
                }
            }
            .navigationTitle("Entdecken")
            .iOSNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .iOSTopBarTrailing) {
                    if dataService.isLoading {
                        ProgressView()
                    }
                }
            }
            .navigationDestination(item: $selectedLake) { lake in
                LakeDetailView(lake: lake)
            }
        }
        .task {
            await dataService.loadData()
            locationService.requestPermission()
            locationService.startUpdating()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background gradient card — seasonal
            ZStack {
                season.heroGradient

                // Seasonal particle effects (snow, leaves, blossoms, or bubbles)
                SeasonalOverlay(season: season)
            }
            .frame(height: 310)
            .clipShape(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .padding(.horizontal, 16)
            .shadow(color: season.heroGradientColors.last?.opacity(0.25) ?? AppTheme.oceanBlue.opacity(0.2), radius: 20, y: 10)

            // Wave at the bottom of hero
            WaterWaveView(baseColor: season.waveColor, height: 35, speed: 0.8)
                .frame(height: 35)
                .offset(y: 15)
                .padding(.horizontal, 16)

            // Content overlay
            VStack(spacing: 10) {
                // Duck
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 130, height: 130)
                        .scaleEffect(heroAppear ? 1.05 : 0.95)

                    DuckView(state: heroState, size: 110)
                }
                .frame(height: 130)

                // Season icon + greeting
                HStack(spacing: 6) {
                    if Season.isOffSeason {
                        Image(systemName: season.heroIcon)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(heroGreeting)
                        .font(.system(size: Season.isOffSeason ? 20 : 14, weight: Season.isOffSeason ? .heavy : .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(Season.isOffSeason ? 1.0 : 0.75))

                // Contextual message
                Text(heroMessage)
                    .font(.system(size: Season.isOffSeason ? 15 : 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(Season.isOffSeason ? 0.85 : 1.0))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 20)
                    .fixedSize(horizontal: false, vertical: true)

                if let error = dataService.error {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text(error)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.12), in: Capsule())
                }
            }
            .padding(.bottom, 36)
        }
        .padding(.bottom, 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                heroAppear = true
            }
        }
    }

    // MARK: - Content

    private var contentSections: some View {
        VStack(spacing: 28) {
            searchBar
            statsRow

            if locationService.isAuthorized {
                lakeSection(
                    title: "In deiner Nähe",
                    icon: "location.fill",
                    iconColor: AppTheme.oceanBlue,
                    lakes: nearbyLakes,
                    showDistance: true
                )
            }

            if !warmestLakes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    lakeSection(
                        title: Season.isOffSeason ? "Letzte Messungen" : "Am wärmsten",
                        icon: Season.isOffSeason ? "clock.arrow.circlepath" : "flame.fill",
                        iconColor: Season.isOffSeason ? AppTheme.textSecondary : AppTheme.coral,
                        lakes: warmestLakes,
                        showDistance: false
                    )

                    // Off-season: show that this data is from last summer
                    if Season.isOffSeason && !lastMeasurementYear.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("Wassertemperaturen vom Sommer \(lastMeasurementYear)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }
                }
            }

            // Wave divider before all lakes
            WaveDivider(color: AppTheme.teal, height: 24)
                .padding(.horizontal, 16)

            allLakesSection

            // Data source attribution
            dataAttributionFooter
        }
        .padding(.bottom, 40)
    }

    // MARK: - Data Attribution

    private var dataAttributionFooter: some View {
        VStack(spacing: 6) {
            Divider()
                .padding(.horizontal, 20)

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 10))
                    Text("Wasserqualität & Temperatur: AGES Badegewässerdatenbank")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }

                Text("Wassertemperaturen werden von Juni bis August gemessen.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))

                HStack(spacing: 4) {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 10))
                    Text("Wetter: Open-Meteo (aktuell)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
            }
            .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            TextField("See oder Ort suchen...", text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .rounded))

            if !searchText.isEmpty {
                Button {
                    withAnimation(AppTheme.quickSpring) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        .padding(.horizontal, 20)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statChip(
                    icon: "drop.fill",
                    value: "\(dataService.lakes.count)",
                    label: "Gewässer",
                    color: AppTheme.oceanBlue
                )
                if let warmest = warmestLakes.first, let temp = warmest.waterTemperature {
                    statChip(
                        icon: Season.isOffSeason ? "clock.arrow.circlepath" : "thermometer.sun.fill",
                        value: String(format: "%.0f°C", temp),
                        label: Season.isOffSeason ? "Sommer \(lastMeasurementYear)" : "Wärmstes",
                        color: Season.isOffSeason ? AppTheme.textSecondary : AppTheme.coral
                    )
                }
                statChip(
                    icon: "checkmark.seal.fill",
                    value: "\(dataService.lakes.filter { $0.qualityRating?.uppercased() == "A" }.count)",
                    label: "Ausgezeichnet",
                    color: AppTheme.freshGreen
                )
                statChip(
                    icon: "map.fill",
                    value: "\(dataService.availableStates.count)",
                    label: "Bundesländer",
                    color: AppTheme.lavender
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func statChip(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(width: 90, height: 90)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Lake Section

    private func lakeSection(
        title: String,
        icon: String,
        iconColor: Color,
        lakes: [BathingWater],
        showDistance: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(AppTheme.sectionTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)

            if dataService.isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                                .fill(AppTheme.divider)
                                .frame(width: 200, height: 140)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else if lakes.isEmpty {
                Text("Keine Daten verfügbar")
                    .font(AppTheme.bodyText)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(lakes) { lake in
                            LakeCard(
                                lake: lake,
                                distanceKm: showDistance ? locationService.userLocation.map { lake.distance(from: $0) } : nil
                            )
                            .onTapGesture { selectedLake = lake }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - All Lakes Section

    private var allLakesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.teal)
                Text("Alle Gewässer")
                    .font(AppTheme.sectionTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()

                Text("\(filteredLakes.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.divider, in: Capsule())
            }
            .padding(.horizontal, 20)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "Alle", isSelected: selectedState == nil) {
                        selectedState = nil
                    }
                    ForEach(dataService.availableStates, id: \.self) { state in
                        filterChip(label: state, isSelected: selectedState == state) {
                            selectedState = selectedState == state ? nil : state
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Lake list
            LazyVStack(spacing: 2) {
                ForEach(filteredLakes.prefix(showAllLakes ? 999 : 20)) { lake in
                    Button { selectedLake = lake } label: {
                        LakeListRow(
                            lake: lake,
                            distanceKm: locationService.userLocation.map { lake.distance(from: $0) }
                        )
                    }
                    .buttonStyle(.plain)

                    if lake.id != filteredLakes.prefix(showAllLakes ? 999 : 20).last?.id {
                        Divider()
                            .padding(.leading, 74)
                            .padding(.trailing, 20)
                    }
                }
            }
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
            .padding(.horizontal, 16)

            if filteredLakes.count > 20 && !showAllLakes {
                Button {
                    withAnimation(AppTheme.gentleSpring) { showAllLakes = true }
                } label: {
                    HStack(spacing: 6) {
                        Text("Alle \(filteredLakes.count) anzeigen")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.oceanBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.oceanBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AppTheme.oceanBlue : Color.clear,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppTheme.divider, lineWidth: 1.5)
                )
        }
        .animation(AppTheme.quickSpring, value: isSelected)
    }
}

#Preview {
    HomeView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
