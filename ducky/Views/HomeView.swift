import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(WeatherService.self) private var weatherService
    @Environment(\.modelContext) private var modelContext
    @Query var favourites: [FavouriteItem]
    @Query var allVisits: [LakeVisit]
    @State private var selectedLake: BathingWater?
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

    // MARK: - Inexpensive Computed Properties (no weatherCache access)

    private var topNearbyPicks: [NearbyPick] {
        guard let userLocation = locationService.userLocation else { return [] }
        let nearbyCandidates = dataService.lakes
            .map { ($0, $0.distance(from: userLocation)) }
            .sorted { $0.1 < $1.1 }
            .prefix(20)

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
        if dataService.isLoading { return .zoegernd }
        if let avg = cachedNearbyAverageScore { return avg.duckState }
        if let avg = cachedAverageScore { return avg.duckState }
        return .zoegernd
    }

    private var heroGreeting: String {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let minute = Calendar.current.component(.minute, from: now)
        let totalMinutes = hour * 60 + minute
        if totalMinutes < 330 { return "Häh, du bist noch wach?" }   // before 5:30
        if totalMinutes < 660 { return "Guten Morgen!" }              // 5:30–10:59
        if hour < 18 { return "Servus!" }                              // 11:00–17:59
        if hour < 23 { return "Guten Abend!" }                        // 18:00–22:59
        return "Häh, du bist noch wach?"                               // 23:00+
    }

    private var heroMessage: String {
        if dataService.isLoading { return "Ich schnüffle gerade noch... einen Moment." }

        let total = dataService.lakes.count
        if total == 0 { return "Keine Seen da? Moment..." }
        if shouldBlockForWeather {
            return "Nicht stressen, ich rechne noch!"
        }
        if weatherService.isUsingStaleCache {
            return "Moment, ich mache im Hintergrund noch einen Frische-Check."
        }

        if let avg = cachedAverageScore {
            return cachedAverageHeroMessage ?? Self.randomizedHeroMessage(for: avg.level)
        }

        return "Ich lade gerade die Wetterdaten nach."
    }

    private static func randomizedHeroMessage(for level: SwimScore.Level) -> String {
        switch level {
        case .perfekt:
            return [
                "Badebedingungen vom Feinsten gerade. REIN DAAAAAA!",
                "Sonne oben, Laune oben, Flossen oben. Ab ins Wasser!",
                "Mega gute Badebedingungen gerade. TU ES. TU ES. TU ES.",
                "AB INS WASSER OIDA! Nahezu perfekte Badebedingungen derzeit!",
                "Wenn du jetzt nicht SOFORT schwimmen gehst, werd ich grantig. REIN DA!"
            ].randomElement() ?? "Badebedingungen vom Feinsten gerade. REIN DAAAAAA!"
        case .gut:
            return [
                "Passt schon richtig gut derzeit. Rein ins Wasser!",
                "Nicht perfekt derzeit, aber schon recht fein. Kann man sehr wohl machen.",
                "Fühlt sich gerade nach einem soliden Sprung ins Wasser an.",
                "Allzu viel besser wird's nicht mehr. Spring rein. Tu es.",
                "Geh eine Runde schwimmen. Vertrau mir. (Ducky gibt keine Gewähr.)"
            ].randomElement() ?? "Passt schon richtig gut derzeit. Rein ins Wasser!"
        case .mittel:
            return [
                "Naja, geht so derzeit. Kann lustig sein, kann auch wild werden.",
                "Ich bin ein bissl skeptisch derzeit, aber nicht komplett dagegen.",
                "Derzeit sind eher so 'wenn du magst' statt 'muss sein' Badebedingungen.",
                "Trau dich halt. So super ist derzeit nicht, aber du bist ja Hardcore.",
                "Als Ente würde ich es wagen. Als Mensch...?"
            ].randomElement() ?? "Naja, geht so derzeit. Kann lustig sein, kann auch wild werden."
        case .schlecht:
            return [
                "Bleib derzeit lieber im Hoodie und iss eine fette Semmel.",
                "Derzeit schreit alles eher nach Couch als Kopfsprung.",
                "Wenn du jetzt baden gehst, brauchst du danach medizinische Betreuung.",
                "Ich würde derzeit nicht baden gehen. Aber you do you.",
                "Ich bin eine Ente und nicht mal ich würde derzeit ins Wasser gehen."
            ].randomElement() ?? "Bleib derzeit lieber im Hoodie und iss eine fette Semmel."
        case .warnung:
            return [
                "Nein, derzeit fix nicht. Ich ziehe die Notbremse.",
                "Derzeit bleibt der Schnabel trocken. Ende der Diskussion.",
                "Absolut kein Badewetter gerade. Bleib lieber daheim.",
                "Bleib daheim. Chill. Kein Badewetter gerade.",
                "Denk gar nicht erst darüber nach. Bleib daheim!"
            ].randomElement() ?? "Nein, derzeit fix nicht. Ich ziehe die Notbremse."
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
                HomeSceneBackground(scoreLevel: heroState.scoreLevel)
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        if !isSearchActive {
                            heroSection
                        }
                        contentSections
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await dataService.refresh()
                    Haptics.success()
                }

                if shouldBlockForWeather {
                    weatherHydrationOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }

                if !isSearchActive {
                    floatingSettingsButton
                }
            }
            .navigationBarHidden(true)
            .iOSNavigationBarStyle()
            .navigationDestination(item: $selectedLake) { lake in
                LakeDetailView(lake: lake)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $shareLake) { lake in
                ShareCardView(
                    lake: lake,
                    weather: weatherService.weatherCache[lake.id]
                )
            }
        }
        .task {
            if dataService.isPreviewStubbed {
                recentLakes = []
                updateDisplayLakes(debounce: false, animated: false, recomputeHeroStats: true)
                return
            }

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

            guard !dataService.isPreviewStubbed else { return }
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

    private var isScoreVerdict: Bool {
        !dataService.isLoading && !dataService.lakes.isEmpty && !shouldBlockForWeather && !weatherService.isUsingStaleCache && cachedAverageScore != nil
    }

    private var floatingSettingsButton: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 12) {
                    if dataService.isLoading {
                        ProgressView()
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(12)
                            .glassEffect(.regular.interactive().tint(.clear), in: .circle)
                    }
                }
                .padding(.trailing, 16)
                .padding(.top, 6)
            }
            Spacer()
        }
    }

    private var heroSection: some View {
        HomeHeroCardView(
            state: heroState,
            greeting: heroGreeting,
            message: heroMessage,
            error: nil,
            isScoreVerdict: isScoreVerdict
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(white: 0.45))

            TextField("Suchen...", text: $searchText, prompt: Text("Suchen...").foregroundStyle(Color(white: 0.45)))
                .font(.system(size: 15, weight: .regular, design: .rounded))
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
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 280)
        .background(.white, in: Capsule())
        .contentShape(Capsule())
        .simultaneousGesture(
            TapGesture().onEnded {
                if !isSearchFocused {
                    Haptics.light()
                    isSearchFocused = true
                }
            }
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }

    private var nearbyTopScoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
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

                                SwimScoreBadge(score: pick.score, size: .medium, isVisited: allVisits.contains { $0.lakeID == pick.lake.id })

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
                                        Text("\(pick.distanceKm.formatted(.number.precision(.fractionLength(1)))) km")
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
                        .contextMenu { lakeContextMenu(for: pick.lake) }

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
                                    .foregroundStyle(sortOption.iconColor)
                            }
                            Text(currentSortPillLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                                .allowsTightening(true)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(minWidth: 76)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.cardBackground.opacity(0.8), in: Capsule())
                    }

                    Button {
                        Haptics.light()
                        withAnimation(AppTheme.quickSpring) {
                            sortDirection.toggle()
                        }
                    } label: {
                        Image(systemName: sortDirection.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 28, height: 26)
                            .background(AppTheme.cardBackground.opacity(0.8), in: Capsule())
                    }
                    .buttonStyle(PressableChipButtonStyle())

                    Text("\(displayTotalCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.cardBackground.opacity(0.8), in: Capsule())
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
                            isFavourite: favourites.contains { $0.lakeID == lake.id },
                            isVisited: allVisits.contains { $0.lakeID == lake.id }
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .contextMenu { lakeContextMenu(for: lake) }

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
                        Text("20 mehr laden")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.oceanBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                isSelected ? AppTheme.oceanBlue : .white,
                in: Capsule()
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

    @ViewBuilder
    private func lakeContextMenu(for lake: BathingWater) -> some View {
        let isFav = favourites.contains { $0.lakeID == lake.id }
        Button { Haptics.light(); shareLake = lake } label: {
            Label("Teilen", systemImage: "square.and.arrow.up")
        }
        Button(role: isFav ? .destructive : nil) {
            toggleFavourite(lake)
        } label: {
            Label(
                isFav ? "Favorit entfernen" : "Favorit",
                systemImage: isFav ? "heart.slash.fill" : "heart.fill"
            )
        }
        Button { openInMaps(lake) } label: {
            Label("Route", systemImage: "map.fill")
        }
    }

    private func toggleFavourite(_ lake: BathingWater) {
        Haptics.light()
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
        try? modelContext.save()
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
                Task {
                    try? await Task.sleep(for: .milliseconds(180))
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


private struct HomeHeroCardView: View {
    let state: DuckState
    let greeting: String
    let message: String
    var error: String? = nil
    var isScoreVerdict: Bool = false

    @State private var heroAppear = false

    private var heroBaseColor: Color {
        AppTheme.scoreColor(for: state.scoreLevel)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Duck in blueish circle (same as onboarding)
            ZStack {
                Circle()
                    .fill(AppTheme.skyBlue.opacity(0.15))
                    .frame(width: 155, height: 155)

                Circle()
                    .stroke(AppTheme.skyBlue.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 185, height: 185)

                FloatingBubblesView(count: 8, color: AppTheme.skyBlue.opacity(0.35))
                    .frame(width: 200, height: 175)
                    .allowsHitTesting(false)

                DuckView(state: state, size: 120)
            }
            .frame(height: 190)

            // Greeting pill — signature blue
            Text(greeting)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AppTheme.oceanBlue, in: Capsule())
                .shadow(color: AppTheme.oceanBlue.opacity(0.25), radius: 6, y: 3)

            // Message bubble — score-colored
            Text(LocalizedStringKey(message))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .minimumScaleFactor(0.90)
                .allowsTightening(true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(heroBaseColor)
                )
                .shadow(color: heroBaseColor.opacity(0.30), radius: 10, y: 4)
                .padding(.horizontal, 30)
                .fixedSize(horizontal: false, vertical: true)

            // "Duckys aktuelle Bade-Einschätzung" — only for score verdicts
            if isScoreVerdict {
                Text("Duckys aktuelle Bade-Einschätzung")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .tracking(0.3)
                    .padding(.top, -6)
            }

            if let error {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                heroAppear = true
            }
        }
    }
}


private struct HomeHeroCardPreviewContainer: View {
    let state: DuckState
    let greeting: String
    let message: String

    var body: some View {
        ZStack(alignment: .top) {
            HomeSceneBackground(scoreLevel: state.scoreLevel)
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
    let environment = PreviewFixtures.makeEnvironment()

    return HomeView()
        .environment(environment.dataService)
        .environment(environment.locationService)
        .environment(environment.weatherService)
        .environment(environment.lakeContentService)
        .environment(environment.lakePlaceService)
        .environment(environment.tipJarService)
        .modelContainer(for: [FavouriteItem.self, LakeVisit.self, LakeNote.self], inMemory: true)
}

#Preview("All Ducky States") {
    ScrollView(.horizontal) {
        HStack(spacing: 0) {
            HomeHeroCardPreviewContainer(
                state: .begeistert,
                greeting: "Servus!",
                message: "Badebedingungen vom Feinsten gerade. REIN DAAAAAA!"
            )
            .frame(width: 390, height: 750)

            HomeHeroCardPreviewContainer(
                state: .zufrieden,
                greeting: "Guten Morgen!",
                message: "Passt schon richtig gut derzeit. Rein ins Wasser!"
            )
            .frame(width: 390, height: 750)

            HomeHeroCardPreviewContainer(
                state: .zoegernd,
                greeting: "Servus!",
                message: "Naja, geht so derzeit. Kann lustig sein, kann auch wild werden."
            )
            .frame(width: 390, height: 750)

            HomeHeroCardPreviewContainer(
                state: .frierend,
                greeting: "Guten Abend!",
                message: "Bleib derzeit lieber im Hoodie und iss eine fette Semmel."
            )
            .frame(width: 390, height: 750)

            HomeHeroCardPreviewContainer(
                state: .warnend,
                greeting: "Häh, du bist noch wach?",
                message: "Nein, derzeit fix nicht. Ich ziehe die Notbremse."
            )
            .frame(width: 390, height: 750)
        }
    }
    .scrollTargetBehavior(.paging)
}

#Preview("Hero Perfekt") {
    HomeHeroCardPreviewContainer(
        state: .begeistert,
        greeting: "Servus!",
        message: "Badebedingungen vom Feinsten gerade. REIN DAAAAAA!"
    )
}

#Preview("Hero Gut") {
    HomeHeroCardPreviewContainer(
        state: .zufrieden,
        greeting: "Guten Morgen!",
        message: "Passt schon richtig gut derzeit. Rein ins Wasser!"
    )
}

#Preview("Hero Mittel") {
    HomeHeroCardPreviewContainer(
        state: .zoegernd,
        greeting: "Servus!",
        message: "Naja, geht so derzeit. Kann lustig sein, kann auch wild werden."
    )
}

#Preview("Hero Schlecht") {
    HomeHeroCardPreviewContainer(
        state: .frierend,
        greeting: "Guten Abend!",
        message: "Bleib derzeit lieber im Hoodie und iss eine fette Semmel."
    )
}

#Preview("Hero Warnung") {
    HomeHeroCardPreviewContainer(
        state: .warnend,
        greeting: "Häh, du bist noch wach?",
        message: "Nein, derzeit fix nicht. Ich ziehe die Notbremse."
    )
}
