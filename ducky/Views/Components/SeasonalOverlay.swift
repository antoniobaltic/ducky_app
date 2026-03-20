import SwiftUI

struct SeasonalOverlay: View {
    var season: Season = .current

    var body: some View {
        switch season {
        case .winter:
            SnowfallView()
        case .spring:
            SpringBlossomView()
        case .summer:
            FloatingBubblesView(count: 6, color: .white.opacity(0.3))
        case .autumn:
            FallingLeavesView()
        }
    }
}

// MARK: - Preview

#Preview("Seasonal Effects") {
    VStack(spacing: 0) {
        ForEach(Season.allCases, id: \.rawValue) { season in
            ZStack {
                Color.blue.opacity(0.3)
                SeasonalOverlay(season: season)
                Text(season.rawValue.capitalized)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(height: 180)
        }
    }
    .ignoresSafeArea()
}
