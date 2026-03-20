import SwiftUI

// MARK: - App Icon Renderer
// Static Ducky icon at 1024x1024 for App Store / Home Screen.
// Render via Xcode Preview, then screenshot at 1024x1024.

struct AppIconView: View {
    let variant: IconVariant

    enum IconVariant: String, CaseIterable {
        case oceanGradient = "Ocean Gradient"
        case sunsetWarm = "Sunset Warm"
        case freshPool = "Fresh Pool"
        case skyBubbles = "Sky Bubbles"
        case goldenHour = "Golden Hour"
    }

    private let canvasSize: CGFloat = 1024

    var body: some View {
        ZStack {
            background
            iconDuck
        }
        .frame(width: canvasSize, height: canvasSize)
        .clipped()
    }

    // MARK: - Backgrounds

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .oceanGradient:
            // Deep ocean blue to sky blue — clean, brand-forward
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.32, blue: 0.78),
                        Color(red: 0.18, green: 0.52, blue: 0.96),
                        Color(red: 0.40, green: 0.72, blue: 1.0)
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                // Subtle radial glow behind duck
                RadialGradient(
                    colors: [
                        .white.opacity(0.18),
                        .clear
                    ],
                    center: .init(x: 0.52, y: 0.42),
                    startRadius: 80,
                    endRadius: 420
                )
                // Soft wave shapes at bottom
                iconWaves(
                    color1: Color(red: 0.08, green: 0.28, blue: 0.68).opacity(0.5),
                    color2: Color(red: 0.12, green: 0.36, blue: 0.80).opacity(0.4)
                )
            }

        case .sunsetWarm:
            // Warm sunset tones — orange to pink to soft blue
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.50, blue: 0.25),
                        Color(red: 1.0, green: 0.62, blue: 0.40),
                        Color(red: 0.96, green: 0.78, blue: 0.56),
                        Color(red: 0.70, green: 0.82, blue: 0.96)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                RadialGradient(
                    colors: [
                        .white.opacity(0.22),
                        .clear
                    ],
                    center: .init(x: 0.52, y: 0.42),
                    startRadius: 60,
                    endRadius: 400
                )
                iconWaves(
                    color1: Color(red: 0.90, green: 0.40, blue: 0.20).opacity(0.35),
                    color2: Color(red: 0.95, green: 0.50, blue: 0.28).opacity(0.25)
                )
            }

        case .freshPool:
            // Teal to mint — fresh swimming pool feel
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.0, green: 0.55, blue: 0.58),
                        Color(red: 0.05, green: 0.70, blue: 0.68),
                        Color(red: 0.35, green: 0.88, blue: 0.82),
                        Color(red: 0.65, green: 0.96, blue: 0.92)
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                RadialGradient(
                    colors: [
                        .white.opacity(0.20),
                        .clear
                    ],
                    center: .init(x: 0.50, y: 0.40),
                    startRadius: 60,
                    endRadius: 380
                )
                iconWaves(
                    color1: Color(red: 0.0, green: 0.48, blue: 0.52).opacity(0.4),
                    color2: Color(red: 0.0, green: 0.56, blue: 0.58).opacity(0.3)
                )
            }

        case .skyBubbles:
            // Bright sky blue with floating bubbles
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.45, blue: 0.91),
                        Color(red: 0.30, green: 0.62, blue: 1.0),
                        Color(red: 0.55, green: 0.82, blue: 1.0)
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
                RadialGradient(
                    colors: [
                        .white.opacity(0.16),
                        .clear
                    ],
                    center: .init(x: 0.50, y: 0.42),
                    startRadius: 80,
                    endRadius: 420
                )
                iconBubbles
                iconWaves(
                    color1: Color(red: 0.08, green: 0.38, blue: 0.82).opacity(0.45),
                    color2: Color(red: 0.12, green: 0.42, blue: 0.86).opacity(0.35)
                )
            }

        case .goldenHour:
            // Warm gold to soft blue — late afternoon lake
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.48, blue: 0.82),
                        Color(red: 0.50, green: 0.68, blue: 0.92),
                        Color(red: 0.82, green: 0.78, blue: 0.60),
                        Color(red: 1.0, green: 0.82, blue: 0.42)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.30),
                        .clear
                    ],
                    center: .init(x: 0.55, y: 0.30),
                    startRadius: 40,
                    endRadius: 350
                )
                iconWaves(
                    color1: Color(red: 0.18, green: 0.40, blue: 0.72).opacity(0.4),
                    color2: Color(red: 0.22, green: 0.46, blue: 0.78).opacity(0.3)
                )
            }
        }
    }

    // MARK: - Waves

    private func iconWaves(color1: Color, color2: Color) -> some View {
        ZStack {
            // Back wave
            IconWaveShape(amplitude: 22, frequency: 1.2, phase: 0.3)
                .fill(color2)
                .frame(height: 220)
                .offset(y: canvasSize * 0.38)

            // Front wave
            IconWaveShape(amplitude: 28, frequency: 1.0, phase: 0.0)
                .fill(color1)
                .frame(height: 200)
                .offset(y: canvasSize * 0.42)
        }
    }

    // MARK: - Bubbles

    private var iconBubbles: some View {
        ZStack {
            iconBubble(x: 0.14, y: 0.22, size: 48)
            iconBubble(x: 0.82, y: 0.18, size: 36)
            iconBubble(x: 0.08, y: 0.62, size: 28)
            iconBubble(x: 0.88, y: 0.55, size: 42)
            iconBubble(x: 0.72, y: 0.78, size: 24)
            iconBubble(x: 0.22, y: 0.82, size: 32)
            iconBubble(x: 0.92, y: 0.35, size: 20)
            iconBubble(x: 0.06, y: 0.42, size: 22)
        }
    }

    private func iconBubble(x: Double, y: Double, size: CGFloat) -> some View {
        Circle()
            .fill(.white.opacity(0.10))
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 1.5)
            )
            .overlay(
                // Shine highlight
                Circle()
                    .fill(.white.opacity(0.20))
                    .frame(width: size * 0.3, height: size * 0.3)
                    .offset(x: -size * 0.15, y: -size * 0.18)
            )
            .frame(width: size, height: size)
            .position(x: canvasSize * x, y: canvasSize * y)
    }

    // MARK: - Static Duck (no animations)

    private let duckScale: CGFloat = 2.5 // scale factor from 120 base to ~300px duck
    private var s: CGFloat { duckScale }

    private let bodyColor = Color(red: 1.0, green: 0.82, blue: 0.20) // Ducky yellow
    private let billColor = Color(red: 0.98, green: 0.60, blue: 0.10)
    private let outlineColor = Color(red: 0.85, green: 0.65, blue: 0.10)

    private var iconDuck: some View {
        ZStack {
            // Water ripple shadow
            Ellipse()
                .fill(.black.opacity(0.08))
                .frame(width: 76 * s, height: 14 * s)
                .offset(y: 46 * s)
                .blur(radius: 8 * s)

            // Body
            Ellipse()
                .fill(
                    EllipticalGradient(
                        colors: [bodyColor, bodyColor.opacity(0.88), bodyColor.opacity(0.72)],
                        center: .init(x: 0.38, y: 0.28),
                        startRadiusFraction: 0.0,
                        endRadiusFraction: 0.7
                    )
                )
                .overlay(
                    Ellipse().stroke(outlineColor.opacity(0.45), lineWidth: 1.2 * s)
                )
                .frame(width: 64 * s, height: 46 * s)
                .shadow(color: bodyColor.opacity(0.15), radius: 3 * s, y: 2 * s)
                .offset(y: 20 * s)

            // Belly shine
            Ellipse()
                .fill(.white.opacity(0.28))
                .frame(width: 32 * s, height: 20 * s)
                .offset(x: -5 * s, y: 24 * s)
                .blur(radius: 3 * s)

            // Tucked wing (left)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [bodyColor.opacity(0.65), bodyColor.opacity(0.40)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    Ellipse().stroke(outlineColor.opacity(0.40), lineWidth: 0.8 * s)
                )
                .frame(width: 18 * s, height: 12 * s)
                .rotationEffect(.degrees(-10))
                .offset(x: -22 * s, y: 22 * s)

            // Wing (right, slightly raised — friendly wave)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [bodyColor.opacity(0.75), bodyColor.opacity(0.50)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    Ellipse().stroke(outlineColor.opacity(0.50), lineWidth: 1.0 * s)
                )
                .frame(width: 22 * s, height: 14 * s)
                .rotationEffect(.degrees(15))
                .rotationEffect(.degrees(-8), anchor: .leading)
                .offset(x: 20 * s, y: 22 * s)

            // Tail
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(bodyColor.opacity(0.5 - Double(i) * 0.08))
                        .overlay(
                            Capsule().stroke(outlineColor.opacity(0.35), lineWidth: 0.7 * s)
                        )
                        .frame(width: (9 - CGFloat(i)) * s, height: (3.5 + CGFloat(i) * 0.5) * s)
                        .rotationEffect(.degrees(Double(i - 1) * -18))
                        .offset(x: -CGFloat(i) * 2 * s, y: CGFloat(1 - i) * 3 * s)
                }
            }
            .offset(x: -30 * s, y: 10 * s)

            // Head
            Circle()
                .fill(
                    RadialGradient(
                        colors: [bodyColor, bodyColor.opacity(0.88)],
                        center: .init(x: 0.4, y: 0.32),
                        startRadius: 0,
                        endRadius: 28 * s
                    )
                )
                .overlay(
                    Circle().stroke(outlineColor.opacity(0.40), lineWidth: 1.2 * s)
                )
                .frame(width: 54 * s, height: 54 * s)
                .shadow(color: bodyColor.opacity(0.12), radius: 3 * s, y: 1 * s)
                .offset(x: 2 * s, y: -14 * s)

            // Head shine
            Ellipse()
                .fill(.white.opacity(0.28))
                .frame(width: 20 * s, height: 14 * s)
                .rotationEffect(.degrees(-25))
                .offset(x: -8 * s, y: -28 * s)
                .blur(radius: 2.5 * s)

            // Cheeks (pink glow)
            Circle()
                .fill(Color.pink.opacity(0.25))
                .frame(width: 11 * s, height: 8 * s)
                .offset(x: 21 * s, y: -5 * s)
                .blur(radius: 3 * s)
            Circle()
                .fill(Color.pink.opacity(0.12))
                .frame(width: 8 * s, height: 6 * s)
                .offset(x: -8 * s, y: -3 * s)
                .blur(radius: 3 * s)

            // Beak
            ZStack {
                // Upper beak
                RoundedRectangle(cornerRadius: 7 * s)
                    .fill(
                        LinearGradient(
                            colors: [billColor, billColor.opacity(0.85)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7 * s)
                            .stroke(Color(red: 0.85, green: 0.40, blue: 0.05).opacity(0.40), lineWidth: 1.0 * s)
                    )
                    .frame(width: 21 * s, height: 11 * s)
                    .offset(y: -2 * s)

                // Lower beak
                RoundedRectangle(cornerRadius: 5 * s)
                    .fill(billColor.opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5 * s)
                            .stroke(Color(red: 0.85, green: 0.40, blue: 0.05).opacity(0.30), lineWidth: 0.8 * s)
                    )
                    .frame(width: 18 * s, height: 8 * s)
                    .offset(y: 5 * s)

                // Smile line
                Path { p in
                    p.move(to: CGPoint(x: 2 * s, y: 4 * s))
                    p.addQuadCurve(
                        to: CGPoint(x: 16 * s, y: 4 * s),
                        control: CGPoint(x: 9 * s, y: 8 * s)
                    )
                }
                .stroke(.white.opacity(0.4), lineWidth: 1.5 * s)
                .frame(width: 20 * s, height: 14 * s)
            }
            .offset(x: 27 * s, y: -10 * s)

            // Eyes
            HStack(spacing: 6 * s) {
                iconEye(isLeft: true)
                iconEye(isLeft: false)
            }
            .offset(x: 6 * s, y: -20 * s)

            // Sparkle decorations
            Image(systemName: "sparkle")
                .font(.system(size: 12 * s))
                .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.0))
                .offset(x: 34 * s, y: -42 * s)
                .opacity(0.85)
        }
        .offset(x: -8 * s, y: canvasSize * 0.02) // center visually (compensate for beak)
    }

    private func iconEye(isLeft: Bool) -> some View {
        ZStack {
            // Eye white
            Ellipse()
                .fill(.white)
                .frame(width: 14 * s, height: 12 * s)
                .shadow(color: .black.opacity(0.06), radius: 1 * s, y: 1 * s)

            // Pupil
            Circle()
                .fill(Color(white: 0.1))
                .frame(width: 5.5 * s, height: 5.5 * s)
                .offset(x: (isLeft ? 0.5 : 1) * s, y: 0.5 * s)

            // Glint
            Circle()
                .fill(.white)
                .frame(width: 2.8 * s, height: 2.8 * s)
                .offset(x: (isLeft ? 1.5 : 2) * s, y: -2 * s)

            // Happy eyebrow arc
            Circle()
                .trim(from: 0.0, to: 0.5)
                .rotation(.degrees(180))
                .stroke(Color(white: 0.25).opacity(0.45), lineWidth: 2.2 * s)
                .frame(width: 14 * s * 0.8, height: 14 * s * 0.35)
                .offset(y: -(12 * s * 0.55 + 2 * s))
        }
    }
}

// MARK: - Wave Shape for Icon

private struct IconWaveShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))

        for x in stride(from: 0, through: rect.width, by: 2) {
            let relativeX = x / rect.width
            let y = rect.midY + sin((relativeX * frequency * .pi * 2) + phase * .pi * 2) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Previews

#Preview("All Icon Variants") {
    ScrollView(.horizontal) {
        HStack(spacing: 24) {
            ForEach(AppIconView.IconVariant.allCases, id: \.rawValue) { variant in
                VStack(spacing: 8) {
                    AppIconView(variant: variant)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)

                    Text(variant.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
    }
}

#Preview("Ocean Gradient — Full Size") {
    AppIconView(variant: .oceanGradient)
        .frame(width: 1024, height: 1024)
}

#Preview("Sunset Warm — Full Size") {
    AppIconView(variant: .sunsetWarm)
        .frame(width: 1024, height: 1024)
}

#Preview("Fresh Pool — Full Size") {
    AppIconView(variant: .freshPool)
        .frame(width: 1024, height: 1024)
}

#Preview("Sky Bubbles — Full Size") {
    AppIconView(variant: .skyBubbles)
        .frame(width: 1024, height: 1024)
}

#Preview("Golden Hour — Full Size") {
    AppIconView(variant: .goldenHour)
        .frame(width: 1024, height: 1024)
}
