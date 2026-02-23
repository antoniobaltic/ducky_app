import SwiftUI
import SwiftData
import MapKit

struct MapView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @State private var selectedLake: BathingWater?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 47.5, longitude: 14.0),
            span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 5.0)
        )
    )

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition, selection: $selectedLake) {
                    ForEach(dataService.lakes) { lake in
                        Annotation(lake.name, coordinate: lake.coordinate, anchor: .bottom) {
                            DuckPinView(state: lake.duckState)
                                .scaleEffect(selectedLake?.id == lake.id ? 1.3 : 1.0)
                                .animation(AppTheme.quickSpring, value: selectedLake?.id)
                        }
                        .tag(lake)
                    }

                    if locationService.isAuthorized {
                        UserAnnotation()
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }

                // Bottom sheet
                if let lake = selectedLake {
                    lakeBottomSheet(lake)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Karte")
            .task {
                await dataService.loadData()
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
        }
    }

    // MARK: - Bottom Sheet

    private func lakeBottomSheet(_ lake: BathingWater) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppTheme.divider)
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack(spacing: 14) {
                DuckBadge(state: lake.duckState, size: 56)
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(lake.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    if let municipality = lake.municipality {
                        HStack(spacing: 4) {
                            Text(municipality)
                            if let state = lake.state {
                                Text("·")
                                Text(state)
                            }
                        }
                        .font(AppTheme.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    }

                    HStack(spacing: 8) {
                        TemperatureBadge(temperature: lake.waterTemperature, size: .small)
                        QualityBadge(qualityLabel: lake.qualityLabel, qualityColor: lake.qualityColor)
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        withAnimation(AppTheme.quickSpring) { selectedLake = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .symbolRenderingMode(.hierarchical)
                    }

                    NavigationLink(destination: LakeDetailView(lake: lake)) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.oceanBlue)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(16)
        }
        .background(
            AppTheme.cardBackground
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 20, y: -4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
        .animation(AppTheme.springAnimation, value: selectedLake?.id)
    }
}

#Preview {
    MapView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
