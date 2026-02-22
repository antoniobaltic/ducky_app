import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(DataService.self) private var dataService
    @Environment(LocationService.self) private var locationService
    @State private var selectedLake: BathingWater?
    @State private var showDetail = false
    @State private var duckBobOffset: CGFloat = 0

    private var nearbyLakes: [BathingWater] {
        dataService.sortedByDistance(from: locationService.userLocation)
    }

    private var warmestLakes: [BathingWater] {
        dataService.sortedByTemperature()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.48, green: 0.78, blue: 1.00),
                        Color(red: 0.30, green: 0.58, blue: 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero Duck
                        heroDuckSection

                        // Content cards
                        VStack(spacing: 28) {
                            // Nearby
                            lakeRow(
                                title: "In deiner Nähe",
                                subtitle: locationService.isAuthorized ? nil : "Standort nicht freigegeben",
                                lakes: nearbyLakes,
                                emptyMessage: "Keine Seen in der Nähe"
                            )

                            // Warmest
                            lakeRow(
                                title: "Am wärmsten",
                                subtitle: nil,
                                lakes: Array(warmestLakes.prefix(10)),
                                emptyMessage: "Keine Temperaturdaten"
                            )
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
                            .tint(.white)
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

    // MARK: - Hero Duck

    private var heroDuckSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Soft glow behind duck
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)

                DuckView(state: heroState, size: 140)
                    .offset(y: duckBobOffset)
            }
            .frame(height: 180)

            VStack(spacing: 4) {
                Text("Hallo! Ich bin Ente Emma.")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(heroState.line)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }

            if let error = dataService.error {
                Text("⚠️ \(error)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
    }

    private var heroState: DuckState {
        guard let warmest = warmestLakes.first else { return .zufrieden }
        return warmest.duckState
    }

    // MARK: - Lake Row

    private func lakeRow(
        title: String,
        subtitle: String?,
        lakes: [BathingWater],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
            .padding(.horizontal, 20)

            if dataService.isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.white.opacity(0.2))
                                .frame(width: 180, height: 140)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else if lakes.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(lakes.prefix(15)) { lake in
                            LakeCard(
                                lake: lake,
                                distanceKm: locationService.userLocation.map { lake.distance(from: $0) }
                            )
                            .onTapGesture { selectedLake = lake }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - Shimmer modifier

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .init(x: phase, y: 0),
                    endPoint: .init(x: phase + 0.6, y: 0)
                )
                .animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: phase)
            )
            .onAppear { phase = 1.4 }
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

#Preview {
    HomeView()
        .environment(DataService.shared)
        .environment(LocationService.shared)
        .modelContainer(for: FavouriteItem.self, inMemory: true)
}
