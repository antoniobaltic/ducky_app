import SwiftUI

/// A living lakeside scene background for the Home screen.
/// Score-aware atmosphere: sun, sky, clouds, birds, water, fish.
struct HomeSceneBackground: View {
    let scoreLevel: SwimScore.Level

    @State private var sunPulse = false
    @State private var cloud1X: CGFloat = 0.10
    @State private var cloud2X: CGFloat = 0.55
    @State private var cloud3X: CGFloat = 0.75
    @State private var cloud4X: CGFloat = 0.30
    @State private var cloud5X: CGFloat = 0.60

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizon = h * 0.38

            ZStack {
                // 1. Sky gradient
                skyGradient(horizon: horizon / h)
                    .ignoresSafeArea()

                // 2. Water fill below horizon
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: horizon)
                    LinearGradient(
                        colors: [
                            AppTheme.skyBlue.opacity(0.30),
                            AppTheme.oceanBlue.opacity(0.18),
                            AppTheme.oceanBlue.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea()

                // 3. Sun glow
                if sunOpacity > 0 {
                    sunGlow
                        .position(x: w * 0.82, y: h * 0.06)
                }

                // 4. Clouds
                cloudsView(w: w, h: h)

                // 5. Birds (only perfekt/gut/mittel)
                if scoreLevel == .perfekt || scoreLevel == .gut || scoreLevel == .mittel {
                    BirdsView(skyWidth: w, skyHeight: horizon)
                        .position(x: w / 2, y: horizon / 2)
                }

                // 6. Water wave at horizon
                WaterWaveView(baseColor: AppTheme.oceanBlue, height: 40, speed: 0.7)
                    .opacity(0.35)
                    .position(x: w / 2, y: horizon + 10)

                // 7. Swimming fish with bubbles
                FishView(waterWidth: w, waterHeight: h - horizon)
                    .position(x: w / 2, y: horizon + (h - horizon) / 2)
            }
        }
        .animation(AppTheme.gentleSpring, value: scoreLevel)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: sunPulseDuration).repeatForever(autoreverses: true)) {
                sunPulse = true
            }
            withAnimation(.linear(duration: 80).repeatForever(autoreverses: false)) {
                cloud1X = 1.15
            }
            withAnimation(.linear(duration: 100).repeatForever(autoreverses: false)) {
                cloud2X = 1.25
            }
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                cloud3X = 1.20
            }
            withAnimation(.linear(duration: 110).repeatForever(autoreverses: false)) {
                cloud4X = 1.30
            }
            withAnimation(.linear(duration: 70).repeatForever(autoreverses: false)) {
                cloud5X = 1.18
            }
        }
    }

    // MARK: - Sky Gradient

    private func skyGradient(horizon: CGFloat) -> LinearGradient {
        LinearGradient(
            colors: skyColors,
            startPoint: .top,
            endPoint: UnitPoint(x: 0.5, y: horizon)
        )
    }

    private var skyColors: [Color] {
        switch scoreLevel {
        case .perfekt:
            return [
                Color(red: 1.0, green: 0.95, blue: 0.78),   // warm sunshine
                Color(red: 1.0, green: 0.90, blue: 0.80),   // soft peach
                Color(red: 0.78, green: 0.90, blue: 1.0),   // sky blue
            ]
        case .gut:
            return [
                Color(red: 0.95, green: 0.96, blue: 1.0),   // cool light
                Color(red: 0.88, green: 0.94, blue: 1.0),   // soft blue
                Color(red: 0.78, green: 0.90, blue: 1.0),   // sky blue
            ]
        case .mittel:
            return [
                Color(red: 0.88, green: 0.90, blue: 0.94),  // hazy grey-blue
                Color(red: 0.84, green: 0.87, blue: 0.92),  // muted blue-grey
                Color(red: 0.80, green: 0.86, blue: 0.94),  // pale steel
            ]
        case .schlecht:
            return [
                Color(red: 0.82, green: 0.83, blue: 0.86),  // flat overcast
                Color(red: 0.80, green: 0.82, blue: 0.86),  // grey
                Color(red: 0.78, green: 0.82, blue: 0.88),  // cool grey
            ]
        case .warnung:
            return [
                Color(red: 0.78, green: 0.76, blue: 0.78),  // dark stormy
                Color(red: 0.76, green: 0.75, blue: 0.80),  // grey-purple
                Color(red: 0.74, green: 0.78, blue: 0.84),  // steel
            ]
        }
    }

    // MARK: - Sun

    private var sunOpacity: Double {
        switch scoreLevel {
        case .perfekt:  return 1.0
        case .gut:      return 0.80
        case .mittel:   return 0.50
        case .schlecht: return 0.25
        case .warnung:  return 0.0
        }
    }

    private var sunOuterSize: CGFloat {
        switch scoreLevel {
        case .perfekt:  return 180
        case .gut:      return 140
        case .mittel:   return 100
        case .schlecht: return 60
        case .warnung:  return 0
        }
    }

    private var sunInnerSize: CGFloat {
        switch scoreLevel {
        case .perfekt:  return 60
        case .gut:      return 45
        case .mittel:   return 30
        case .schlecht: return 18
        case .warnung:  return 0
        }
    }

    private var sunPulseRange: (CGFloat, CGFloat) {
        switch scoreLevel {
        case .perfekt:  return (0.96, 1.08)
        case .gut:      return (0.97, 1.05)
        case .mittel:   return (0.98, 1.03)
        default:        return (1.0, 1.0)
        }
    }

    private var sunPulseDuration: Double {
        switch scoreLevel {
        case .perfekt:  return 3.5
        case .gut:      return 4.0
        case .mittel:   return 5.0
        default:        return 3.5
        }
    }

    private var sunGlowColor: Color {
        switch scoreLevel {
        case .perfekt:  return AppTheme.sunshine
        case .gut:      return AppTheme.sunshine
        case .mittel:   return AppTheme.sunshine.opacity(0.6)
        case .schlecht: return Color(red: 0.85, green: 0.80, blue: 0.65)
        case .warnung:  return .clear
        }
    }

    private var sunGlow: some View {
        let pulse = sunPulseRange
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            sunGlowColor.opacity(0.35 * sunOpacity),
                            sunGlowColor.opacity(0.10 * sunOpacity),
                            sunGlowColor.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: sunOuterSize * 0.11,
                        endRadius: sunOuterSize * 0.5
                    )
                )
                .frame(width: sunOuterSize, height: sunOuterSize)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.70 * sunOpacity),
                            sunGlowColor.opacity(0.40 * sunOpacity),
                            sunGlowColor.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: sunInnerSize * 0.5
                    )
                )
                .frame(width: sunInnerSize, height: sunInnerSize)
        }
        .scaleEffect(sunPulse ? pulse.1 : pulse.0)
        .opacity(sunOpacity)
    }

    // MARK: - Clouds

    private var cloudColor: Color {
        switch scoreLevel {
        case .perfekt, .gut: return .white
        case .mittel:        return Color(white: 0.85)
        case .schlecht:      return Color(white: 0.70)
        case .warnung:       return Color(white: 0.55)
        }
    }

    private var cloudOpacity: Double {
        switch scoreLevel {
        case .perfekt, .gut: return 0.75
        case .mittel:        return 0.70
        case .schlecht:      return 0.80
        case .warnung:       return 0.85
        }
    }

    private func cloudsView(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // Base 3 clouds (all states)
            cloudShape(width: w * 0.35, height: 30)
                .position(x: cloud1X * w, y: h * 0.16)

            cloudShape(width: w * 0.28, height: 24)
                .position(x: cloud2X * w, y: h * 0.28)

            cloudShape(width: w * 0.22, height: 18)
                .position(x: (cloud1X + 0.45) * w, y: h * 0.22)

            // 4th cloud for mittel+
            if scoreLevel == .mittel || scoreLevel == .schlecht || scoreLevel == .warnung {
                cloudShape(width: w * 0.32, height: 26)
                    .position(x: cloud3X * w, y: h * 0.12)
            }

            // 5th cloud for schlecht+
            if scoreLevel == .schlecht || scoreLevel == .warnung {
                cloudShape(width: w * 0.38, height: 32)
                    .position(x: cloud4X * w, y: h * 0.08)
            }

            // 6th cloud for warnung
            if scoreLevel == .warnung {
                cloudShape(width: w * 0.42, height: 36)
                    .position(x: cloud5X * w, y: h * 0.18)
            }
        }
    }

    private func cloudShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(cloudColor.opacity(cloudOpacity))
                .frame(width: width, height: height)
                .blur(radius: 8)
            Ellipse()
                .fill(cloudColor.opacity(cloudOpacity * 0.67))
                .frame(width: width * 0.7, height: height * 0.7)
                .offset(x: width * 0.1, y: -height * 0.15)
                .blur(radius: 5)
        }
    }
}
