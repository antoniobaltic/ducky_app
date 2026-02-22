import SwiftUI

// MARK: - Duck Mascot "Ente Emma"

struct DuckView: View {
    let state: DuckState
    var size: CGFloat = 120

    @State private var bobOffset: CGFloat = 0
    @State private var blinkOpacity: Double = 1
    @State private var wingAngle: Double = 0

    private var scale: CGFloat { size / 120 }

    var body: some View {
        ZStack {
            duckBody
        }
        .frame(width: size, height: size)
        .onAppear { startAnimations() }
        .onChange(of: state) { startAnimations() }
    }

    // MARK: - Body Parts

    private var duckBody: some View {
        ZStack(alignment: .center) {
            // Shadow
            Ellipse()
                .fill(.black.opacity(0.08))
                .frame(width: 80 * scale, height: 18 * scale)
                .offset(y: 46 * scale)
                .blur(radius: 4 * scale)

            // Main body
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [state.bodyColor.opacity(0.95), state.bodyColor.opacity(0.75)],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 2,
                        endRadius: 60 * scale
                    )
                )
                .frame(width: 78 * scale, height: 62 * scale)
                .offset(y: 18 * scale + bobOffset)

            // Wing
            DuckWing(scale: scale, state: state)
                .offset(x: 12 * scale, y: 26 * scale + bobOffset)
                .rotationEffect(.degrees(wingAngle), anchor: .topLeading)

            // Head
            Circle()
                .fill(state.bodyColor)
                .frame(width: 44 * scale, height: 44 * scale)
                .offset(x: 12 * scale, y: -18 * scale + bobOffset)
                .shadow(color: .black.opacity(0.08), radius: 2, x: 1, y: 2)

            // Bill
            DuckBill(state: state, scale: scale)
                .offset(x: 34 * scale, y: -14 * scale + bobOffset)

            // Eye
            DuckEye(state: state, scale: scale, blinkOpacity: blinkOpacity)
                .offset(x: 18 * scale, y: -26 * scale + bobOffset)

            // State decorations
            stateDecoration
                .offset(bobOffset: bobOffset)
        }
        .frame(width: 90 * scale, height: 110 * scale)
    }

    @ViewBuilder
    private var stateDecoration: some View {
        switch state {
        case .begeistert:
            // Sparkles
            Group {
                Text("✨").font(.system(size: 14 * scale))
                    .offset(x: 40 * scale, y: -44 * scale + bobOffset)
                Text("⭐️").font(.system(size: 10 * scale))
                    .offset(x: -30 * scale, y: -50 * scale + bobOffset)
            }
        case .frierend:
            // Snowflakes
            Group {
                Text("❄️").font(.system(size: 14 * scale))
                    .offset(x: -36 * scale, y: -32 * scale + bobOffset)
                Text("❄️").font(.system(size: 10 * scale))
                    .offset(x: 40 * scale, y: -48 * scale + bobOffset)
            }
        case .warnend:
            Text("⚠️").font(.system(size: 16 * scale))
                .offset(x: 38 * scale, y: -50 * scale + bobOffset)
        default:
            EmptyView()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Bob
        withAnimation(
            .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        ) {
            bobOffset = state == .frierend ? -6 * scale : -4 * scale
        }

        // Wing flap (only for begeistert)
        withAnimation(
            .easeInOut(duration: state == .begeistert ? 0.5 : 2.5)
            .repeatForever(autoreverses: true)
        ) {
            wingAngle = state == .begeistert ? -18 : -4
        }

        // Blink
        scheduleBlink()
    }

    private func scheduleBlink() {
        let delay = Double.random(in: 2...5)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.07)) { blinkOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.07)) { blinkOpacity = 1 }
                scheduleBlink()
            }
        }
    }
}

// MARK: - Sub-shapes

private struct DuckBill: View {
    let state: DuckState
    let scale: CGFloat

    var body: some View {
        ZStack {
            // Upper bill
            Capsule()
                .fill(state.billColor)
                .frame(width: 18 * scale, height: 9 * scale)
                .offset(y: -2 * scale)

            // Lower bill
            Capsule()
                .fill(state.billColor.opacity(0.8))
                .frame(width: 16 * scale, height: 7 * scale)
                .offset(y: 4 * scale)

            // Mouth expression
            mouthShape
        }
    }

    @ViewBuilder
    private var mouthShape: some View {
        switch state {
        case .begeistert:
            // Big smile
            Path { p in
                p.move(to: CGPoint(x: 2 * scale, y: 4 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: 14 * scale, y: 4 * scale),
                    control: CGPoint(x: 8 * scale, y: 10 * scale)
                )
            }
            .stroke(Color.white.opacity(0.6), lineWidth: 1.5 * scale)
            .frame(width: 18 * scale, height: 12 * scale)
            .offset(y: 1 * scale)

        case .zufrieden:
            Path { p in
                p.move(to: CGPoint(x: 3 * scale, y: 4 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: 13 * scale, y: 4 * scale),
                    control: CGPoint(x: 8 * scale, y: 7 * scale)
                )
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1.2 * scale)
            .frame(width: 18 * scale, height: 10 * scale)
            .offset(y: 1 * scale)

        case .frierend, .warnend:
            // Frown
            Path { p in
                p.move(to: CGPoint(x: 3 * scale, y: 6 * scale))
                p.addQuadCurve(
                    to: CGPoint(x: 13 * scale, y: 6 * scale),
                    control: CGPoint(x: 8 * scale, y: 2 * scale)
                )
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1.2 * scale)
            .frame(width: 18 * scale, height: 10 * scale)
            .offset(y: 0 * scale)

        default:
            EmptyView()
        }
    }
}

private struct DuckEye: View {
    let state: DuckState
    let scale: CGFloat
    let blinkOpacity: Double

    var body: some View {
        ZStack {
            // Eye white
            Ellipse()
                .fill(.white)
                .frame(width: eyeWidth, height: eyeHeight * blinkOpacity + 0.5)
                .opacity(blinkOpacity < 0.2 ? 0 : 1)

            // Pupil
            Circle()
                .fill(.black)
                .frame(width: 5 * scale, height: 5 * scale)
                .offset(x: 1 * scale, y: -1 * scale)
                .opacity(blinkOpacity < 0.2 ? 0 : 1)

            // Glint
            Circle()
                .fill(.white.opacity(0.9))
                .frame(width: 2 * scale, height: 2 * scale)
                .offset(x: 2 * scale, y: -2 * scale)
                .opacity(blinkOpacity < 0.2 ? 0 : 1)

            // Eyebrow for zoegernd
            if state == .zoegernd {
                Capsule()
                    .fill(.black.opacity(0.7))
                    .frame(width: 10 * scale, height: 2 * scale)
                    .rotationEffect(.degrees(-15))
                    .offset(x: 1 * scale, y: -10 * scale)
                    .opacity(blinkOpacity < 0.2 ? 0 : 1)
            }

            // Closed/squint for frierend
            if state == .frierend {
                Capsule()
                    .fill(.black.opacity(0.6))
                    .frame(width: 10 * scale, height: 2.5 * scale)
                    .offset(y: 3 * scale)
            }

            // Shining eyes for begeistert (stars)
            if state == .begeistert {
                Text("★")
                    .font(.system(size: 8 * scale))
                    .foregroundStyle(.yellow)
                    .offset(x: 1 * scale, y: -1 * scale)
                    .opacity(blinkOpacity < 0.2 ? 0 : 1)
            }
        }
    }

    private var eyeWidth: CGFloat {
        switch state {
        case .begeistert: return 12 * scale
        case .frierend, .warnend: return 10 * scale
        default: return 11 * scale
        }
    }

    private var eyeHeight: CGFloat {
        switch state {
        case .begeistert: return 12 * scale
        case .frierend: return 6 * scale
        default: return 10 * scale
        }
    }
}

private struct DuckWing: View {
    let scale: CGFloat
    let state: DuckState

    var body: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [state.bodyColor.opacity(0.6), state.bodyColor.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 28 * scale, height: 18 * scale)
            .rotationEffect(.degrees(20))
    }
}

// MARK: - Pin version for Map

struct DuckPinView: View {
    let state: DuckState

    var body: some View {
        ZStack {
            Circle()
                .fill(state.bodyColor)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

            DuckView(state: state, size: 28)
                .offset(y: -2)
        }
    }
}

// MARK: - Small inline version

struct DuckBadge: View {
    let state: DuckState
    var size: CGFloat = 40

    var body: some View {
        DuckView(state: state, size: size)
    }
}

// MARK: - Offset helper

extension View {
    func offset(bobOffset: CGFloat) -> some View {
        self
    }
}

// MARK: - Preview

#Preview("All Duck States") {
    ScrollView(.horizontal) {
        HStack(spacing: 24) {
            ForEach([DuckState.begeistert, .zufrieden, .zoegernd, .frierend, .warnend], id: \.rawValue) { state in
                VStack(spacing: 8) {
                    DuckView(state: state, size: 100)
                    Text(state.title)
                        .font(.caption.bold())
                    Text(state.line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                }
                .padding()
                .background(state.backgroundGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
    }
}
