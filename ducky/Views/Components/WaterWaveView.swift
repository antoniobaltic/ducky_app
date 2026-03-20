import SwiftUI

// MARK: - Multi-Layer Water Wave Background

struct WaterWaveView: View {
    var baseColor: Color = AppTheme.oceanBlue
    var height: CGFloat = 60
    var speed: Double = 1.0

    @State private var phase1: Angle = .zero
    @State private var phase2: Angle = .degrees(120)
    @State private var phase3: Angle = .degrees(240)

    var body: some View {
        ZStack {
            // Back wave (lightest)
            WaveShape(offset: phase3, amplitude: height * 0.15, frequency: 1.2)
                .fill(baseColor.opacity(0.12))

            // Mid wave
            WaveShape(offset: phase2, amplitude: height * 0.2, frequency: 1.5)
                .fill(baseColor.opacity(0.18))

            // Front wave (darkest)
            WaveShape(offset: phase1, amplitude: height * 0.25, frequency: 1.0)
                .fill(baseColor.opacity(0.25))
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.linear(duration: 6 / speed).repeatForever(autoreverses: false)) {
                phase1 = .degrees(360)
            }
            withAnimation(.linear(duration: 8 / speed).repeatForever(autoreverses: false)) {
                phase2 = .degrees(360 + 120)
            }
            withAnimation(.linear(duration: 10 / speed).repeatForever(autoreverses: false)) {
                phase3 = .degrees(360 + 240)
            }
        }
    }
}

// MARK: - Preview

#Preview("Water Effects") {
    VStack(spacing: 0) {
        ZStack {
            AppTheme.heroGradient
            FloatingBubblesView(count: 10, color: .white)
            VStack {
                Text("Hero Area")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 300)

        WaterWaveView(baseColor: AppTheme.oceanBlue, height: 50)
            .offset(y: -25)

        WaveDivider()
            .padding(.top, 20)

        Spacer()
    }
    .ignoresSafeArea()
}
