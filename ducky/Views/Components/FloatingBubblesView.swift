import SwiftUI

// MARK: - Floating Bubbles

struct FloatingBubblesView: View {
    var count: Int = 8
    var color: Color = .white

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    BubbleView(
                        color: color,
                        containerSize: geo.size,
                        index: i,
                        total: count
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct BubbleView: View {
    let color: Color
    let containerSize: CGSize
    let index: Int
    let total: Int

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var stableSize: CGFloat = 0
    @State private var stableX: CGFloat = 0
    @State private var stableDuration: Double = 0
    @State private var stableOpacity: Double = 0
    @State private var initialized = false

    var body: some View {
        Circle()
            .fill(color.opacity(opacity))
            .frame(width: stableSize, height: stableSize)
            .position(x: stableX, y: containerSize.height + 10 + yOffset)
            .blur(radius: 0.5)
            .onAppear {
                guard !initialized else { return }
                initialized = true
                let segment = containerSize.width / CGFloat(max(total, 1))
                stableSize = CGFloat.random(in: 4...14)
                stableX = segment * CGFloat(index) + CGFloat.random(in: 0...segment)
                stableDuration = Double.random(in: 4...8)
                stableOpacity = Double.random(in: 0.15...0.4)

                let delay = Double.random(in: 0...3)
                Task {
                    try? await Task.sleep(for: .seconds(delay))
                    startBubble()
                }
            }
    }

    private func startBubble() {
        withAnimation(.easeIn(duration: 0.5)) {
            opacity = stableOpacity
        }
        withAnimation(.easeInOut(duration: stableDuration).repeatForever(autoreverses: false)) {
            yOffset = -(containerSize.height + 30)
        }
        Task {
            try? await Task.sleep(for: .seconds(stableDuration * 0.7))
            withAnimation(.easeOut(duration: stableDuration * 0.3)) {
                opacity = 0
            }
        }
    }
}
