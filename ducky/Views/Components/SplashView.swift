import SwiftUI

// MARK: - Water Splash Particles

struct SplashView: View {
    var color: Color = AppTheme.skyBlue
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(color.opacity(animate ? 0 : 0.5))
                    .frame(width: CGFloat.random(in: 3...8))
                    .offset(
                        x: animate ? CGFloat.random(in: -40...40) : 0,
                        y: animate ? CGFloat.random(in: -50...(-10)) : 0
                    )
                    .scaleEffect(animate ? 0.3 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate = true
            }
        }
    }
}
