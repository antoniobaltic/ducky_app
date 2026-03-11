import SwiftUI
import SwiftData

struct ContentView: View {
    private let dataService = DataService.shared
    private let locationService = LocationService.shared
    private let weatherService = WeatherService.shared
    private let lakeContentService = LakeContentService.shared
    private let lakePlaceService = LakePlaceService.shared
    private let tipJarService = TipJarService.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: Int
    @State private var showTipPrompt = false
    @State private var hasRegisteredLaunch = false
    @State private var hasEvaluatedPromptThisSession = false

    init() {
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
        .preferredColorScheme(.light)
        .sheet(isPresented: $showTipPrompt) {
            TipJarSheet(entryPoint: .prompt)
                .environment(tipJarService)
        }
        .task {
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
    ContentView()
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
