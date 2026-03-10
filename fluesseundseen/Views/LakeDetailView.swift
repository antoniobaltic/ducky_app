import SwiftUI
import SwiftData
import MapKit

struct LakeDetailView: View {
    let lake: BathingWater
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(LocationService.self) private var locationService
    @Environment(LakeContentService.self) private var lakeContentService
    @Environment(LakePlaceService.self) private var lakePlaceService
    @Query var favourites: [FavouriteItem]

    init(lake: BathingWater) {
        self.lake = lake
    }

    @Environment(WeatherService.self) private var weatherService
    @State private var weather: LakeWeather?
    @State private var wikipediaContent: LakeWikipediaContent?
    @State private var isLoadingWikipedia = false
    @State private var applePlaceItem: MKMapItem?
    @State private var isLoadingApplePlace = false
    @State private var hasApplePlaceLookupMiss = false
    @State private var showShareCard = false
    @State private var showBacteriaValues = false
    @State private var appear = false
    @State private var selectedHeroQuote = ""

    private var isFavourite: Bool {
        favourites.contains { $0.lakeID == lake.id }
    }

    private var currentScore: SwimScore {
        lake.swimScore(weather: weather)
    }

    private var heroQuote: String {
        if !selectedHeroQuote.isEmpty {
            return selectedHeroQuote
        }
        return heroQuotes(for: currentScore.level).first ?? currentScore.duckState.line
    }

    private func heroQuotes(for level: SwimScore.Level) -> [String] {
        switch level {
        case .perfekt:
            return [
                "Oida, heit is so leiwand, i hupf glei mit Bauchfleck eini!",
                "Sonne, Wasser, vielleicht a Bier. REIN DA!",
                "Des is ka Badetag, des is a Staatsfeiertag für Enten."
            ]
        case .gut:
            return [
                "Passt scho, oida. Ned göttlich, oba ziemlich gschmeidig.",
                "Ducky nickt wie a Kellner im Beisl. Jo, des geht fix.",
                "A bisserl wild, a bisserl geil. I würd's machen."
            ]
        case .mittel:
            return [
                "Heast, kann ma machen, muss ma aber ned.",
                "Da Bademeister schaut skeptisch, i schau skeptisch, sogar die Badehosn schaut skeptisch.",
                "Ziemlich mid. Aba manchmal muss ma a Risiko gehn."
            ]
        case .schlecht:
            return [
                "Brrr, oida. Des Wasser gibt da instant Gänsehaut am Popsch.",
                "Do geh i nur mit Wärmeflasche and guada Versicherung eini.",
                "Wennst do reingehst, brauchst danach an Tee und a Lebensentscheidung."
            ]
        case .warnung:
            return [
                "Na sicher ned. Des is ka See, des is a Fehlermeldung mit Ufer.",
                "Do zieh i die Notbremse. Oida, heit bleib ma trocken!",
                "Do wüst eini? Na fix net. Geh ma ham Playstation zocken."
            ]
        }
    }

    private func randomHeroQuote(for level: SwimScore.Level) -> String {
        heroQuotes(for: level).randomElement() ?? currentScore.duckState.line
    }

    private var quoteBaseColor: Color {
        AppTheme.scoreColor(for: currentScore.level)
    }

    private var quoteAccentColor: Color {
        switch currentScore.level {
        case .perfekt: return AppTheme.sunshine
        case .gut: return AppTheme.skyBlue
        case .mittel: return AppTheme.sunshine
        case .schlecht: return AppTheme.lightBlue
        case .warnung: return AppTheme.sunshine.opacity(0.85)
        }
    }

    private var heroTextPrimary: Color {
        colorScheme == .dark ? .black.opacity(0.94) : .black.opacity(0.88)
    }

    private var heroTextSecondary: Color {
        colorScheme == .dark ? .black.opacity(0.78) : .black.opacity(0.70)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentSection
            }
        }
        .background(
            ZStack(alignment: .top) {
                AppTheme.pageGradient
                AppTheme.detailPageGradient(for: currentScore.level, isDark: colorScheme == .dark)
                BubbleBackground(color: AppTheme.scoreColor(for: currentScore.level))
                    .opacity(0.20)
                LinearGradient(
                    colors: [.clear, AppTheme.pageBackground.opacity(0.80)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .ignoresSafeArea()
            }
            .ignoresSafeArea()
        )
        .ignoresSafeArea(edges: .top)
        .iOSNavigationBarInline()
        #if os(iOS)
        .toolbarBackground(.hidden, for: .navigationBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .iOSTopBarTrailing) {
                HStack(spacing: 4) {
                    Button { showShareCard = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    Button { toggleFavourite() } label: {
                        Image(systemName: isFavourite ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isFavourite ? AppTheme.warmPink : .primary)
                            .symbolEffect(.bounce, value: isFavourite)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareCard) {
            ShareCardView(lake: lake, weather: weather)
        }
        .task {
            isLoadingWikipedia = true
            isLoadingApplePlace = true
            async let weatherTask = weatherService.fetchWeather(for: lake)
            async let wikipediaTask = lakeContentService.fetchWikipediaContent(for: lake)
            async let placeTask = lakePlaceService.fetchPlace(for: lake)

            weather = await weatherTask
            wikipediaContent = await wikipediaTask
            applePlaceItem = await placeTask
            isLoadingWikipedia = false
            isLoadingApplePlace = false
            hasApplePlaceLookupMiss = applePlaceItem == nil
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
            selectedHeroQuote = randomHeroQuote(for: currentScore.level)
            RecentLake.add(RecentLake(id: lake.id, name: lake.displayName))
        }
        .onChange(of: currentScore.level) { _, newLevel in
            selectedHeroQuote = randomHeroQuote(for: newLevel)
        }
    }

    // MARK: - Hero Section

    private var heroConditionLabel: String {
        switch currentScore.level {
        case .perfekt: return "Perfekte Badebedingungen"
        case .gut: return "Gute Badebedingungen"
        case .mittel: return "Mittelmäßige Badebedingungen"
        case .schlecht: return "Schlechte Badebedingungen"
        case .warnung: return "Kritische Badebedingungen"
        }
    }

    private var heroSection: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 80)

            SwimScoreBadge(score: currentScore, size: .hero, showHeroDetails: false)
                .scaleEffect(appear ? 1 : 0.8)
                .opacity(appear ? 1 : 0)
                .padding(.bottom, 8)

            Text(heroConditionLabel)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.scoreColor(for: currentScore.level))
                .multilineTextAlignment(.center)
                .padding(.bottom, 14)

            // Name + location
            VStack(spacing: 6) {
                Text(lake.displayName)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(heroTextPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    if let municipality = lake.municipality {
                        Text(municipality)
                    }
                    if let state = lake.state {
                        Text("·")
                        Text(state)
                    }
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(heroTextSecondary)

                if lake.isClosed {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Gesperrt")
                        if let reason = lake.closureReason, !reason.isEmpty {
                            Text("– \(reason)")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AppTheme.coral, in: Capsule())
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 14)

            // Temperature display: Air + Water side by side
            HStack(alignment: .top, spacing: 20) {
                heroTemperatureColumn(
                    icon: "wind",
                    iconColor: AppTheme.airTempGreen,
                    label: "Lufttemp."
                ) {
                    if let airTemp = weather?.airTemperature {
                        heroNumericTemperatureValue(
                            valueText: String(format: "%.0f", airTemp),
                            color: AppTheme.airTempGreen
                        )
                    } else {
                        heroUnknownTemperatureValue
                    }
                }

                heroTemperatureColumn(
                    icon: "drop.fill",
                    iconColor: AppTheme.oceanBlue,
                    label: "Wassertemp.",
                    footnote: lake.currentWaterTemperature == nil ? "(Messungen: Juni bis August)" : nil
                ) {
                    if let waterTemp = lake.currentWaterTemperature {
                        heroNumericTemperatureValue(
                            valueText: String(format: "%.1f", waterTemp),
                            color: AppTheme.oceanBlue
                        )
                    } else {
                        Text("Unbekannt")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue.opacity(0.85))
                    }
                }
            }
            .padding(.bottom, 16)

            // Ducky + quote at the bottom of the hero
            HStack(alignment: .center, spacing: 10) {
                DuckView(state: currentScore.duckState, size: 50)
                    .scaleEffect(appear ? 1 : 0.7)
                    .opacity(appear ? 1 : 0)

                Text(heroQuote)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        quoteBaseColor.opacity(0.54),
                                        quoteAccentColor.opacity(0.42),
                                        quoteBaseColor.opacity(0.40)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.34), lineWidth: 1)
                    )
                    .shadow(color: quoteBaseColor.opacity(0.32), radius: 7, y: 3)
                    .shadow(color: .black.opacity(0.10), radius: 1, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 24)
        .background {
            ZStack(alignment: .bottom) {
                AppTheme.detailHeroGradient(for: currentScore.level, isDark: colorScheme == .dark)

                // Floating bubbles
                FloatingBubblesView(count: 5, color: .white.opacity(0.25))
                    .allowsHitTesting(false)

                // Wave at bottom of hero
                WaterWaveView(baseColor: AppTheme.pageBackground, height: 30, speed: 0.6)
                    .frame(height: 30)
                    .offset(y: 14)
                    .allowsHitTesting(false)
            }
        }
    }

    private func heroTemperatureColumn<Content: View>(
        icon: String,
        iconColor: Color,
        label: String,
        footnote: String? = nil,
        @ViewBuilder valueContent: () -> Content
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)

            valueContent()
                .frame(height: 46)

            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(heroTextSecondary)

            Text(footnote ?? " ")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(heroTextSecondary.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .opacity(footnote == nil ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
    }

    private func heroNumericTemperatureValue(valueText: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 2) {
            Text(valueText)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text("°C")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(color.opacity(0.7))
                .padding(.top, 5)
        }
    }

    private var heroUnknownTemperatureValue: some View {
        Text("—")
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundStyle(heroTextSecondary.opacity(0.55))
    }

    // MARK: - Content

    private var contentSection: some View {
        VStack(spacing: 16) {
            quickConditionsCard

            if let wikipediaContent {
                wikipediaCard(content: wikipediaContent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isLoadingWikipedia {
                wikipediaLoadingCard
                    .transition(.opacity)
            }

            appleMapsCombinedCard

            // Weather (always try to show)
            if let weather {
                weatherCard(weather)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            gesundheitCard

            // Score breakdown — at the very bottom
            ScoreBreakdownView(score: currentScore)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 40)
    }

    private var quickConditionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "water.waves")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.oceanBlue)
                Text("Auf einen Blick")
                    .font(AppTheme.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            // Flow layout: chips wrap to a new row automatically when the
            // weather condition text is long (e.g. "Überwiegend bewölkt").
            ChipFlowLayout(spacing: 8) {
                if let weather {
                    quickConditionChip(
                        icon: weather.conditionSymbol,
                        value: weather.conditionDescription,
                        color: weatherConditionChipStyle(for: weather)
                    )
                }
                if let weather, let airTemp = weather.airTemperature {
                    quickConditionChip(
                        icon: "wind",
                        value: String(format: "Luft: %.0f°C", airTemp),
                        color: AppTheme.airTempGreen
                    )
                }
                if let waterTemp = lake.currentWaterTemperature {
                    quickConditionChip(
                        icon: "drop.fill",
                        value: String(format: "Wasser: %.1f°C", waterTemp),
                        color: AppTheme.oceanBlue
                    )
                } else {
                    quickConditionChip(
                        icon: "drop.fill",
                        value: "Wasser: Unbek.",
                        color: AppTheme.oceanBlue
                    )
                }
                if let distance = locationService.userLocation.map({ lake.distance(from: $0) }) {
                    quickConditionChip(
                        icon: "location.fill",
                        value: String(format: "%.1f km entfernt", distance),
                        color: AppTheme.teal
                    )
                }
            }
        }
        .appCard()
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

    // MARK: - Chip Flow Layout

    /// A Layout that arranges chips left-to-right and wraps to the next row
    /// when the available width is exhausted — like CSS `flex-wrap: wrap`.
    struct ChipFlowLayout: Layout {
        var spacing: CGFloat = 8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let result = flow(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews)
            return result.size
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let result = flow(in: bounds.width, subviews: subviews)
            for (index, frame) in result.frames.enumerated() {
                subviews[index].place(
                    at: CGPoint(x: frame.minX + bounds.minX, y: frame.minY + bounds.minY),
                    proposal: ProposedViewSize(frame.size)
                )
            }
        }

        private struct FlowResult {
            var size: CGSize = .zero
            var frames: [CGRect] = []
        }

        private func flow(in maxWidth: CGFloat, subviews: Subviews) -> FlowResult {
            var result = FlowResult()
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            var rowMaxX: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    y += rowHeight + spacing
                    x = 0
                    rowHeight = 0
                }
                result.frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                rowMaxX = max(rowMaxX, x - spacing)
            }

            result.size = CGSize(width: rowMaxX, height: y + rowHeight)
            return result
        }
    }

    private func quickConditionChip(
        icon: String,
        value: String,
        color: Color
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.10), in: Capsule())
    }

    private var wikipediaLoadingCard: some View {
        HStack(spacing: 10) {
            wikipediaIcon
            VStack(alignment: .leading, spacing: 4) {
                Text("Über den See")
                    .font(AppTheme.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Ducky sucht den passenden Wikipedia-Eintrag …")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            ProgressView()
                .tint(AppTheme.oceanBlue)
        }
        .appCard()
        .shimmer()
    }

    private func wikipediaCard(content: LakeWikipediaContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                wikipediaIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text("Über den See")
                        .font(AppTheme.cardTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(content.pageTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()

                Button {
                    triggerLightHaptic()
                    openInSystemBrowser(content.pageURL)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Browser")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(AppTheme.oceanBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.oceanBlue.opacity(0.12), in: Capsule())
            }

            Text(content.summary)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCard()
        .background(
            LinearGradient(
                colors: [AppTheme.oceanBlue.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
        )
    }

    private var wikipediaIcon: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [AppTheme.oceanBlue, AppTheme.skyBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .overlay(
                Text("W")
                    .font(.system(size: 14, weight: .heavy, design: .serif))
                    .foregroundStyle(.white)
            )
            .shadow(color: AppTheme.oceanBlue.opacity(0.22), radius: 6, y: 2)
    }

    private func openInSystemBrowser(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                openURL(url)
            }
        }
        #else
        openURL(url)
        #endif
    }

    private func triggerLightHaptic() {
        #if canImport(UIKit)
        Haptics.light()
        #endif
    }

    private var appleMapsCombinedCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header — always visible; shows matched POI name as subtitle when found,
            // small spinner while the lookup is in flight.
            HStack(spacing: 10) {
                appleMapsIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Maps")
                        .font(AppTheme.cardTitle)
                        .foregroundStyle(AppTheme.textPrimary)
                    if isLoadingApplePlace {
                        Text("Suche passenden Eintrag …")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else if let name = applePlaceItem?.name, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isLoadingApplePlace {
                    ProgressView()
                        .tint(AppTheme.teal)
                        .scaleEffect(0.85)
                }
            }

            // Extra info rows — only shown when a POI was matched and carries that data.
            // "Ort" is intentionally omitted (visible elsewhere in the app).
            // Opening times are available in the Maps app itself via the route button.
            if let place = applePlaceItem {
                appleMapsMetadataBlock(place: place)
            }

            // Map — always uses the lake's own AGES GPS coordinates as ground truth.
            mapCard

            // Route button — always functional.
            // When a POI was matched: opens Maps with the full place card
            // (opening hours, reviews, photos etc. via Maps' own database).
            // When no POI found: routes to AGES coordinates directly.
            routeButton
        }
        .appCard()
        .background(
            LinearGradient(
                colors: [AppTheme.teal.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
        )
    }

    private var appleMapsIcon: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [AppTheme.teal, AppTheme.skyBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
            .overlay(
                Image(systemName: "map.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            )
            .shadow(color: AppTheme.teal.opacity(0.22), radius: 6, y: 2)
    }

    @ViewBuilder
    private func appleMapsMetadataBlock(place: MKMapItem) -> some View {
        let phone = place.phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let websiteURL = place.url
        let websiteDisplay = websiteURL?.host ?? websiteURL?.absoluteString
        let address = formattedAddress(from: place)

        let hasPhone = phone != nil && !phone!.isEmpty
        let hasWebsite = websiteDisplay != nil && !websiteDisplay!.isEmpty
        let hasAddress = address != nil

        if hasPhone || hasWebsite || hasAddress {
            VStack(alignment: .leading, spacing: 8) {
                if let address {
                    appleMapsMetaRow(icon: "mappin.circle.fill", label: "Adresse", value: address)
                }
                if let phone, !phone.isEmpty {
                    appleMapsMetaRow(icon: "phone.fill", label: "Telefon", value: phone)
                }
                if let websiteDisplay, !websiteDisplay.isEmpty {
                    appleMapsMetaRow(icon: "globe", label: "Website", value: websiteDisplay)
                }
            }
        }
    }

    private func formattedAddress(from place: MKMapItem) -> String? {
        if let singleLine = place.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true),
           !singleLine.isEmpty {
            return singleLine
        }
        if let shortAddress = place.address?.shortAddress, !shortAddress.isEmpty {
            return shortAddress
        }
        return place.address?.fullAddress
    }

    private func appleMapsMetaRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.teal)
            Text("\(label):")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Weather Card

    private func weatherCard(_ weather: LakeWeather) -> some View {
        VStack(spacing: 14) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.multicolor)
                Text("Wetter vor Ort")
                    .font(AppTheme.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Aktuell")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.freshGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.freshGreen.opacity(0.12), in: Capsule())
                Spacer()
            }

            // Weather condition pill — matches "Auf einen Blick" chip style
            HStack {
                quickConditionChip(
                    icon: weather.conditionSymbol,
                    value: weather.conditionDescription,
                    color: weatherConditionChipStyle(for: weather)
                )
                Spacer()
            }

            HStack(spacing: 8) {
                if let airTemp = weather.airTemperature {
                    weatherStat(
                        icon: "wind",
                        value: String(format: "%.0f°C", airTemp),
                        label: "Lufttemperatur",
                        color: AppTheme.airTempGreen
                    )
                }
                if let uv = weather.uvIndex {
                    weatherStat(
                        icon: "sun.max.fill",
                        value: "\(uv)",
                        label: "UV-Index",
                        color: AppTheme.sunshine,
                        valueColor: .black.opacity(0.78),
                        labelColor: .black.opacity(0.66)
                    )
                }
                if let feels = weather.feelsLike {
                    weatherStat(
                        icon: "person.fill",
                        value: String(format: "%.0f°C", feels),
                        label: "Gefühlt",
                        color: AppTheme.lavender
                    )
                }
            }

            HStack(spacing: 8) {
                if let wind = weather.windSpeed {
                    weatherStat(
                        icon: "wind",
                        value: String(format: "%.0f km/h", wind),
                        label: "Wind",
                        color: AppTheme.skyBlue
                    )
                }
                if let precip = weather.precipitationProbability {
                    weatherStat(
                        icon: "cloud.rain.fill",
                        value: "\(precip)%",
                        label: "Niederschlag",
                        color: AppTheme.oceanBlue
                    )
                }
            }

            // 5-day forecast strip
            if !weather.forecast.isEmpty {
                Divider()
                    .padding(.top, 2)
                forecastStrip(weather.forecast)
            }
        }
        .appCard()
        .background(
            LinearGradient(
                colors: [AppTheme.skyBlue.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
        )
    }

    private func weatherStat(
        icon: String,
        value: String,
        label: String,
        color: Color,
        valueColor: Color = AppTheme.textPrimary,
        labelColor: Color = AppTheme.textSecondary
    ) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(labelColor)
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .padding(.vertical, 6)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Forecast Strip

    private func forecastStrip(_ days: [ForecastDay]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: 5) {
                    Text(index == 0 ? "Heute" : index == 1 ? "Morgen" : dayAbbreviation(from: day.date))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)

                    forecastIcon(symbol: day.conditionSymbol)
                        .frame(height: 22)

                    Text(String(format: "%.0f°", day.tempMax))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(String(format: "%.0f°", day.tempMin))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.65))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    index == 0
                        ? AppTheme.skyBlue.opacity(0.10)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
        }
    }

    /// Renders a forecast weather icon with proper layered colouring.
    /// - Pure sun symbols → single sunshine yellow.
    /// - Cloud+sun symbols (cloud.sun.fill etc.) → palette: skyBlue cloud + sunshine sun.
    /// - Everything else → single contrasting colour via forecastIconColor().
    @ViewBuilder
    private func forecastIcon(symbol: String) -> some View {
        let hasSun   = symbol.contains("sun")
        let hasCloud = symbol.contains("cloud")

        if hasSun && hasCloud {
            // Two-layer palette: cloud in blue, sun peeking out in yellow
            Image(systemName: symbol)
                .font(.system(size: 17))
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppTheme.skyBlue, AppTheme.sunshine)
        } else {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(forecastIconColor(for: symbol))
        }
    }

    /// Single-colour fallback for symbols that don't mix cloud and sun layers.
    private func forecastIconColor(for symbol: String) -> Color {
        if symbol.hasPrefix("sun") {
            return AppTheme.sunshine          // yellow
        }
        if symbol.contains("bolt") || symbol.contains("thunder") {
            return AppTheme.coral             // orange-red for storms
        }
        if symbol.contains("snow") || symbol.contains("sleet") {
            return AppTheme.lavender          // light purple for snow/sleet
        }
        if symbol.contains("fog") {
            return AppTheme.textSecondary     // muted grey for fog
        }
        // All plain cloud variants (cloud.fill, cloud.rain, cloud.drizzle, etc.)
        return AppTheme.skyBlue
    }

    private func dayAbbreviation(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "de_AT")
        guard let date = formatter.date(from: dateString) else { return "" }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayFormatter.locale = Locale(identifier: "de_AT")
        return dayFormatter.string(from: date).capitalized
    }

    // MARK: - Gesundheit Card (Wasserqualität + Bakteriologie + Sichttiefe)

    private var gesundheitCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.freshGreen)
                Text("Gesundheit")
                    .font(AppTheme.cardTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }
            .padding(.bottom, 14)

            // ── Wasserqualität ──────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(lake.qualityColor)
                Text("Wasserqualität")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(lake.qualityLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(lake.qualityColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(lake.qualityColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // ── Sichttiefe (optional) ──────────────────────────────────
            if let depth = lake.visibilityDepth {
                Divider()
                    .padding(.vertical, 12)

                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.skyBlue)
                    Text("Sichttiefe")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f m", depth))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.skyBlue)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.divider)
                            .frame(width: 56, height: 5)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.skyBlue, AppTheme.oceanBlue],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: min(CGFloat(depth / 8.0) * 56, 56), height: 5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.skyBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Divider()
                .padding(.vertical, 12)

            // ── Bakteriologie ──────────────────────────────────────────
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "allergens")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.teal)
                    Text("Bakteriologie")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Button {
                        withAnimation(AppTheme.quickSpring) { showBacteriaValues.toggle() }
                    } label: {
                        Text(showBacteriaValues ? "Ausblenden" : "Details")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.oceanBlue.opacity(0.10), in: Capsule())
                    }
                }

                TrafficLightRow(
                    label: "E.Coli",
                    value: lake.eColi.map { String(format: "%.0f KBE/100ml", $0) },
                    status: lake.eColiStatus,
                    showValue: showBacteriaValues
                )

                Divider()

                TrafficLightRow(
                    label: "Enterokokken",
                    value: lake.enterococci.map { String(format: "%.0f KBE/100ml", $0) },
                    status: lake.enterococciStatus,
                    showValue: showBacteriaValues
                )
            }

            // ── Footer: date + attribution ─────────────────────────────
            if let date = lake.measurementDate {
                Divider()
                    .padding(.vertical, 10)
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Gemessen am \(date)")
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 10))
                        Text("AGES")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                }
            } else {
                Divider()
                    .padding(.vertical, 10)
                HStack(spacing: 4) {
                    Image(systemName: "building.columns")
                        .font(.system(size: 10))
                    Text("Daten: AGES Badegewässerdatenbank")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
            }
        }
        .appCard()
        .background(
            LinearGradient(
                colors: [AppTheme.freshGreen.opacity(0.07), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
        )
    }

    // MARK: - Map Card

    private var mapCard: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: lake.coordinate,
            latitudinalMeters: 3_500,
            longitudinalMeters: 3_500
        ))) {
            Marker(lake.displayName, coordinate: lake.coordinate)
                .tint(AppTheme.oceanBlue)
        }
        .allowsHitTesting(false)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    // MARK: - Route Button

    private var routeButton: some View {
        Button { openInMaps(using: applePlaceItem) } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                Text("Route in Apple Maps")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.oceanBlue, in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
            .shadow(color: AppTheme.oceanBlue.opacity(0.3), radius: 10, y: 5)
        }
    }

    // MARK: - Favourite

    private var favouriteButton: some View {
        Button { toggleFavourite() } label: {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFavourite ? AppTheme.warmPink : .primary)
                .symbolEffect(.bounce, value: isFavourite)
        }
    }

    // MARK: - Actions

    private func toggleFavourite() {
        triggerMediumHaptic()
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

    private func triggerMediumHaptic() {
        #if canImport(UIKit)
        Haptics.medium()
        #endif
    }

    private func openInMaps(using mapItem: MKMapItem?) {
        if let mapItem {
            // When a POI was matched, open the full place card in Maps.
            // This gives the user opening hours, reviews, photos etc. from Maps' database.
            #if os(iOS)
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
            #else
            mapItem.openInMaps(launchOptions: nil)
            #endif
        } else {
            // Fallback: route to the lake's AGES coordinates via URL scheme.
            guard let routeURL = coordinateFallbackRouteURL() else { return }
            #if os(iOS)
            UIApplication.shared.open(routeURL, options: [:]) { success in
                if !success { openURL(routeURL) }
            }
            #else
            NSWorkspace.shared.open(routeURL)
            #endif
        }
    }

    private func coordinateFallbackRouteURL() -> URL? {
        let c = lake.coordinate
        let encodedName = lake.name
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lake.name
        return URL(string: "https://maps.apple.com/?daddr=\(c.latitude),\(c.longitude)&q=\(encodedName)&dirflg=d")
    }
}

// MARK: - Card Container (legacy compat)

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .appCard()
    }
}

#Preview {
    NavigationStack {
        LakeDetailView(lake: .preview)
            .environment(LocationService.shared)
            .environment(WeatherService.shared)
            .environment(LakeContentService.shared)
            .environment(LakePlaceService.shared)
            .modelContainer(for: FavouriteItem.self, inMemory: true)
    }
}
