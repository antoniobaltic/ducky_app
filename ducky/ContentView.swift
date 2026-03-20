import SwiftUI
import SwiftData
import StoreKit

enum AppTab: Int, CaseIterable {
    case home = 0
    case map = 1
    case favourites = 2
}

struct ContentView: View {
    private let dataService: DataService
    private let locationService: LocationService
    private let weatherService: WeatherService
    private let lakeContentService: LakeContentService
    private let lakePlaceService: LakePlaceService
    private let tipJarService: TipJarService

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: AppTab
    @State private var showTipPrompt = false
    @State private var hasRegisteredLaunch = false
    @State private var hasEvaluatedPromptThisSession = false
    @Environment(\.requestReview) private var requestReview
    @Query private var favourites: [FavouriteItem]
    @Query private var visits: [LakeVisit]

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
        _selectedTab = State(initialValue: AppTab(rawValue: Self.clampedTab(stored)) ?? .home)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 0.92)
        tabAppearance.shadowColor = UIColor(red: 0.70, green: 0.75, blue: 0.90, alpha: 0.30)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
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
            evaluateReviewPrompt()
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            guard !dataService.isPreviewStubbed else { return }
            bootstrapLocationIfNeeded()
            evaluateTipPromptIfNeeded()
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Entdecken", systemImage: "water.waves", value: .home) {
                HomeView()
            }

            Tab("Karte", systemImage: "map.fill", value: .map) {
                MapView()
            }

            Tab("Favoriten", systemImage: "heart.fill", value: .favourites) {
                FavouritesView()
            }
        }
        .tint(AppTheme.oceanBlue)
        .onChange(of: selectedTab) { _, _ in
            Haptics.light()
        }
    }

    private static func clampedTab(_ value: Int) -> Int {
        min(max(value, 0), 2)
    }

    private func bootstrapLocationIfNeeded() {
        guard hasCompletedOnboarding else { return }
        locationService.requestPermission()
        locationService.startUpdating()
    }

    private func evaluateReviewPrompt() {
        guard hasCompletedOnboarding else { return }
        let launches = tipJarService.launchCount
        let hasEngagement = !favourites.isEmpty || !visits.isEmpty
        let lastReviewLaunch = UserDefaults.standard.integer(forKey: "lastReviewPromptLaunch")

        // First prompt: 8+ launches with engagement
        // Second prompt: 25+ launches (regardless)
        // Third prompt: 60+ launches
        let shouldPrompt: Bool
        if lastReviewLaunch == 0 {
            shouldPrompt = launches >= 8 && hasEngagement
        } else if lastReviewLaunch < 25 {
            shouldPrompt = launches >= 25
        } else if lastReviewLaunch < 60 {
            shouldPrompt = launches >= 60
        } else {
            shouldPrompt = false
        }

        guard shouldPrompt else { return }
        UserDefaults.standard.set(launches, forKey: "lastReviewPromptLaunch")

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            requestReview()
        }
    }

    private func evaluateTipPromptIfNeeded() {
        guard hasCompletedOnboarding else { return }
        guard !hasEvaluatedPromptThisSession else { return }
        guard tipJarService.shouldPresentPrompt() else { return }

        hasEvaluatedPromptThisSession = true
        tipJarService.markPromptShown()

        Task {
            try? await Task.sleep(for: .seconds(1.1))
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
        .modelContainer(for: [FavouriteItem.self, LakeVisit.self, LakeNote.self], inMemory: true)
}
