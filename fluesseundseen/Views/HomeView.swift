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

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero
                        heroDuckSection

                        // Content
                        VStack(spacing: 28) {
                            // Search bar
                            searchBar

                            // Quick stats
                            statsRow

                            // Nearby
                            if locationService.isAuthorized {
                                lakeSection(
                                    title: "In deiner Nähe",
                                    icon: "location.fill",
                                    iconColor: AppTheme.oceanBlue,
                                    lakes: nearbyLakes,
                                    showDistance: true
                                )
                            }

                            // Warmest
                            lakeSection(
                                title: "Am wärmsten",
                                icon: "flame.fill",
                                iconColor: AppTheme.coral,
                                lakes: warmestLakes,
                                showDistance: false
                            )

                            // All lakes section
                            allLakesSection
                        }
                        .padding(.bottom, 40)
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

    // MARK: - Hero Duck Section

    private var heroDuckSection: some View {
        ZStack {
            // Gradient background
            AppTheme.heroGradient
                .frame(height: 280)
                .clipShape(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
                .padding(.horizontal, 16)
                .shadow(color: AppTheme.oceanBlue.opacity(0.25), radius: 20, y: 10)

            VStack(spacing: 12) {
                ZStack {
                    // Animated circles
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .scaleEffect(heroAppear ? 1.1 : 0.9)
                        .blur(radius: 10)

                    DuckView(state: heroState, size: 120)
                }
                .frame(height: 140)

                VStack(spacing: 6) {
                    Text(greeting)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(heroState.line)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                if let error = dataService.error {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text(error)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.15), in: Capsule())
                }
            }
            .padding(.top, 16)
        }
        .padding(.bottom, 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                heroAppear = true
            }
        }
    }

    private var heroState: DuckState {
        guard let warmest = warmestLakes.first else { return .zufrieden }
        return warmest.duckState
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Guten Morgen! Ducky hier." }
        if hour < 18 { return "Hallo! Ducky meldet sich." }
        return "Guten Abend! Ducky wünscht schöne Badezeit."
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
                    searchText = ""
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
                statChip(
                    icon: "thermometer.sun.fill",
                    value: warmestLakes.first?.waterTemperature.map { String(format: "%.0f°C", $0) } ?? "–",
                    label: "Wärmstes",
                    color: AppTheme.coral
                )
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

            // State filter chips
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
                    Button {
                        selectedLake = lake
                    } label: {
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
