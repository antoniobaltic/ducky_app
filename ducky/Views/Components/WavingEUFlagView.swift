import SwiftUI

struct WavingEUFlagView: View {
    var width: CGFloat = 248
    var height: CGFloat = 160

    @State private var phaseFront: Angle = .zero
    @State private var phaseBack: Angle = .degrees(160)
    @State private var tilt = false

    private var scale: CGFloat {
        min(width / 248, height / 160)
    }

    private var cornerRadius: CGFloat {
        24 * scale
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.08, green: 0.30, blue: 0.78))

            WaveShape(offset: phaseFront, amplitude: 8 * scale, frequency: 1.15)
                .fill(.white.opacity(0.15))
                .offset(y: -30 * scale)
                .blendMode(.screen)

            WaveShape(offset: phaseBack, amplitude: 9 * scale, frequency: 1.0)
                .fill(.black.opacity(0.12))
                .offset(y: 34 * scale)
                .blendMode(.multiply)

            ForEach(0..<12, id: \.self) { index in
                let angle = (Double(index) / 12.0) * (2.0 * Double.pi) - (Double.pi / 2.0)
                Image(systemName: "star.fill")
                    .font(.system(size: 11 * scale, weight: .black))
                    .foregroundStyle(AppTheme.sunshine)
                    .offset(x: cos(angle) * 56 * scale, y: sin(angle) * 38 * scale)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 16 * scale, x: 0, y: 10 * scale)
        .rotation3DEffect(
            .degrees(tilt ? 7 : -7),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                phaseFront = .degrees(360)
            }
            withAnimation(.linear(duration: 3.1).repeatForever(autoreverses: false)) {
                phaseBack = .degrees(520)
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                tilt = true
            }
        }
    }
}

