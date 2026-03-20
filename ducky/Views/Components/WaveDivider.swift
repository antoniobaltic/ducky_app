import SwiftUI

// MARK: - Gentle Wave Divider (for section separators)

struct WaveDivider: View {
    var color: Color = AppTheme.oceanBlue
    var height: CGFloat = 30

    @State private var phase: Angle = .zero

    var body: some View {
        WaveShape(offset: phase, amplitude: height * 0.35, frequency: 2.0)
            .fill(color.opacity(0.08))
            .frame(height: height)
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    phase = .degrees(360)
                }
            }
    }
}
