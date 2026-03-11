import SwiftUI
import SwiftData
import MapKit

struct MapView: View {
    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.5, longitude: 14.0),
        span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 5.0)
    )

    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @Environment(WeatherService.self) private var weatherService
    @State private var selectedLake: BathingWater?
    @State private var selectedWeather: LakeWeather?
    @State private var visibleRegion: MKCoordinateRegion? = defaultRegion
    @State private var cameraPosition: MapCameraPosition = .region(defaultRegion)
    @State private var didSetInitialCamera = false
    @State private var selectedWeatherTask: Task<Void, Never>?

    init(initialSelectedLake: BathingWater? = nil) {
        _selectedLake = State(initialValue: initialSelectedLake)
    }

    private func distanceToLake(_ lake: BathingWater) -> Double? {
        guard let userLocation = locationService.userLocation else { return nil }
        return lake.distance(from: userLocation)
    }

    /// Lakes filtered to the visible map region for performance
    private var visibleLakes: [BathingWater] {
        guard let region = visibleRegion else { return dataService.lakes }
        let latDelta = region.span.latitudeDelta / 2
        let lonDelta = region.span.longitudeDelta / 2
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        return dataService.lakes.filter { lake in
            abs(lake.latitude - centerLat) <= latDelta &&
            abs(lake.longitude - centerLon) <= lonDelta
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, selection: $selectedLake) {
                    ForEach(visibleLakes) { lake in
                        Annotation(lake.displayName, coordinate: lake.coordinate, anchor: .bottom) {
                            ScorePinView(score: lake.swimScore(weather: weatherService.weatherCache[lake.id]))
                                .scaleEffect(selectedLake?.id == lake.id ? 1.3 : 1.0)
                                .animation(AppTheme.quickSpring, value: selectedLake?.id)
                        }
                        .tag(lake)
                    }

                    if locationService.isAuthorized {
                        UserAnnotation()
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleRegion = context.region
                }

                // Bottom sheet
                if let lake = selectedLake {
                    lakeBottomSheet(lake)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Karte")
            .task {
                if dataService.isPreviewStubbed {
                    applyInitialCameraIfNeeded()
                    loadSelectedWeather(for: selectedLake)
                    return
                }

                await dataService.loadData()
                applyInitialCameraIfNeeded()
                loadSelectedWeather(for: selectedLake)
            }
        }
        .onChange(of: selectedLake) { _, new in
            if let lake = new {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(
                        MKCoordinateRegion(
                            center: lake.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                        )
                    )
                }
            }
            loadSelectedWeather(for: new)
        }
        .onChange(of: locationService.userLocation) { _, _ in
            applyInitialCameraIfNeeded()
        }
        .onDisappear {
            selectedWeatherTask?.cancel()
            selectedWeatherTask = nil
        }
    }

    // MARK: - Bottom Sheet

    private func lakeBottomSheet(_ lake: BathingWater) -> some View {
        let score = lake.swimScore(weather: selectedWeather)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Capsule()
                    .fill(AppTheme.divider)
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            ZStack(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 12) {
                    SwimScoreBadge(score: score, size: .medium)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(lake.displayName)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            if let municipality = lake.municipality {
                                Text(municipality)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                            }
                            if let state = lake.state {
                                Text("·")
                                    .padding(.leading, 3)
                                Text(state)
                            }
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.trailing, 38)

                    Spacer(minLength: 0)
                }

                Button {
                    withAnimation(AppTheme.quickSpring) { selectedLake = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.75))
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(.top, 2)
            }

            HStack(spacing: 12) {
                miniInfoChip(
                    icon: "wind",
                    label: "Luft",
                    value: selectedWeather?.airTemperature.map { String(format: "%.0f°C", $0) } ?? "–",
                    color: AppTheme.airTempGreen
                )
                miniInfoChip(
                    icon: "drop.fill",
                    label: "Wasser",
                    value: lake.currentWaterTemperature.map { String(format: "%.0f°C", $0) } ?? "–",
                    color: AppTheme.oceanBlue
                )
                if let distanceKm = distanceToLake(lake) {
                    miniInfoChip(
                        icon: "location.fill",
                        label: "",
                        value: String(format: "%.1f km", distanceKm),
                        color: AppTheme.teal
                    )
                }
            }

            HStack(spacing: 10) {
                NavigationLink(destination: LakeDetailView(lake: lake)) {
                    Label("Details", systemImage: "sparkles")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppTheme.oceanBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    openInMaps(lake)
                } label: {
                    Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppTheme.oceanBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(
            AppTheme.cardBackground
                .overlay(
                    LinearGradient(
                        colors: [AppTheme.oceanBlue.opacity(0.08), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 22, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
        .animation(AppTheme.springAnimation, value: selectedLake?.id)
    }

    private func miniInfoChip(
        icon: String,
        label: String,
        value: String,
        color: Color,
        textColor: Color = AppTheme.textPrimary
    ) -> some View {
        let text = label.isEmpty ? value : "\(label) \(value)"

        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10), in: Capsule())
    }

    private func openInMaps(_ lake: BathingWater) {
        let coordinate = lake.coordinate
        guard let url = URL(
            string: "maps://?q=\(lake.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lake.name)&ll=\(coordinate.latitude),\(coordinate.longitude)"
        ) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func loadSelectedWeather(for lake: BathingWater?) {
        selectedWeatherTask?.cancel()
        selectedWeatherTask = nil
        selectedWeather = nil

        guard let lake else { return }
        let selectedID = lake.id

        selectedWeatherTask = Task {
            let weather = await weatherService.fetchWeather(for: lake)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard selectedLake?.id == selectedID else { return }
                selectedWeather = weather
            }
        }
    }

    private func applyInitialCameraIfNeeded() {
        guard !didSetInitialCamera else { return }

        if let lake = selectedLake {
            let region = MKCoordinateRegion(
                center: lake.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
            )
            visibleRegion = region
            cameraPosition = .region(region)
            didSetInitialCamera = true
            return
        }

        guard let userLocation = locationService.userLocation else { return }

        // 50 km radius => 100 km span.
        let region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: 100_000,
            longitudinalMeters: 100_000
        )
        visibleRegion = region
        cameraPosition = .region(region)
        didSetInitialCamera = true
    }
}

#Preview {
    let environment = PreviewFixtures.makeEnvironment()

    return MapView()
        .environment(environment.dataService)
        .environment(environment.locationService)
        .environment(environment.weatherService)
        .environment(environment.lakeContentService)
        .environment(environment.lakePlaceService)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}

#Preview("Selected Lake Card") {
    let environment = PreviewFixtures.makeEnvironment(useFixtures: true)

    return MapView(initialSelectedLake: .preview)
        .environment(environment.dataService)
        .environment(environment.locationService)
        .environment(environment.weatherService)
        .environment(environment.lakeContentService)
        .environment(environment.lakePlaceService)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
