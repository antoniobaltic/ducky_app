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
    @State private var quickActionLake: BathingWater?
    @State private var shareLake: BathingWater?
    @State private var searchText = ""
    @State private var selectedState: String?
    @State private var showSettings = false
    @FocusState private var isSearchFocused: Bool

    // Sort
    @State private var sortOption: SortOption = .bestScore
    @State private var sortDirection: SortDirection = .descending

    // Recent lakes
    @State private var recentLakes: [RecentLake] = []

    // MARK: - Display State
    // These are derived values computed off the render path (via updateDisplayLakes),
    // so that weatherCache updates don't trigger expensive recomputation every frame.
    @State private var displayLakes: [BathingWater] = []
    @State private var displayTotalCount: Int = 0
    @State private var cachedAverageScore: SwimScore? = nil
    @State private var cachedNearbyAverageScore: SwimScore? = nil
    @State private var cachedAverageHeroMessage: String? = nil
    @State private var cachedAverageHeroLevel: SwimScore.Level? = nil
    @State private var visibleCount: Int = 20        // progressive pagination
    @State private var updateTask: Task<Void, Never>?
    @State private var pendingWeatherDrivenRefresh = false
    @State private var sectionsVisible = false

    private struct NearbyPick: Identifiable {
        let lake: BathingWater
        let distanceKm: Double
        let score: SwimScore
        var id: String { lake.id }
    }

    // MARK: - Sort / Filter Enums

    enum SortOption: String, CaseIterable {
        case bestScore, nearest, alphabetical, airTemperature, waterTemperature

        static let displayOrder: [SortOption] = [
            .bestScore,
            .nearest,
            .alphabetical,
            .airTemperature,
            .waterTemperature
        ]

        var label: String {
            switch self {
            case .bestScore:    return "Bester Score"
            case .nearest:      return "Entfernung"
            case .alphabetical: return "A–Z"
            case .airTemperature: return "Lufttemperatur"
            case .waterTemperature: return "Wassertemperatur"
            }
        }

        var icon: String {
            switch self {
            case .bestScore:    return "star.fill"
            case .nearest:      return "location.fill"
            case .alphabetical: return "textformat.abc"
            case .airTemperature: return "wind"
            case .waterTemperature: return "drop.fill"
            }
        }

        var shortLabel: String {
            switch self {
            case .bestScore: return "Score"
            case .nearest: return "Distanz"
            case .alphabetical: return "A-Z"
            case .airTemperature: return "Luft"
            case .waterTemperature: return "Wasser"
            }
        }

        var defaultDirection: SortDirection {
            switch self {
            case .nearest, .alphabetical: return .ascending
            case .bestScore, .airTemperature, .waterTemperature: return .descending
            }
        }
    }

    enum SortDirection {
        case ascending
        case descending

        var symbol: String {
            switch self {
            case .ascending: return "arrow.up"
            case .descending: return "arrow.down"
            }
        }

        mutating func toggle() {
            self = self == .ascending ? .descending : .ascending
        }
    }

    // MARK: - Inexpensive Computed Properties (no weatherCache access)

    private var topNearbyPicks: [NearbyPick] {
        guard let userLocation = locationService.userLocation else { return [] }
        let nearbyCandidates = dataService.lakes
            .map { ($0, $0.distance(from: userLocation)) }
            .sorted { $0.1 < $1.1 }
            .prefix(24)

        let weatherCache = weatherService.weatherCache
        return nearbyCandidates
            .map { entry in
                NearbyPick(
                    lake: entry.0,
                    distanceKm: entry.1,
                    score: entry.0.swimScore(weather: weatherCache[entry.0.id])
                )
            }
            .sorted {
                if $0.score.total == $1.score.total {
                    return $0.distanceKm < $1.distanceKm
                }
                return $0.score.total > $1.score.total
            }
            .prefix(5)
            .map(\.self)
    }

    private var isSearchActive: Bool {
        !searchText.isEmpty
    }

    private var activeFilterCount: Int {
        (selectedState != nil ? 1 : 0)
    }

    private var currentSortPillLabel: String {
        if sortOption == .alphabetical {
            return sortDirection == .ascending ? "A–Z" : "Z–A"
        }
        return sortOption.shortLabel
    }

    private var season: Season { .current }
    private var hasCompleteWeatherCoverage: Bool {
        weatherService.hasCompleteWeather(for: dataService.lakes)
    }
    private var shouldBlockForWeather: Bool {
        !dataService.isLoading && !dataService.lakes.isEmpty && !hasCompleteWeatherCoverage
    }
    private var weatherMissingCount: Int {
        dataService.lakes.filter { weatherService.weatherCache[$0.id] == nil }.count
    }

    private var heroState: DuckState {
        if dataService.isLoading { return .zufrieden }
        if let avg = cachedNearbyAverageScore { return avg.duckState }
        if let avg = cachedAverageScore { return avg.duckState }
        return .zufrieden
    }

    private var heroGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6  { return "Heast, immer no munter?" }
        if hour < 12 { return "Grias di!" }
        if hour < 18 { return "Servas! I hob Flossn-Jucken." }
        return "Guadn Abend!"
    }

    private var heroMessage: String {
        if dataService.isLoading { return "I schnüffel grad durchs Wasser-Orakel... gib ma a Sekundal." }

        let total = dataService.lakes.count
        if total == 0 { return "No koane Seen da? Heast, i find da glei a poar." }
        if shouldBlockForWeather {
            return "I jonglier grad mit \(total) Seen gleichzeitig. Ned hudeln, i rechne no!"
        }
        if weatherService.isUsingStaleCache {
            return "Ranking steht scho, oba i mach im Hintergrund no an Frische-Check."
        }

        if let avg = cachedAverageScore {
            return cachedAverageHeroMessage ?? Self.randomizedHeroMessage(for: avg.level)
        }

        return "\(total) Gewässer san da. I schupf grad die Wetterdaten nach."
    }

    private static func randomizedHeroMessage(for level: SwimScore.Level) -> String {
        switch level {
        case .perfekt:
            return [
                "Oida, heit is Badetag vom Feinsten. REIN DA!",
                "Sonne oben, Laune oben, Flossn oben. GEMMA!",
                "Heit is so guad, sogar mei Quietscheentn macht an Backflip."
            ].randomElement() ?? "Oida, heit is Badetag vom Feinsten. REIN DA!"
        case .gut:
            return [
                "Passt scho richtig guad. *Ducky gibt den offiziellen Nicker*",
                "Ned perfekt, oba gschmeidig. Kann ma sehr wohl machen.",
                "Des fühlt sich nach solidem Sprung ins Wasser an."
            ].randomElement() ?? "Passt scho richtig guad. *Ducky gibt den offiziellen Nicker*"
        case .mittel:
            return [
                "Jo mei, geht so. Kann lustig sein, kann a wild werden.",
                "I bin a bissi skeptisch, oba ned komplett dagegen.",
                "Heit is eher „wennst magst“ statt „muss sein“."
            ].randomElement() ?? "Jo mei, geht so. Kann lustig sein, kann a wild werden."
        case .schlecht:
            return [
                "I glaub i bleib heit lieber im Hoodie und ess a fettes Brot.",
                "Heit schreit alles nach Couch statt Kopfsprung.",
                "Kann ma machen, dann brauchst danach Wärmflasche und Lebensmut."
            ].randomElement() ?? "I glaub i bleib heit lieber im Hoodie und ess a fettes Brot."
        case .warnung:
            return [
                "Na heit fix ned. I zieh die Notbremse.",
                "Heit bleibt der Schnabel trocken. Ende der Diskussion.",
                "Heut is ka Badetag heast. Bleib daham."
            ].randomElement() ?? "Na heit fix ned. I zieh die Notbremse."
        }
    }

    // MARK: - Display Update (debounced, off-render-path)

    /// Recompute displayLakes, optional hero stats, and pagination.
    /// `debounce: true` waits 120 ms — coalesces rapid weather cache ticks.
    private func updateDisplayLakes(
        debounce: Bool = true,
        animated: Bool = false,
        recomputeHeroStats: Bool = true
    ) {
        updateTask?.cancel()
        updateTask = Task { @MainActor in
            if debounce {
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
            }

            // Snapshot the cache so the sort key is stable within this computation
            let cache = weatherService.weatherCache

            var lakes = dataService.search(searchText)
            if let state = selectedState {
                lakes = lakes.filter { $0.state == state }
            }

            let scoreByID = Dictionary(uniqueKeysWithValues: lakes.map { lake in
                (lake.id, lake.swimScore(weather: cache[lake.id]).total)
            })
            let airTempByID = Dictionary(uniqueKeysWithValues: lakes.map { lake in
                (lake.id, cache[lake.id]?.airTemperature)
            })
            let waterTempByID = Dictionary(uniqueKeysWithValues: lakes.map { lake in
                (lake.id, lake.currentWaterTemperature)
            })
            let distanceByID: [String: Double]? = {
                guard sortOption == .nearest, let loc = locationService.userLocation else { return nil }
                return Dictionary(uniqueKeysWithValues: lakes.map { ($0.id, $0.distance(from: loc)) })
            }()

            func sortByNumericValue(
                _ value: (BathingWater) -> Double,
                ascending: Bool
            ) {
                lakes.sort { a, b in
                    let lhs = value(a)
                    let rhs = value(b)
                    if lhs == rhs {
                        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                    }
                    return ascending ? lhs < rhs : lhs > rhs
                }
            }

            switch sortOption {
            case .bestScore:
                sortByNumericValue({ scoreByID[$0.id] ?? -.infinity }, ascending: sortDirection == .ascending)
            case .nearest:
                guard let distances = distanceByID else { break }
                sortByNumericValue({ distances[$0.id] ?? .infinity }, ascending: sortDirection == .ascending)
            case .alphabetical:
                lakes.sort {
                    let cmp = $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                    if cmp == .orderedSame { return $0.id < $1.id }
                    return sortDirection == .ascending ? cmp == .orderedAscending : cmp == .orderedDescending
                }
            case .airTemperature:
                sortByNumericValue({
                    let raw = airTempByID[$0.id, default: nil]
                    return raw ?? (sortDirection == .ascending ? .infinity : -.infinity)
                }, ascending: sortDirection == .ascending)
            case .waterTemperature:
                sortByNumericValue({
                    let raw = waterTempByID[$0.id, default: nil]
                    return raw ?? (sortDirection == .ascending ? .infinity : -.infinity)
                }, ascending: sortDirection == .ascending)
            }

            if animated {
                withAnimation(AppTheme.quickSpring) {
                    displayTotalCount = lakes.count
                    displayLakes = lakes
                }
            } else {
                displayTotalCount = lakes.count
                displayLakes = lakes
            }

            if recomputeHeroStats {
                // Hero stats (scoped to all lakes, not just filtered)
                let allLakes = dataService.lakes

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
                if let level = cachedAverageScore?.level {
                    if cachedAverageHeroLevel != level || cachedAverageHeroMessage == nil {
                        cachedAverageHeroMessage = Self.randomizedHeroMessage(for: level)
                        cachedAverageHeroLevel = level
                    }
                } else {
                    cachedAverageHeroLevel = nil
                    cachedAverageHeroMessage = nil
                }

                // Nearby average: 5 closest lakes → drives home screen Ducky state
                if let userLocation = locationService.userLocation {
                    let nearbyScored = allLakes
                        .map { ($0, $0.distance(from: userLocation)) }
                        .sorted { $0.1 < $1.1 }
                        .prefix(5)
                        .compactMap { entry -> SwimScore? in
                            guard cache[entry.0.id] != nil else { return nil }
                            return entry.0.swimScore(weather: cache[entry.0.id])
                        }
                    if !nearbyScored.isEmpty {
                        let avgTotal = nearbyScored.map(\.total).reduce(0, +) / Double(nearbyScored.count)
                        cachedNearbyAverageScore = nearbyScored.min { abs($0.total - avgTotal) < abs($1.total - avgTotal) }
                    } else {
                        cachedNearbyAverageScore = nil
                    }
                } else {
                    cachedNearbyAverageScore = nil
                }
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageGradient
                    .ignoresSafeArea()

                BubbleBackground(color: AppTheme.skyBlue)
                    .opacity(0.40)
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

                if shouldBlockForWeather {
                    weatherHydrationOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
            .sheet(item: $quickActionLake) { lake in
                QuickLakeActionsSheet(
                    lake: lake,
                    isFavourite: favourites.contains { $0.lakeID == lake.id },
                    onShare: { shareLake = lake },
                    onToggleFavourite: { toggleFavourite(lake) },
                    onRoute: { openInMaps(lake) }
                )
            }
            .sheet(item: $shareLake) { lake in
                ShareCardView(
                    lake: lake,
                    weather: weatherService.weatherCache[lake.id]
                )
            }
        }
        .task {
            await dataService.loadData()
            recentLakes = RecentLake.load()

            // Populate display immediately after data loads (no debounce)
            updateDisplayLakes(debounce: false, animated: false, recomputeHeroStats: true)
            await weatherService.bootstrapWeather(for: dataService.lakes)
            updateDisplayLakes(debounce: false, animated: false, recomputeHeroStats: true)
        }
        // React to filter/sort/data changes — reset pagination on most changes
        .onChange(of: dataService.lakes) {
            visibleCount = 20
            updateDisplayLakes(debounce: false, animated: false, recomputeHeroStats: true)
            Task {
                await weatherService.bootstrapWeather(for: dataService.lakes)
                updateDisplayLakes(debounce: false, animated: false, recomputeHeroStats: true)
            }
        }
        .onChange(of: sortOption) {
            visibleCount = 20
            updateDisplayLakes(debounce: false, animated: true, recomputeHeroStats: false)
        }
        .onChange(of: sortDirection) {
            visibleCount = 20
            updateDisplayLakes(debounce: false, animated: true, recomputeHeroStats: false)
        }
        .onChange(of: selectedState) {
            visibleCount = 20
            updateDisplayLakes(debounce: false, animated: true, recomputeHeroStats: false)
        }
        .onChange(of: searchText) {
            // Debounce search input so we don't refilter on every keystroke
            visibleCount = 20
            updateDisplayLakes(debounce: true, animated: false, recomputeHeroStats: false)
        }
        // Weather updates are debounced; while editing search we defer them for input smoothness.
        .onChange(of: weatherService.cacheRevision) {
            guard !isSearchFocused else {
                pendingWeatherDrivenRefresh = true
                return
            }
            pendingWeatherDrivenRefresh = false
            updateDisplayLakes(debounce: true, animated: false, recomputeHeroStats: true)
        }
        .onChange(of: isSearchFocused) { _, isFocused in
            guard !isFocused, pendingWeatherDrivenRefresh else { return }
            pendingWeatherDrivenRefresh = false
            updateDisplayLakes(debounce: true, animated: false, recomputeHeroStats: true)
        }
        .onAppear {
            guard !sectionsVisible else { return }
            withAnimation(AppTheme.entranceSpring) {
                sectionsVisible = true
            }
        }
    }

    private var weatherHydrationOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.2))
                .ignoresSafeArea()

            VStack(spacing: 14) {
                DuckView(state: .zufrieden, size: 96)

                Text("Score wird vorbereitet")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Wetter für \(weatherService.hydrationCompleted)/\(max(weatherService.hydrationTotal, dataService.lakes.count)) Seen geladen")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)

                ProgressView(value: weatherService.hydrationProgress)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.oceanBlue)
                    .padding(.horizontal, 10)

                if !weatherService.isHydratingAll && weatherMissingCount > 0 {
                    Button {
                        Task {
                            await weatherService.hydrateAllWeather(for: dataService.lakes, forceRefresh: false)
                            updateDisplayLakes(debounce: false, animated: false, recomputeHeroStats: true)
                        }
                    } label: {
                        Text("Erneut versuchen")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.oceanBlue, in: Capsule())
                    }
                }
            }
            .padding(22)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AppTheme.divider, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HomeHeroCardView(
            state: heroState,
            greeting: heroGreeting,
            message: heroMessage,
            error: dataService.error
        )
        .padding(.bottom, 12)
    }

    // MARK: - Content

    private var contentSections: some View {
        VStack(spacing: isSearchActive ? 16 : 28) {
            searchBar
                .opacity(sectionsVisible ? 1 : 0)
                .offset(y: sectionsVisible ? 0 : 12)
                .animation(AppTheme.entranceSpring.delay(0.04), value: sectionsVisible)

            // Recent lakes shown when search is focused but empty
            if isSearchFocused && searchText.isEmpty && !recentLakes.isEmpty && !isSearchActive {
                recentLakesSection
            }

            if isSearchActive {
                searchFilters
                    .opacity(sectionsVisible ? 1 : 0)
                    .offset(y: sectionsVisible ? 0 : 10)
                    .animation(AppTheme.entranceSpring.delay(0.10), value: sectionsVisible)
                allLakesSection
                    .opacity(sectionsVisible ? 1 : 0)
                    .offset(y: sectionsVisible ? 0 : 10)
                    .animation(AppTheme.entranceSpring.delay(0.14), value: sectionsVisible)
            } else {
                if locationService.isAuthorized {
                    nearbyTopScoreSection
                        .opacity(sectionsVisible ? 1 : 0)
                        .offset(y: sectionsVisible ? 0 : 10)
                        .animation(AppTheme.entranceSpring.delay(0.10), value: sectionsVisible)
                }

                WaveDivider(color: AppTheme.teal, height: 24)
                    .opacity(sectionsVisible ? 1 : 0)
                    .animation(AppTheme.smoothEase.delay(0.13), value: sectionsVisible)

                allLakesSection
                    .opacity(sectionsVisible ? 1 : 0)
                    .offset(y: sectionsVisible ? 0 : 10)
                    .animation(AppTheme.entranceSpring.delay(0.16), value: sectionsVisible)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Search Filters

    private var searchFilters: some View {
        VStack(spacing: 10) {
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

            TextField("Gewässer oder Ort suchen...", text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit { isSearchFocused = false }

            if !searchText.isEmpty {
                Button {
                    withAnimation(AppTheme.quickSpring) {
                        searchText = ""
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
        .background(AppTheme.searchBarBackground.opacity(0.98), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.cardStroke.opacity(0.75), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .simultaneousGesture(
            TapGesture().onEnded {
                if !isSearchFocused {
                    isSearchFocused = true
                }
            }
        )
        .shadow(color: .black.opacity(0.14), radius: 14, y: 6)
        .shadow(color: AppTheme.glowOverlay.opacity(0.08), radius: 2, y: 1)
        .padding(.horizontal, 20)
    }

    private var nearbyTopScoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.sunshine)
                Text("Top 5 in deiner Nähe")
                    .font(AppTheme.sectionTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("nach Score")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.cardBackground.opacity(0.8), in: Capsule())
            }
            .padding(.horizontal, 20)

            if topNearbyPicks.isEmpty {
                Text("Lade nahe Gewässer…")
                    .font(AppTheme.bodyText)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topNearbyPicks.enumerated()), id: \.element.id) { index, pick in
                        Button { selectedLake = pick.lake } label: {
                            HStack(spacing: 12) {
                                Text("#\(index + 1)")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(AppTheme.oceanBlue, in: Circle())

                                SwimScoreBadge(score: pick.score, size: .medium)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(pick.lake.displayName)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(AppTheme.textPrimary)
                                            .lineLimit(1)
                                        if favourites.contains(where: { $0.lakeID == pick.lake.id }) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(AppTheme.warmPink)
                                        }
                                    }

                                    HStack(spacing: 4) {
                                        if let municipality = pick.lake.municipality {
                                            Text(municipality)
                                                .lineLimit(1)
                                        }
                                        Text("·")
                                        Text(String(format: "%.1f km", pick.distanceKm))
                                    }
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .highPriorityGesture(quickActionGesture(for: pick.lake))

                        if index < topNearbyPicks.count - 1 {
                            Divider()
                                .padding(.leading, 54)
                        }
                    }
                }
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 14, y: 5)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - All Lakes Section

    private var allLakesSection: some View {
        // Materialise once per render so ForEach and divider check share the same array
        let visibleLakes = Array(displayLakes.prefix(visibleCount))

        return VStack(alignment: .leading, spacing: 14) {
            if !isSearchActive {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.teal)
                    Text("Gewässer")
                        .font(AppTheme.sectionTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer()

                    Menu {
                        ForEach(SortOption.displayOrder, id: \.rawValue) { option in
                            Button {
                                if sortOption == option {
                                    sortDirection.toggle()
                                } else {
                                    sortOption = option
                                    sortDirection = option.defaultDirection
                                }
                                Haptics.light()
                            } label: {
                                HStack {
                                    Label(option.label, systemImage: option.icon)
                                    if sortOption == option {
                                        Image(systemName: sortDirection.symbol)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                }
                            }
                            .disabled(option == .nearest && locationService.userLocation == nil)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if sortOption != .alphabetical {
                                Image(systemName: sortOption.icon)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text(currentSortPillLabel)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                                .allowsTightening(true)
                        }
                        .foregroundStyle(AppTheme.oceanBlue)
                        .frame(minWidth: 76)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.oceanBlue.opacity(0.1), in: Capsule())
                    }

                    Button {
                        Haptics.light()
                        withAnimation(AppTheme.quickSpring) {
                            sortDirection.toggle()
                        }
                    } label: {
                        Image(systemName: sortDirection.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.oceanBlue)
                            .frame(width: 28, height: 26)
                            .background(AppTheme.oceanBlue.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(PressableChipButtonStyle())

                    Text("\(displayTotalCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.divider, in: Capsule())
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: "Alle", isSelected: selectedState == nil) {
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

            LazyVStack(spacing: 2) {
                ForEach(visibleLakes) { lake in
                    Button { selectedLake = lake } label: {
                        LakeListRow(
                            lake: lake,
                            distanceKm: locationService.userLocation.map { lake.distance(from: $0) },
                            isFavourite: favourites.contains { $0.lakeID == lake.id }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .highPriorityGesture(quickActionGesture(for: lake))

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

            if !visibleLakes.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 10))
                    Text("Lange drücken zum Teilen, als Favorit hinzufügen und Route berechnen.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                .padding(.horizontal, 20)
            }

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
        .buttonStyle(PressableChipButtonStyle())
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

    // MARK: - Quick Actions

    private func quickActionGesture(for lake: BathingWater) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .onEnded { _ in
                Haptics.medium()
                quickActionLake = lake
            }
    }

    private func toggleFavourite(_ lake: BathingWater) {
        if let existing = favourites.first(where: { $0.lakeID == lake.id }) {
            modelContext.delete(existing)
        } else {
            let item = FavouriteItem(
                lakeID: lake.id,
                lakeName: lake.displayName,
                municipalityName: lake.municipality,
                lastKnownTemperature: lake.currentWaterTemperature,
                lastKnownQuality: lake.qualityRating
            )
            modelContext.insert(item)
        }
    }

    private func openInMaps(_ lake: BathingWater) {
        let coordinate = lake.coordinate
        guard let url = URL(string: "maps://?q=\(lake.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lake.name)&ll=\(coordinate.latitude),\(coordinate.longitude)") else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}

private struct PressableChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct QuickLakeActionsSheet: View {
    let lake: BathingWater
    let isFavourite: Bool
    let onShare: () -> Void
    let onToggleFavourite: () -> Void
    let onRoute: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "duck.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.sunshine)
                Text(lake.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Spacer()
            }

            Button {
                Haptics.light()
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    onShare()
                }
            } label: {
                actionRow(
                    title: "Teilen",
                    subtitle: "Gewässer teilen.",
                    icon: "square.and.arrow.up",
                    tint: AppTheme.oceanBlue
                )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.medium()
                onToggleFavourite()
                dismiss()
            } label: {
                actionRow(
                    title: isFavourite ? "Favorit entfernen" : "Favorit",
                    subtitle: isFavourite ? "Aus Favoriten löschen." : "Als Favorit speichern.",
                    icon: isFavourite ? "heart.slash.fill" : "heart.fill",
                    tint: AppTheme.warmPink
                )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.medium()
                onRoute()
                dismiss()
            } label: {
                actionRow(
                    title: "Route",
                    subtitle: "In Apple Maps öffnen.",
                    icon: "map.fill",
                    tint: AppTheme.teal
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.height(270)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(26)
    }

    private func actionRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
    }
}

private struct HomeHeroMotionConfig {
    let bubbleCount: Int
    let bubbleColor: Color
    let waveColor: Color
    let waveHeight: CGFloat
    let waveSpeed: Double
    let waveOpacity: Double
    let symbolNames: [String]
    let symbolColor: Color
    let symbolOpacity: Double
    let symbolCount: Int
    let symbolDrift: CGFloat
    let symbolAmplitude: CGFloat

    init(level: SwimScore.Level) {
        switch level {
        case .perfekt:
            bubbleCount = 15
            bubbleColor = .white.opacity(0.32)
            waveColor = AppTheme.scoreColor(for: .perfekt)
            waveHeight = 78
            waveSpeed = 1.35
            waveOpacity = 0.92
            symbolNames = ["sparkles", "sun.max.fill", "drop.fill"]
            symbolColor = AppTheme.sunshine
            symbolOpacity = 0.85
            symbolCount = 7
            symbolDrift = 8
            symbolAmplitude = 10
        case .gut:
            bubbleCount = 12
            bubbleColor = .white.opacity(0.28)
            waveColor = AppTheme.scoreColor(for: .gut)
            waveHeight = 70
            waveSpeed = 1.12
            waveOpacity = 0.86
            symbolNames = ["sparkles", "water.waves", "drop.fill"]
            symbolColor = AppTheme.teal
            symbolOpacity = 0.78
            symbolCount = 6
            symbolDrift = 6
            symbolAmplitude = 8
        case .mittel:
            bubbleCount = 10
            bubbleColor = .white.opacity(0.24)
            waveColor = AppTheme.scoreColor(for: .mittel)
            waveHeight = 62
            waveSpeed = 0.95
            waveOpacity = 0.78
            symbolNames = ["questionmark.circle.fill", "wind", "drop.fill"]
            symbolColor = AppTheme.sunshine
            symbolOpacity = 0.68
            symbolCount = 5
            symbolDrift = 5
            symbolAmplitude = 7
        case .schlecht:
            bubbleCount = 8
            bubbleColor = .white.opacity(0.20)
            waveColor = AppTheme.scoreColor(for: .schlecht)
            waveHeight = 58
            waveSpeed = 0.84
            waveOpacity = 0.72
            symbolNames = ["wind", "snowflake", "thermometer.low"]
            symbolColor = AppTheme.skyBlue
            symbolOpacity = 0.70
            symbolCount = 5
            symbolDrift = 5
            symbolAmplitude = 8
        case .warnung:
            bubbleCount = 7
            bubbleColor = .white.opacity(0.18)
            waveColor = AppTheme.scoreColor(for: .warnung)
            waveHeight = 56
            waveSpeed = 0.76
            waveOpacity = 0.68
            symbolNames = ["exclamationmark.triangle.fill", "xmark.octagon.fill", "hand.raised.fill"]
            symbolColor = AppTheme.coral
            symbolOpacity = 0.90
            symbolCount = 6
            symbolDrift = 7
            symbolAmplitude = 10
        }
    }
}

private struct HomeHeroCardView: View {
    let state: DuckState
    let greeting: String
    let message: String
    var error: String? = nil

    @State private var heroAppear = false

    private var heroBaseColor: Color {
        AppTheme.scoreColor(for: state.scoreLevel)
    }

    private var heroAccentColor: Color {
        switch state.scoreLevel {
        case .perfekt: return AppTheme.sunshine
        case .gut: return AppTheme.skyBlue
        case .mittel: return AppTheme.sunshine
        case .schlecht: return AppTheme.lightBlue
        case .warnung: return AppTheme.sunshine.opacity(0.85)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                AppTheme.detailHeroGradient(for: state.scoreLevel, isDark: false)

                HomeHeroMotionLayer(level: state.scoreLevel)

                LinearGradient(
                    colors: [
                        .white.opacity(0.20),
                        heroAccentColor.opacity(0.14),
                        heroBaseColor.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(height: 310)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .padding(.horizontal, 16)
            .shadow(color: AppTheme.scoreColor(for: state.scoreLevel).opacity(0.28), radius: 20, y: 10)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 130, height: 130)
                        .scaleEffect(heroAppear ? 1.05 : 0.95)
                    DuckView(state: state, size: 110)
                }
                .frame(height: 130)

                Text(greeting)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [heroAccentColor.opacity(0.34), heroBaseColor.opacity(0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.34), lineWidth: 1)
                    )
                    .shadow(color: heroBaseColor.opacity(0.28), radius: 4, y: 2)

                Text(LocalizedStringKey(message))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.90)
                    .allowsTightening(true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        heroBaseColor.opacity(0.40),
                                        heroAccentColor.opacity(0.26),
                                        .white.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.32), lineWidth: 1)
                    )
                    .shadow(color: heroBaseColor.opacity(0.34), radius: 7, y: 3)
                    .shadow(color: .black.opacity(0.10), radius: 1, y: 1)
                    .padding(.horizontal, 26)
                    .fixedSize(horizontal: false, vertical: true)

                if let error {
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
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                heroAppear = true
            }
        }
    }
}

private struct HomeHeroMotionLayer: View {
    let level: SwimScore.Level

    private var config: HomeHeroMotionConfig { .init(level: level) }

    var body: some View {
        ZStack(alignment: .bottom) {
            FloatingBubblesView(count: config.bubbleCount, color: config.bubbleColor)
                .padding(.top, 8)

            HomeHeroFloatingSymbolsView(config: config)
                .padding(.vertical, 12)

            WaterWaveView(baseColor: config.waveColor, height: config.waveHeight, speed: config.waveSpeed)
                .frame(height: 104)
                .opacity(config.waveOpacity)
                .offset(y: 16)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HomeHeroFloatingSymbolsView: View {
    let config: HomeHeroMotionConfig

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<config.symbolCount, id: \.self) { index in
                        let frame = symbolFrame(index: index, time: t, in: proxy.size)
                        Image(systemName: config.symbolNames[index % config.symbolNames.count])
                            .font(.system(size: frame.size, weight: .semibold, design: .rounded))
                            .foregroundStyle(config.symbolColor.opacity(config.symbolOpacity))
                            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                            .position(x: frame.x, y: frame.y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func symbolFrame(index: Int, time: TimeInterval, in size: CGSize) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        let indexValue = Double(index + 1)
        let phase = time * (0.58 + (indexValue * 0.03)) + indexValue * 1.77
        let xUnit = normalized(index: index, salt: 1.11)
        let yUnit = normalized(index: index, salt: 2.73)
        let sizeUnit = normalized(index: index, salt: 5.49)

        let baseX = size.width * (0.12 + 0.76 * xUnit)
        let baseY = size.height * (0.18 + 0.58 * yUnit)
        let driftX = CGFloat(cos(phase)) * config.symbolDrift
        let driftY = CGFloat(sin(phase * 1.3)) * config.symbolAmplitude
        let symbolSize = 10 + (10 * sizeUnit)

        return (x: baseX + driftX, y: baseY + driftY, size: symbolSize)
    }

    private func normalized(index: Int, salt: Double) -> CGFloat {
        let value = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
        return CGFloat(value - floor(value))
    }
}

private struct HomeHeroCardPreviewContainer: View {
    let state: DuckState
    let greeting: String
    let message: String

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.pageGradient
                .ignoresSafeArea()

            HomeHeroCardView(
                state: state,
                greeting: greeting,
                message: message
            )
            .padding(.top, 8)
        }
    }
}

#Preview {
    HomeView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .environment(WeatherService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}

#Preview("Hero Perfekt") {
    HomeHeroCardPreviewContainer(
        state: .begeistert,
        greeting: "Grias di!",
        message: "Oida, heit is Badetag vom Feinsten. REIN DA!"
    )
}

#Preview("Hero Gut") {
    HomeHeroCardPreviewContainer(
        state: .zufrieden,
        greeting: "Grias di!",
        message: "Passt scho richtig guad. *Ducky gibt den offiziellen Nicker*"
    )
}

#Preview("Hero Mittel") {
    HomeHeroCardPreviewContainer(
        state: .zoegernd,
        greeting: "Servas! I hob Flossn-Jucken.",
        message: "I bin a bissi skeptisch, oba ned komplett dagegen."
    )
}

#Preview("Hero Schlecht") {
    HomeHeroCardPreviewContainer(
        state: .frierend,
        greeting: "Guadn Abend!",
        message: "I glaub i bleib heit lieber im Hoodie und ess a fettes Brot."
    )
}

#Preview("Hero Warnung") {
    HomeHeroCardPreviewContainer(
        state: .warnend,
        greeting: "Heast, immer no munter?",
        message: "Na heit fix ned. I zieh die Notbremse."
    )
}
