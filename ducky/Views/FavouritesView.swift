import SwiftUI
import SwiftData
import CoreLocation

struct FavouritesView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(WeatherService.self) private var weatherService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavouriteItem.addedAt, order: .reverse) var favourites: [FavouriteItem]
    @State private var quickActionTarget: FavouriteQuickActionTarget?
    @State private var selectedLake: BathingWater?
    @State private var shareLake: BathingWater?
    @State private var sortOption: SortOption = .bestScore
    @State private var sortDirection: SortDirection = .descending

    init() {
        _favourites = Query(sort: \FavouriteItem.addedAt, order: .reverse)
    }

    private struct FavouriteQuickActionTarget: Identifiable {
        let lakeID: String
        let lakeName: String
        let municipalityName: String?
        let lake: BathingWater?
        var id: String { lakeID }
    }

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
            case .bestScore: return "Bester Score"
            case .nearest: return "Entfernung"
            case .alphabetical: return "A–Z"
            case .airTemperature: return "Lufttemperatur"
            case .waterTemperature: return "Wassertemperatur"
            }
        }

        var icon: String {
            switch self {
            case .bestScore: return "star.fill"
            case .nearest: return "location.fill"
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

    private func liveData(for fav: FavouriteItem) -> BathingWater? {
        dataService.lake(withID: fav.lakeID)
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
                AppTheme.pageGradient
                    .ignoresSafeArea()

                BubbleBackground(color: AppTheme.warmPink)
                    .opacity(0.32)
                    .ignoresSafeArea()

                if favourites.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            favouritesHero

                            // Subtle wave header
                            WaveDivider(color: AppTheme.warmPink, height: 20)
                                .opacity(0.5)
                                .padding(.bottom, 4)

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
                }
            }
            .navigationTitle("Favoriten")
            .navigationDestination(item: $selectedLake) { lake in
                LakeDetailView(lake: lake)
            }
            .sheet(item: $quickActionTarget) { target in
                FavouritesQuickLakeActionsSheet(
                    lakeName: target.lake?.displayName ?? target.lakeName,
                    isShareAvailable: target.lake != nil,
                    isRouteAvailable: target.lake != nil,
                    onShare: {
                        guard let lake = target.lake else { return }
                        shareLake = lake
                    },
                    onToggleFavourite: {
                        removeFavourite(lakeID: target.lakeID)
                    },
                    onRoute: {
                        guard let lake = target.lake else { return }
                        openInMaps(lake)
                    }
                )
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
    }

    private var favouritesHero: some View {
        HStack(spacing: 12) {
            DuckView(state: .begeistert, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Deine Bade-Favoriten")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(favourites.count) gespeichert")
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

    private var emptyState: some View {
        ZStack {
            // Subtle water background
            VStack {
                Spacer()
                WaterWaveView(baseColor: AppTheme.skyBlue, height: 50, speed: 0.5)
                    .frame(height: 50)
                    .opacity(0.25)
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(AppTheme.warmPink.opacity(0.08))
                        .frame(width: 160, height: 160)

                    FloatingBubblesView(count: 4, color: AppTheme.warmPink.opacity(0.2))
                        .frame(width: 180, height: 180)

                    DuckView(state: .zufrieden, size: 120)
                }

                VStack(spacing: 8) {
                    Text("Noch keine Favoriten")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Füge ein Gewässer zu deinen Favoriten hinzu,\num ihn hier zu sehen!")
                        .font(AppTheme.bodyText)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.warmPink.opacity(0.3))
                    .symbolEffect(.pulse, options: .repeating)
            }
            .padding()
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
                    distanceKm: distanceKm
                )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .highPriorityGesture(quickActionGesture(for: fav))
        }
    }

    private func quickActionGesture(for fav: FavouriteItem) -> some Gesture {
        LongPressGesture(minimumDuration: 0.22)
            .onEnded { _ in
                Haptics.medium()
                quickActionTarget = FavouriteQuickActionTarget(
                    lakeID: fav.lakeID,
                    lakeName: fav.lakeName,
                    municipalityName: fav.municipalityName,
                    lake: liveData(for: fav)
                )
            }
    }

    private func removeFavourite(lakeID: String) {
        guard let fav = favourites.first(where: { $0.lakeID == lakeID }) else { return }
        withAnimation(AppTheme.quickSpring) {
            modelContext.delete(fav)
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
            SwimScoreBadge(score: score, size: .medium)

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
                value: weather?.airTemperature.map { String(format: "%.0f°C", $0) } ?? "-"
            )
            temperatureChip(
                icon: "drop.fill",
                iconColor: AppTheme.oceanBlue,
                value: live?.currentWaterTemperature.map { String(format: "%.0f°C", $0) } ?? "-"
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
                Text(String(format: "%.0f km", dist))
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
    @State private var tapReleaseWorkItem: DispatchWorkItem?

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
            tapReleaseWorkItem?.cancel()
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
                        blockTaps(for: 0.20)
                        return
                    }

                    // Activate swipe only for deliberate horizontal gestures.
                    guard absX > absY * 1.4, absX > 14 else { return }
                    swipeAxis = .horizontal
                }
                guard swipeAxis == .horizontal else { return }
                blockTaps(for: 0.25)

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
                    blockTaps(for: 0.16)
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
                    blockTaps(for: 0.25)
                } else {
                    withAnimation(AppTheme.quickSpring) {
                        offsetX = 0
                    }
                    blockTaps(for: 0.20)
                }
            }
    }

    private func triggerDelete(animatedOffscreen: Bool) {
        guard !isDeleting else { return }
        isDeleting = true
        blockTaps(for: 0.4)
        Haptics.medium()

        if animatedOffscreen {
            withAnimation(AppTheme.quickSpring) {
                offsetX = -420
            }
        }

        let delay: TimeInterval = animatedOffscreen ? 0.12 : 0.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onDelete()
        }
    }

    private func blockTaps(for duration: TimeInterval = 0.22) {
        suppressTap = true
        tapReleaseWorkItem?.cancel()

        let work = DispatchWorkItem {
            suppressTap = false
        }
        tapReleaseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}

private struct FavouritesQuickLakeActionsSheet: View {
    let lakeName: String
    let isShareAvailable: Bool
    let isRouteAvailable: Bool
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
                Text(lakeName)
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
                quickActionRow(
                    title: "Teilen",
                    subtitle: "Gewässer teilen.",
                    icon: "square.and.arrow.up",
                    tint: AppTheme.oceanBlue
                )
            }
            .buttonStyle(.plain)
            .disabled(!isShareAvailable)
            .opacity(isShareAvailable ? 1 : 0.45)

            Button {
                Haptics.medium()
                onToggleFavourite()
                dismiss()
            } label: {
                quickActionRow(
                    title: "Favorit entfernen",
                    subtitle: "Aus Favoriten löschen.",
                    icon: "heart.slash.fill",
                    tint: AppTheme.warmPink
                )
            }
            .buttonStyle(.plain)

            Button {
                Haptics.medium()
                onRoute()
                dismiss()
            } label: {
                quickActionRow(
                    title: "Route",
                    subtitle: "In Apple Maps öffnen.",
                    icon: "map.fill",
                    tint: AppTheme.teal
                )
            }
            .buttonStyle(.plain)
            .disabled(!isRouteAvailable)
            .opacity(isRouteAvailable ? 1 : 0.45)

            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.height(270)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(26)
    }

    private func quickActionRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.divider, lineWidth: 1)
        )
    }
}

#Preview("Empty") {
    let dataService = DataService.shared
    let weatherService = WeatherService.shared
    PreviewFixtures.installAppPreviewState(dataService: dataService, weatherService: weatherService)

    return FavouritesView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .environment(WeatherService.shared)
        .environment(LakeContentService.shared)
        .environment(LakePlaceService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}

#Preview("With Favorites") {
    let dataService = DataService.shared
    let weatherService = WeatherService.shared
    PreviewFixtures.installAppPreviewState(dataService: dataService, weatherService: weatherService)

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
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .environment(WeatherService.shared)
        .environment(LakeContentService.shared)
        .environment(LakePlaceService.shared)
        .modelContainer(container)
}
