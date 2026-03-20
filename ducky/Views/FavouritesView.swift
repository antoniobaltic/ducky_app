import SwiftUI
import SwiftData
import CoreLocation

struct FavouritesView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(WeatherService.self) private var weatherService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavouriteItem.addedAt, order: .reverse) var favourites: [FavouriteItem]
    @Query var allVisits: [LakeVisit]
    @State private var selectedLake: BathingWater?
    @State private var shareLake: BathingWater?
    @State private var sortOption: SortOption = .bestScore
    @State private var sortDirection: SortDirection = .descending

    private func liveData(for fav: FavouriteItem) -> BathingWater? {
        dataService.lake(withID: fav.lakeID)
    }

    private var visitedLakeCount: Int {
        Set(allVisits.map(\.lakeID)).count
    }

    private var currentSortPillLabel: String {
        if sortOption == .alphabetical {
            return sortDirection == .ascending ? "A–Z" : "Z–A"
        }
        return sortOption.shortLabel
    }

    private var sortedFavourites: [FavouriteItem] {
        let weather = weatherService.weatherCache
        let liveByID = Dictionary(uniqueKeysWithValues: dataService.lakes.map { ($0.id, $0) })
        var items = favourites

        func name(for fav: FavouriteItem) -> String {
            liveByID[fav.lakeID]?.displayName ?? fav.lakeName
        }

        func sortByNumeric(_ value: (FavouriteItem) -> Double?, ascending: Bool) {
            items.sort { lhs, rhs in
                let left = value(lhs) ?? (ascending ? .infinity : -.infinity)
                let right = value(rhs) ?? (ascending ? .infinity : -.infinity)
                if left == right {
                    let cmp = name(for: lhs).localizedCaseInsensitiveCompare(name(for: rhs))
                    if cmp == .orderedSame { return lhs.lakeID < rhs.lakeID }
                    return cmp == .orderedAscending
                }
                return ascending ? left < right : left > right
            }
        }

        switch sortOption {
        case .bestScore:
            sortByNumeric({ fav in
                guard let lake = liveByID[fav.lakeID] else { return nil }
                return lake.swimScore(weather: weather[lake.id]).total
            }, ascending: sortDirection == .ascending)
        case .nearest:
            sortByNumeric({ fav in
                guard let userLocation = locationService.userLocation,
                      let lake = liveByID[fav.lakeID]
                else { return nil }
                return lake.distance(from: userLocation)
            }, ascending: sortDirection == .ascending)
        case .alphabetical:
            items.sort { lhs, rhs in
                let cmp = name(for: lhs).localizedCaseInsensitiveCompare(name(for: rhs))
                if cmp == .orderedSame { return lhs.lakeID < rhs.lakeID }
                return sortDirection == .ascending ? cmp == .orderedAscending : cmp == .orderedDescending
            }
        case .airTemperature:
            sortByNumeric({ fav in
                guard let lake = liveByID[fav.lakeID] else { return nil }
                return weather[lake.id]?.airTemperature
            }, ascending: sortDirection == .ascending)
        case .waterTemperature:
            sortByNumeric({ fav in
                if let lake = liveByID[fav.lakeID] {
                    return lake.currentWaterTemperature
                }
                return fav.lastKnownTemperature
            }, ascending: sortDirection == .ascending)
        }

        return items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.favouritesGradient
                    .ignoresSafeArea()

                BubbleBackground(color: AppTheme.warmPink)
                    .opacity(0.40)
                    .ignoresSafeArea()

                if favourites.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            favouritesHero
                                .padding(.bottom, 8)

                            sortControls
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                            LazyVStack(spacing: 12) {
                                ForEach(sortedFavourites) { fav in
                                    favouriteRow(fav)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .refreshable {
                        await dataService.refresh()
                        await syncFavouriteSnapshotAndWeather(forceRefresh: true)
                        Haptics.success()
                    }
                    .background {
                        FavouriteHeartFishView()
                            .opacity(0.5)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedLake) { lake in
                LakeDetailView(lake: lake)
            }
            .sheet(item: $shareLake) { lake in
                ShareCardView(
                    lake: lake,
                    weather: weatherService.weatherCache[lake.id]
                )
            }
            .task {
                await dataService.loadData()
                await syncFavouriteSnapshotAndWeather()
            }
        }
    }

    private func syncFavouriteSnapshotAndWeather(forceRefresh: Bool = false) async {
        let liveLakes = favourites.compactMap(liveData)
        for lake in liveLakes {
            _ = await weatherService.fetchWeather(for: lake, forceRefresh: forceRefresh)
        }

        for fav in favourites {
            if let live = liveData(for: fav) {
                fav.lastKnownTemperature = live.currentWaterTemperature
                fav.lastKnownQuality = live.qualityRating
            }
        }
        try? modelContext.save()
    }

    private var favouritesHero: some View {
        HStack(spacing: 12) {
            DuckView(state: .zufrieden, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Deine Bade-Favoriten")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(favourites.count) gespeichert · \(visitedLakeCount > 0 ? "\(visitedLakeCount) \(visitedLakeCount == 1 ? "See" : "Seen") besucht" : "Noch keine Seen besucht")")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var sortControls: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.warmPink)

            Text("Sortierung")
                .font(.system(size: 14, weight: .bold, design: .rounded))
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
                .padding(.vertical, 5)
                .background(AppTheme.oceanBlue.opacity(0.1), in: Capsule())
            }
            .buttonStyle(FavouritesPressableChipButtonStyle())

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
            .buttonStyle(FavouritesPressableChipButtonStyle())

            Text("\(favourites.count)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.divider, in: Capsule())
        }
    }

    // MARK: - Empty State

    @State private var glowPulse = false

    private var emptyState: some View {
        VStack(spacing: 24) {
            // Birds at the top
            BirdsView(skyWidth: UIScreen.main.bounds.width, skyHeight: 80)
                .frame(height: 80)
                .allowsHitTesting(false)

            ZStack {
                // Outer glow circle
                Circle()
                    .fill(AppTheme.warmPink.opacity(0.06))
                    .frame(width: 220, height: 220)
                    .blur(radius: 20)
                    .scaleEffect(glowPulse ? 1.08 : 0.95)

                // Main pink circle
                Circle()
                    .fill(AppTheme.warmPink.opacity(0.10))
                    .frame(width: 180, height: 180)

                FloatingBubblesView(count: 4, color: AppTheme.warmPink.opacity(0.2))
                    .frame(width: 200, height: 200)

                // Floating hearts
                FloatingHeartsView()
                    .frame(width: 200, height: 240)
                    .clipped()

                DuckView(state: .zufrieden, size: 120)
            }

            VStack(spacing: 8) {
                Text("Noch keine Favoriten")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Füge einen See oder ein Gewässer zu deinen\nFavoriten hinzu, um sie hier zu sehen!")
                    .font(AppTheme.bodyText)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                HStack(spacing: 6) {
                    Image(systemName: visitedLakeCount > 0 ? "checkmark.seal.fill" : "checkmark.seal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(visitedLakeCount > 0 ? AppTheme.freshGreen : AppTheme.textSecondary)
                    Text(visitedLakeCount > 0 ? "Du hast \(visitedLakeCount) \(visitedLakeCount == 1 ? "See" : "Seen") besucht!" : "Du hast noch keine Seen besucht.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(visitedLakeCount > 0 ? AppTheme.freshGreen : AppTheme.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Favourite Row

    private func favouriteRow(_ fav: FavouriteItem) -> some View {
        let live = liveData(for: fav)
        let quality = live?.qualityRating ?? fav.lastKnownQuality
        let distanceKm = live.flatMap { lake in
            locationService.userLocation.map { lake.distance(from: $0) }
        }

        return FavouriteSwipeActionRow(onDelete: {
            withAnimation(AppTheme.quickSpring) {
                modelContext.delete(fav)
                try? modelContext.save()
            }
        }) { isTapBlocked in
            Button {
                guard !isTapBlocked else { return }
                guard let live else { return }
                selectedLake = live
            } label: {
                FavouriteRowContent(
                    fav: fav,
                    quality: quality,
                    live: live,
                    distanceKm: distanceKm,
                    isVisited: allVisits.contains { $0.lakeID == fav.lakeID }
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .contextMenu {
                if let lake = liveData(for: fav) {
                    Button { shareLake = lake } label: {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) {
                    removeFavourite(lakeID: fav.lakeID)
                } label: {
                    Label("Favorit entfernen", systemImage: "heart.slash.fill")
                }
                if let lake = liveData(for: fav) {
                    Button { openInMaps(lake) } label: {
                        Label("Route", systemImage: "map.fill")
                    }
                }
            }
        }
    }

    private func removeFavourite(lakeID: String) {
        guard let fav = favourites.first(where: { $0.lakeID == lakeID }) else { return }
        withAnimation(AppTheme.quickSpring) {
            modelContext.delete(fav)
            try? modelContext.save()
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

// MARK: - Extracted row content to support weather fetching

private struct FavouriteRowContent: View {
    let fav: FavouriteItem
    let quality: String?
    let live: BathingWater?
    let distanceKm: Double?
    var isVisited: Bool = false

    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?
    @State private var appear = false

    private var score: SwimScore {
        if let live {
            return live.swimScore(weather: weather)
        }
        return SwimScore.compute(weather: weather, waterTemp: nil, qualityRating: quality, isClosed: false)
    }

    private var scoreDuckState: DuckState {
        score.duckState
    }

    private var scoreDuckBackgroundColor: Color {
        AppTheme.scoreColor(for: score.level)
    }

    var body: some View {
        HStack(spacing: 12) {
            SwimScoreBadge(score: score, size: .medium, isVisited: isVisited)

            VStack(alignment: .leading, spacing: 6) {
                Text(live?.displayName ?? fav.lakeName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                metadataLine

                weatherRow
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            duckyBadge
        }
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 10)
        .scaleEffect(appear ? 1 : 0.98)
        .task {
            if let lake = live {
                weather = await weatherService.fetchWeather(for: lake)
            }
        }
        .onAppear {
            withAnimation(AppTheme.entranceSpring.delay(Double.random(in: 0...0.08))) {
                appear = true
            }
        }
    }

    private var duckyBadge: some View {
        ZStack {
            Circle()
                .fill(scoreDuckBackgroundColor.opacity(0.20))
                .frame(width: 56, height: 56)
            DuckView(state: scoreDuckState, size: 42)
        }
        .fixedSize()
    }

    private var metadataLine: some View {
        HStack(spacing: 4) {
            locationTextLine
            if distanceKm != nil {
                if hasLocationMeta {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                distanceChip
            }
        }
    }

    private var locationTextLine: some View {
        HStack(spacing: 4) {
            if let municipality = municipalityLabel {
                Text(municipality)
                    .font(AppTheme.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let state = stateLabel {
                if municipalityLabel != nil {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text(state)
                    .font(AppTheme.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var municipalityLabel: String? {
        let raw = live?.municipality ?? fav.municipalityName
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private var stateLabel: String? {
        guard let text = live?.shortStateLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }

    private var hasLocationMeta: Bool {
        municipalityLabel != nil || stateLabel != nil
    }

    private var weatherRow: some View {
        HStack(spacing: 6) {
            weatherConditionPill
            temperatureChip(
                icon: "wind",
                iconColor: AppTheme.airTempGreen,
                value: weather?.airTemperature.map { "\($0.formatted(.number.precision(.fractionLength(0))))°C" } ?? "-"
            )
            temperatureChip(
                icon: "drop.fill",
                iconColor: AppTheme.oceanBlue,
                value: live?.currentWaterTemperature.map { "\($0.formatted(.number.precision(.fractionLength(0))))°C" } ?? "-"
            )
            Spacer(minLength: 0)
        }
    }

    private var weatherConditionPill: some View {
        Group {
            if let weather {
                quickConditionChip(
                    icon: weather.conditionSymbol,
                    value: weather.conditionDescription,
                    color: weatherConditionChipStyle(for: weather)
                )
            } else {
                quickConditionChip(
                    icon: "cloud.fill",
                    value: "Unbekannt",
                    color: AppTheme.textSecondary
                )
            }
        }
    }

    private func temperatureChip(icon: String, iconColor: Color, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(iconColor.opacity(0.10), in: Capsule())
    }

    private func weatherConditionChipStyle(for weather: LakeWeather) -> Color {
        guard let code = weather.weatherCode else {
            return AppTheme.textSecondary
        }

        switch code {
        case 0, 1:
            return AppTheme.sunshine
        case 2, 3:
            return AppTheme.textSecondary
        case 45, 48:
            return AppTheme.textSecondary
        case 51, 53, 55:
            return AppTheme.skyBlue
        case 56, 57, 66, 67:
            return AppTheme.lavender
        case 61, 63, 65, 80, 81, 82:
            return AppTheme.oceanBlue
        case 71, 73, 75, 77, 85, 86:
            return AppTheme.lightBlue
        case 95, 96, 99:
            return AppTheme.coral
        default:
            return AppTheme.textSecondary
        }
    }

    private func quickConditionChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.10), in: Capsule())
    }

    @ViewBuilder
    private var distanceChip: some View {
        if let dist = distanceKm {
            HStack(spacing: 2) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                Text("\(dist.formatted(.number.precision(.fractionLength(0)))) km")
                    .font(AppTheme.smallCaption)
            }
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

}

private struct FavouritesPressableChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct FavouriteSwipeActionRow<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: (_ isTapBlocked: Bool) -> Content

    @State private var offsetX: CGFloat = 0
    @State private var isDeleting = false
    @State private var swipeAxis: SwipeAxis = .undecided
    @State private var suppressTap = false
    @State private var tapReleaseTask: Task<Void, Never>?

    private let actionWidth: CGFloat = 86
    private let fullSwipeThreshold: CGFloat = 145

    private enum SwipeAxis {
        case undecided
        case horizontal
        case vertical
    }

    private var isTapBlocked: Bool {
        suppressTap || isDeleting || abs(offsetX) > 1
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                triggerDelete(animatedOffscreen: false)
            } label: {
                Text("Entfernen")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: actionWidth, height: 64)
                .background(AppTheme.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(FavouritesPressableChipButtonStyle())
            .padding(.trailing, 2)
            .opacity(offsetX < -8 ? 1 : 0)

            content(isTapBlocked)
                .offset(x: offsetX)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(swipeGesture)
        .clipped()
        .onDisappear {
            tapReleaseTask?.cancel()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard !isDeleting else { return }
                let translation = value.translation.width
                let vertical = value.translation.height

                if swipeAxis == .undecided {
                    let absX = abs(translation)
                    let absY = abs(vertical)
                    if absX < 12 && absY < 12 { return }

                    // Prefer vertical routing to keep ScrollView behavior natural.
                    if absY > absX * 1.15 {
                        if offsetX < 0 {
                            withAnimation(AppTheme.quickSpring) {
                                offsetX = 0
                            }
                        }
                        swipeAxis = .vertical
                        blockTaps(for: .milliseconds(200))
                        return
                    }

                    // Activate swipe only for deliberate horizontal gestures.
                    guard absX > absY * 1.4, absX > 14 else { return }
                    swipeAxis = .horizontal
                }
                guard swipeAxis == .horizontal else { return }
                blockTaps(for: .milliseconds(250))

                if translation < 0 {
                    offsetX = max(-160, translation)
                } else if offsetX < 0 {
                    offsetX = min(0, -actionWidth + translation)
                }
            }
            .onEnded { value in
                defer { swipeAxis = .undecided }
                guard !isDeleting else { return }
                guard swipeAxis == .horizontal else {
                    blockTaps(for: .milliseconds(160))
                    return
                }
                let translation = value.translation.width
                let predicted = value.predictedEndTranslation.width

                if translation < -fullSwipeThreshold || predicted < -fullSwipeThreshold {
                    triggerDelete(animatedOffscreen: true)
                } else if translation < -(actionWidth * 0.60) {
                    withAnimation(AppTheme.quickSpring) {
                        offsetX = -actionWidth
                    }
                    blockTaps(for: .milliseconds(250))
                } else {
                    withAnimation(AppTheme.quickSpring) {
                        offsetX = 0
                    }
                    blockTaps(for: .milliseconds(200))
                }
            }
    }

    private func triggerDelete(animatedOffscreen: Bool) {
        guard !isDeleting else { return }
        isDeleting = true
        blockTaps(for: .milliseconds(400))
        Haptics.medium()

        if animatedOffscreen {
            withAnimation(AppTheme.quickSpring) {
                offsetX = -420
            }
        }

        let delay: Duration = animatedOffscreen ? .milliseconds(120) : .zero
        Task {
            try? await Task.sleep(for: delay)
            onDelete()
        }
    }

    private func blockTaps(for duration: Duration = .milliseconds(220)) {
        suppressTap = true
        tapReleaseTask?.cancel()

        tapReleaseTask = Task {
            try? await Task.sleep(for: duration)
            suppressTap = false
        }
    }
}

// MARK: - Floating Hearts

private struct FloatingHeartsView: View {
    private struct HeartData: Identifiable {
        let id = UUID()
        let x: CGFloat        // 0…1 relative x
        let size: CGFloat      // 8…16
        let opacity: Double    // 0.15…0.45
        let duration: Double   // 3…6
        let delay: Double      // 0…3
    }

    private let hearts: [HeartData] = (0..<6).map { _ in
        HeartData(
            x: CGFloat.random(in: 0.15...0.85),
            size: CGFloat.random(in: 8...16),
            opacity: Double.random(in: 0.15...0.45),
            duration: Double.random(in: 3.5...6.0),
            delay: Double.random(in: 0...2.5)
        )
    }

    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ForEach(hearts) { heart in
                Image(systemName: "heart.fill")
                    .font(.system(size: heart.size))
                    .foregroundStyle(AppTheme.warmPink.opacity(heart.opacity))
                    .position(
                        x: heart.x * geo.size.width,
                        y: animate ? -20 : geo.size.height * 0.7
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeInOut(duration: heart.duration)
                        .repeatForever(autoreverses: false)
                        .delay(heart.delay),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}

// MARK: - Heart Fish (Favourites background)

private struct FavouriteHeartFishView: View {
    private struct FishInfo {
        let baseX: CGFloat
        let baseY: CGFloat
        let size: CGFloat
        let period: Double
        let range: CGFloat
        let phase: Double
        let opacity: Double
        let goesRight: Bool
    }

    private let fishData: [FishInfo] = [
        .init(baseX: 0.15, baseY: 0.15, size: 16, period: 14, range: 0.22, phase: 0, opacity: 0.40, goesRight: true),
        .init(baseX: 0.75, baseY: 0.25, size: 13, period: 18, range: 0.18, phase: 3, opacity: 0.35, goesRight: false),
        .init(baseX: 0.40, baseY: 0.35, size: 18, period: 16, range: 0.25, phase: 7, opacity: 0.45, goesRight: true),
        .init(baseX: 0.85, baseY: 0.45, size: 11, period: 20, range: 0.15, phase: 5, opacity: 0.30, goesRight: false),
        .init(baseX: 0.25, baseY: 0.55, size: 15, period: 15, range: 0.20, phase: 2, opacity: 0.38, goesRight: true),
        .init(baseX: 0.60, baseY: 0.65, size: 14, period: 17, range: 0.22, phase: 9, opacity: 0.42, goesRight: false),
        .init(baseX: 0.50, baseY: 0.78, size: 17, period: 13, range: 0.24, phase: 4, opacity: 0.35, goesRight: true),
        .init(baseX: 0.10, baseY: 0.88, size: 12, period: 19, range: 0.16, phase: 6, opacity: 0.32, goesRight: false),
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ForEach(0..<fishData.count, id: \.self) { i in
                    let f = fishData[i]
                    let t = now + f.phase
                    let swimX = f.baseX * w + sin(t / f.period * .pi * 2) * f.range * w

                    // Fish using FishShape
                    FishShape()
                        .fill(AppTheme.warmPink.opacity(f.opacity))
                        .frame(width: f.size, height: f.size * 0.55)
                        .scaleEffect(x: f.goesRight ? 1 : -1, y: 1)
                        .position(x: swimX, y: f.baseY * h)

                    // Two hearts rising from each fish
                    heartView(now: now, phase: f.phase, x: swimX - 3, baseY: f.baseY * h, size: 5, cycle: 3.5)
                    heartView(now: now, phase: f.phase + 1.5, x: swimX + 3, baseY: f.baseY * h, size: 4, cycle: 4.0)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func heartView(now: Double, phase: Double, x: CGFloat, baseY: CGFloat, size: CGFloat, cycle: Double) -> some View {
        let progress = (now + phase).truncatingRemainder(dividingBy: cycle) / cycle
        let yOffset = -progress * 28
        let opacity = max(0, 0.55 - progress * 0.75)

        return Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(AppTheme.warmPink.opacity(0.5))
            .opacity(opacity)
            .position(x: x, y: baseY + yOffset - CGFloat(size))
    }
}

#Preview("Empty") {
    let environment = PreviewFixtures.makeEnvironment(useFixtures: true)

    return FavouritesView()
        .environment(environment.dataService)
        .environment(environment.locationService)
        .environment(environment.weatherService)
        .environment(environment.lakeContentService)
        .environment(environment.lakePlaceService)
        .modelContainer(for: [FavouriteItem.self, LakeVisit.self, LakeNote.self], inMemory: true)
}

#Preview("With Favorites") {
    let environment = PreviewFixtures.makeEnvironment(useFixtures: true)

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FavouriteItem.self, configurations: config)
    let context = container.mainContext

    let one = FavouriteItem(
        lakeID: "preview_1",
        lakeName: "Grundlsee",
        municipalityName: "Bad Aussee",
        lastKnownTemperature: 20.8,
        lastKnownQuality: "A"
    )
    let two = FavouriteItem(
        lakeID: "preview_2",
        lakeName: "Wörthersee",
        municipalityName: "Klagenfurt",
        lastKnownTemperature: 23.2,
        lastKnownQuality: "A"
    )
    context.insert(one)
    context.insert(two)

    return FavouritesView()
        .environment(environment.dataService)
        .environment(environment.locationService)
        .environment(environment.weatherService)
        .environment(environment.lakeContentService)
        .environment(environment.lakePlaceService)
        .modelContainer(container)
}
