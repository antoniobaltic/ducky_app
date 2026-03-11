import SwiftUI
import SwiftData

struct ContentView: View {
    private let dataService: DataService
    private let locationService: LocationService
    private let weatherService: WeatherService
    private let lakeContentService: LakeContentService
    private let lakePlaceService: LakePlaceService
    private let tipJarService: TipJarService

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: Int
    @State private var showTipPrompt = false
    @State private var hasRegisteredLaunch = false
    @State private var hasEvaluatedPromptThisSession = false

    @MainActor
    init(
        dataService: DataService = .shared,
        locationService: LocationService = .shared,
        weatherService: WeatherService = .shared,
        lakeContentService: LakeContentService = .shared,
        lakePlaceService: LakePlaceService = .shared,
        tipJarService: TipJarService = .shared
    ) {
        self.dataService = dataService
        self.locationService = locationService
        self.weatherService = weatherService
        self.lakeContentService = lakeContentService
        self.lakePlaceService = lakePlaceService
        self.tipJarService = tipJarService

        let stored = UserDefaults.standard.object(forKey: "preferredStartTab") as? Int ?? 0
        _selectedTab = State(initialValue: Self.clampedTab(stored))
    }

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                mainTabView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.opacity)
            }
        }
        .animation(AppTheme.gentleSpring, value: hasCompletedOnboarding)
        .environment(dataService)
        .environment(locationService)
        .environment(weatherService)
        .environment(lakeContentService)
        .environment(lakePlaceService)
        .environment(tipJarService)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showTipPrompt) {
            TipJarSheet(entryPoint: .prompt)
                .environment(tipJarService)
        }
        .task {
            guard !dataService.isPreviewStubbed else { return }

            tipJarService.configureIfNeeded()

            if !hasRegisteredLaunch {
                hasRegisteredLaunch = true
                tipJarService.registerAppLaunch()
            }

            await tipJarService.loadProductsIfNeeded()
            bootstrapLocationIfNeeded()
            evaluateTipPromptIfNeeded()
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            guard !dataService.isPreviewStubbed else { return }
            bootstrapLocationIfNeeded()
            evaluateTipPromptIfNeeded()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Entdecken", systemImage: "water.waves")
                }
                .tag(0)

            MapView()
                .tabItem {
                    Label("Karte", systemImage: "map.fill")
                }
                .tag(1)

            FavouritesView()
                .tabItem {
                    Label("Favoriten", systemImage: "heart.fill")
                }
                .tag(2)
        }
        .tint(AppTheme.oceanBlue)
    }

    private static func clampedTab(_ value: Int) -> Int {
        min(max(value, 0), 2)
    }

    private func bootstrapLocationIfNeeded() {
        guard hasCompletedOnboarding else { return }
        locationService.requestPermission()
        locationService.startUpdating()
    }

    private func evaluateTipPromptIfNeeded() {
        guard hasCompletedOnboarding else { return }
        guard !hasEvaluatedPromptThisSession else { return }
        guard tipJarService.shouldPresentPrompt() else { return }

        hasEvaluatedPromptThisSession = true
        tipJarService.markPromptShown()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            showTipPrompt = true
        }
    }
}

#Preview {
    let environment = PreviewFixtures.makeEnvironment()

    return ContentView(
        dataService: environment.dataService,
        locationService: environment.locationService,
        weatherService: environment.weatherService,
        lakeContentService: environment.lakeContentService,
        lakePlaceService: environment.lakePlaceService,
        tipJarService: environment.tipJarService
    )
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
