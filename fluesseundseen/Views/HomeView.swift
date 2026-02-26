import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(WeatherService.self) private var weatherService
    @Environment(\.modelContext) private var modelContext
    @Query var favourites: [FavouriteItem]
    @State private var selectedLake: BathingWater?
    @State private var searchText = ""
    @State private var selectedState: String?
    @State private var heroAppear = false
    @State private var showSettings = false
    @FocusState private var isSearchFocused: Bool

    // Filters
    @State private var selectedQuality: String?
    @State private var selectedScoreFilter: ScoreFilter?

    // Sort
    @State private var sortOption: SortOption = .bestScore

    // Recent lakes
    @State private var recentLakes: [RecentLake] = []

    // MARK: - Display State
    // These are derived values computed off the render path (via updateDisplayLakes),
    // so that weatherCache updates don't trigger expensive recomputation every frame.
    @State private var displayLakes: [BathingWater] = []
    @State private var displayTotalCount: Int = 0
    @State private var cachedGoodScoreCount: Int = 0
    @State private var cachedAverageScore: SwimScore? = nil
    @State private var visibleCount: Int = 20        // progressive pagination
    @State private var updateTask: Task<Void, Never>?

    // MARK: - Sort / Filter Enums

    enum SortOption: String, CaseIterable {
        case bestScore, nearest, warmest, coldest, alphabetical

        var label: String {
            switch self {
            case .bestScore:    return "Bester Score"
            case .nearest:      return "Nächste"
            case .warmest:      return "Wärmstes Wasser"
            case .coldest:      return "Kältestes Wasser"
            case .alphabetical: return "A–Z"
            }
        }

        var icon: String {
            switch self {
            case .bestScore:    return "star.fill"
            case .nearest:      return "location.fill"
            case .warmest:      return "flame.fill"
            case .coldest:      return "snowflake"
            case .alphabetical: return "textformat.abc"
            }
        }
    }

    enum ScoreFilter: String, CaseIterable {
        case perfekt, gut

        var label: String { self == .perfekt ? "Perfekt" : "Gut+" }
        var icon: String  { self == .perfekt ? "star.fill" : "hand.thumbsup.fill" }
        var color: Color  { self == .perfekt ? AppTheme.scorePerfekt : AppTheme.scoreGut }
        var minScore: Double { self == .perfekt ? 8.0 : 6.0 }
    }

    // MARK: - Inexpensive Computed Properties (no weatherCache access)

    private var nearbyLakes: [BathingWater] {
        guard let loc = locationService.userLocation else { return [] }
        // Pre-compute distances once, sort once — avoids CLLocation allocation per comparison
        return dataService.lakes
            .map { ($0, $0.distance(from: loc)) }
            .sorted { $0.1 < $1.1 }
            .prefix(20)
            .map { $0.0 }
    }

    private var isSearchActive: Bool {
        !searchText.isEmpty || selectedQuality != nil || selectedScoreFilter != nil
    }

    private var activeFilterCount: Int {
        (selectedQuality != nil ? 1 : 0) +
        (selectedScoreFilter != nil ? 1 : 0) +
        (selectedState != nil ? 1 : 0)
    }

    private var season: Season { .current }

    private var heroState: DuckState {
        if dataService.isLoading { return .zufrieden }
        if let avg = cachedAverageScore { return avg.duckState }
        if Season.isOffSeason { return season.duckState }
        return .zufrieden
    }

    private var heroGreeting: String {
        if Season.isOffSeason { return season.heroTitle }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6  { return "Gute Nacht!" }
        if hour < 12 { return "Guten Morgen!" }
        if hour < 18 { return "Hallo!" }
        return "Guten Abend!"
    }

    private var heroMessage: String {
        if dataService.isLoading { return "Ducky checkt die Bedingungen..." }
        if Season.isOffSeason { return season.heroMessage }

        let total = dataService.lakes.count
        if total == 0 { return "Entdecke Österreichs schönste Badegewässer!" }

        if let avg = cachedAverageScore {
            let good = cachedGoodScoreCount
            switch avg.level {
            case .perfekt:  return "Perfekter Badetag! \(good) Seen mit top Bedingungen."
            case .gut:      return "Gute Bedingungen heute! \(good) Seen laden zum Baden ein."
            case .mittel:   return "Durchwachsen — \(good) Seen haben noch gute Bedingungen."
            case .schlecht: return "Nicht ideal heute. Vielleicht morgen besser?"
            case .warnung:  return "Heute eher ein Tag für drinnen."
            }
        }

        return "\(total) Gewässer geladen. Wetterdaten werden aktualisiert."
    }

    // MARK: - Display Update (debounced, off-render-path)

    /// Recompute displayLakes, hero stats, and pagination.
    /// `debounce: true` waits 200 ms — coalesces rapid weather cache ticks.
    private func updateDisplayLakes(debounce: Bool = true) {
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            if debounce {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
            }

            // Snapshot the cache so the sort key is stable within this computation
            let cache = weatherService.weatherCache

            var lakes = dataService.search(searchText)
            if let state = selectedState {
                lakes = lakes.filter { $0.state == state }
            }
            if let quality = selectedQuality {
                lakes = lakes.filter { $0.qualityRating?.uppercased() == quality }
            }
            if let scoreFilter = selectedScoreFilter {
                lakes = lakes.filter {
                    $0.swimScore(weather: cache[$0.id]).total >= scoreFilter.minScore
                }
            }
            switch sortOption {
            case .bestScore:
                lakes.sort { a, b in
                    a.swimScore(weather: cache[a.id]).total > b.swimScore(weather: cache[b.id]).total
                }
            case .nearest:
                if let loc = locationService.userLocation {
                    let distances = Dictionary(uniqueKeysWithValues: lakes.map { ($0.id, $0.distance(from: loc)) })
                    lakes.sort { (distances[$0.id] ?? .infinity) < (distances[$1.id] ?? .infinity) }
                }
            case .warmest:
                lakes.sort { ($0.waterTemperature ?? -999) > ($1.waterTemperature ?? -999) }
            case .coldest:
                lakes.sort { ($0.waterTemperature ?? 999) < ($1.waterTemperature ?? 999) }
            case .alphabetical:
                lakes.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            }

            displayTotalCount = lakes.count
            displayLakes = lakes

            // Hero stats (scoped to all lakes, not just filtered)
            let allLakes = dataService.lakes
            cachedGoodScoreCount = allLakes.filter { cache[$0.id] != nil && $0.swimScore(weather: cache[$0.id]).total >= 6.0 }.count

            let scored = allLakes.compactMap { lake -> SwimScore? in
                guard cache[lake.id] != nil else { return nil }
                return lake.swimScore(weather: cache[lake.id])
            }
            if !scored.isEmpty {
                let avgTotal = scored.map(\.total).reduce(0, +) / Double(scored.count)
                cachedAverageScore = scored.min { abs($0.total - avgTotal) < abs($1.total - avgTotal) }
            } else {
                cachedAverageScore = nil
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if !isSearchActive {
                            heroSection
                        }
                        contentSections
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await dataService.refresh()
                    Haptics.success()
                }
            }
            .navigationTitle("Entdecken")
            .iOSNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .iOSTopBarTrailing) {
                    HStack(spacing: 14) {
                        if dataService.isLoading {
                            ProgressView()
                        }
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedLake) { lake in
                LakeDetailView(lake: lake)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .task {
            await dataService.loadData()
            locationService.requestPermission()
            locationService.startUpdating()
            recentLakes = RecentLake.load()

            // Populate display immediately after data loads (no debounce)
            updateDisplayLakes(debounce: false)

            // Prefetch weather for the first visible page
            let prefetchTargets = Array((displayLakes.isEmpty ? dataService.lakes : displayLakes).prefix(30))
            await weatherService.prefetchWeather(for: prefetchTargets)

            // Re-sort with fresh weather scores
            updateDisplayLakes(debounce: false)
        }
        // React to filter/sort/data changes — reset pagination on most changes
        .onChange(of: dataService.lakes) {
            visibleCount = 20
            updateDisplayLakes(debounce: false)
        }
        .onChange(of: sortOption) {
            visibleCount = 20
            updateDisplayLakes(debounce: false)
        }
        .onChange(of: selectedState) {
            visibleCount = 20
            updateDisplayLakes(debounce: false)
        }
        .onChange(of: selectedQuality) {
            visibleCount = 20
            updateDisplayLakes(debounce: false)
        }
        .onChange(of: selectedScoreFilter) {
            visibleCount = 20
            updateDisplayLakes(debounce: false)
        }
        .onChange(of: searchText) {
            // Debounce search input so we don't refilter on every keystroke
            visibleCount = 20
            updateDisplayLakes(debounce: true)
        }
        // Weather updates are debounced — coalesces many individual lake fetches
        .onChange(of: weatherService.weatherCache.count) {
            updateDisplayLakes(debounce: true)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                season.heroGradient
                SeasonalOverlay(season: season)
            }
            .frame(height: 310)
            .clipShape(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .padding(.horizontal, 16)
            .shadow(color: season.heroGradientColors.last?.opacity(0.25) ?? AppTheme.oceanBlue.opacity(0.2), radius: 20, y: 10)

            WaterWaveView(baseColor: season.waveColor, height: 35, speed: 0.8)
                .frame(height: 35)
                .offset(y: 15)
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 130, height: 130)
                        .scaleEffect(heroAppear ? 1.05 : 0.95)
                    DuckView(state: heroState, size: 110)
                }
                .frame(height: 130)

                HStack(spacing: 6) {
                    if Season.isOffSeason {
                        Image(systemName: season.heroIcon)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(heroGreeting)
                        .font(.system(size: Season.isOffSeason ? 20 : 14, weight: Season.isOffSeason ? .heavy : .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(Season.isOffSeason ? 1.0 : 0.75))

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
        VStack(spacing: isSearchActive ? 16 : 28) {
            searchBar

            // Recent lakes shown when search is focused but empty
            if isSearchFocused && searchText.isEmpty && !recentLakes.isEmpty && !isSearchActive {
                recentLakesSection
            }

            if isSearchActive {
                searchFilters
                allLakesSection
            } else {
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

                WaveDivider(color: AppTheme.teal, height: 24)
                    .padding(.horizontal, 16)

                allLakesSection
                dataAttributionFooter
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Search Filters

    private var searchFilters: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "Ausgezeichnet", icon: "checkmark.seal.fill", iconColor: AppTheme.freshGreen, isSelected: selectedQuality == "A") {
                        withAnimation(AppTheme.quickSpring) { selectedQuality = selectedQuality == "A" ? nil : "A" }
                    }
                    filterChip(label: "Gut", icon: "hand.thumbsup.fill", iconColor: AppTheme.teal, isSelected: selectedQuality == "G") {
                        withAnimation(AppTheme.quickSpring) { selectedQuality = selectedQuality == "G" ? nil : "G" }
                    }

                    Rectangle()
                        .fill(AppTheme.divider)
                        .frame(width: 1, height: 20)

                    ForEach(ScoreFilter.allCases, id: \.rawValue) { filter in
                        filterChip(label: filter.label, icon: filter.icon, iconColor: filter.color, isSelected: selectedScoreFilter == filter) {
                            withAnimation(AppTheme.quickSpring) { selectedScoreFilter = selectedScoreFilter == filter ? nil : filter }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            if !dataService.availableStates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: "Alle Bundesländer", isSelected: selectedState == nil) {
                            withAnimation(AppTheme.quickSpring) { selectedState = nil }
                        }
                        ForEach(dataService.availableStates, id: \.self) { state in
                            filterChip(label: state, isSelected: selectedState == state) {
                                withAnimation(AppTheme.quickSpring) { selectedState = selectedState == state ? nil : state }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            if activeFilterCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 12))
                    Text("\(displayLakes.count) Ergebnisse")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    Button {
                        withAnimation(AppTheme.quickSpring) {
                            selectedQuality = nil
                            selectedScoreFilter = nil
                            selectedState = nil
                        }
                    } label: {
                        Text("Filter zurücksetzen")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                }
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 20)
            }
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
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit { isSearchFocused = false }

            if !searchText.isEmpty {
                Button {
                    withAnimation(AppTheme.quickSpring) {
                        searchText = ""
                        selectedQuality = nil
                        selectedScoreFilter = nil
                        selectedState = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(AppTheme.searchBarBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        .padding(.horizontal, 20)
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
                statChip(
                    icon: "star.fill",
                    value: "\(cachedGoodScoreCount)",
                    label: "Guter Score",
                    color: AppTheme.scoreGut
                )
                statChip(
                    icon: "checkmark.seal.fill",
                    value: "\(dataService.lakes.filter { $0.qualityRating?.uppercased() == "A" }.count)",
                    label: "Top Qualität",
                    color: AppTheme.freshGreen
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

    // MARK: - Lake Section (horizontal scroll)

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
                                .frame(width: 200, height: 160)
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
                            .contextMenu { lakeContextMenu(lake) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - All Lakes Section

    private var allLakesSection: some View {
        // Materialise once per render so ForEach and divider check share the same array
        let visibleLakes = Array(displayLakes.prefix(visibleCount))

        return VStack(alignment: .leading, spacing: 14) {
            if !isSearchActive {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.teal)
                    Text("Alle Gewässer")
                        .font(AppTheme.sectionTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()

                    Menu {
                        ForEach(SortOption.allCases, id: \.rawValue) { option in
                            Button {
                                withAnimation(AppTheme.quickSpring) { sortOption = option }
                                Haptics.light()
                            } label: {
                                Label(option.label, systemImage: option.icon)
                            }
                            .disabled(option == .nearest && locationService.userLocation == nil)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sortOption.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(sortOption.label)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.oceanBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.oceanBlue.opacity(0.1), in: Capsule())
                    }

                    Text("\(displayTotalCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.divider, in: Capsule())
                }
                .padding(.horizontal, 20)

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
            }

            LazyVStack(spacing: 2) {
                ForEach(visibleLakes) { lake in
                    Button { selectedLake = lake } label: {
                        LakeListRow(
                            lake: lake,
                            distanceKm: locationService.userLocation.map { lake.distance(from: $0) },
                            isFavourite: favourites.contains { $0.lakeID == lake.id }
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu { lakeContextMenu(lake) }

                    // Use materialized array — O(1), no re-evaluation of displayLakes
                    if lake.id != visibleLakes.last?.id {
                        Divider()
                            .padding(.leading, 74)
                            .padding(.trailing, 20)
                    }
                }
            }
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
            .padding(.horizontal, 16)

            // Progressive "load more" — adds 20 at a time rather than dumping all at once
            if displayTotalCount > visibleCount {
                Button {
                    withAnimation(AppTheme.gentleSpring) { visibleCount += 20 }
                } label: {
                    HStack(spacing: 6) {
                        Text("20 mehr laden (\(displayTotalCount - visibleCount) verbleibend)")
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

    private func filterChip(label: String, icon: String? = nil, iconColor: Color? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : (iconColor ?? AppTheme.textPrimary))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
            }
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

    // MARK: - Recent Lakes Section

    private var recentLakesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Zuletzt angesehen")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentLakes) { recent in
                        Button {
                            if let lake = dataService.lake(withID: recent.id) {
                                selectedLake = lake
                                isSearchFocused = false
                            }
                        } label: {
                            Text(recent.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.oceanBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(AppTheme.oceanBlue.opacity(0.08), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func lakeContextMenu(_ lake: BathingWater) -> some View {
        let isFav = favourites.contains { $0.lakeID == lake.id }

        ShareLink(item: shareText(for: lake)) {
            Label("Teilen", systemImage: "square.and.arrow.up")
        }

        Button {
            Haptics.medium()
            toggleFavourite(lake)
        } label: {
            Label(isFav ? "Favorit entfernen" : "Zu Favoriten", systemImage: isFav ? "heart.slash.fill" : "heart")
        }

        Button {
            openInMaps(lake)
        } label: {
            Label("Route", systemImage: "map.fill")
        }
    }

    private func shareText(for lake: BathingWater) -> String {
        let score = lake.swimScore(weather: weatherService.weatherCache[lake.id])
        var text = "\(lake.name) – Swim Score: \(String(format: "%.1f", score.total))/10 (\(score.level.label))"
        if let temp = lake.currentWaterTemperature {
            text += " – \(String(format: "%.1f°C", temp)) Wasser"
        }
        text += " – \(lake.qualityLabel)"
        if let municipality = lake.municipality {
            text += " (\(municipality))"
        }
        text += "\n🦆 via Flüsse & Seen"
        return text
    }

    private func toggleFavourite(_ lake: BathingWater) {
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

    private func openInMaps(_ lake: BathingWater) {
        let coordinate = lake.coordinate
        guard let url = URL(string: "maps://?q=\(lake.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lake.name)&ll=\(coordinate.latitude),\(coordinate.longitude)") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    HomeView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .environment(WeatherService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
