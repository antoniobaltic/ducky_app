import SwiftUI

// MARK: - Map Pin (mini duck face, not emoji)

struct DuckPinView: View {
    let state: DuckState

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(state.bodyColor.opacity(0.2))
                .frame(width: 38, height: 38)

            // Head circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.bodyColor, state.bodyColor.opacity(0.85)],
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 30, height: 30)
                .shadow(color: state.bodyColor.opacity(0.3), radius: 4, y: 2)

            // Head shine
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 10, height: 8)
                .offset(x: -4, y: -6)
                .blur(radius: 2)

            // Eyes
            HStack(spacing: 4) {
                pinEye
                pinEye
            }
            .offset(x: 1, y: -2)

            // Beak
            Ellipse()
                .fill(state.billColor)
                .frame(width: 9, height: 6)
                .offset(x: 5, y: 4)

            // Tiny cheek
            Circle()
                .fill(Color.pink.opacity(state == .begeistert || state == .zufrieden ? 0.3 : 0))
                .frame(width: 5, height: 5)
                .offset(x: 8, y: 1)
                .blur(radius: 2)
        }
    }

    private var pinEye: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
            Circle()
                .fill(Color(white: 0.1))
                .frame(width: 3.5, height: 3.5)
            Circle()
                .fill(.white)
                .frame(width: 1.5, height: 1.5)
                .offset(x: 0.5, y: -0.8)
        }
    }
}

// MARK: - Preview

#Preview("Duck Pin") {
    HStack(spacing: 16) {
        ForEach(DuckState.allCases, id: \.rawValue) { state in
            DuckPinView(state: state)
        }
    }
    .padding()
}
