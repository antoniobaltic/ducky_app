import SwiftUI

// MARK: - Bubble Animation Background

struct BubbleBackground: View {
    let color: Color
    @State private var animate = false
    @State private var bubbles: [BubbleParams] = []

    struct BubbleParams: Identifiable {
        let id: Int
        let opacity: Double
        let size: CGFloat
        let x: CGFloat
        let y1: CGFloat
        let y2: CGFloat
        let blur: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(bubbles) { b in
                Circle()
                    .fill(color.opacity(b.opacity))
                    .frame(width: b.size)
                    .offset(x: b.x, y: animate ? b.y2 : b.y1)
                    .blur(radius: b.blur)
            }
        }
        .onAppear {
            if bubbles.isEmpty {
                bubbles = (0..<6).map { i in
                    BubbleParams(
                        id: i,
                        opacity: .random(in: 0.03...0.08),
                        size: .random(in: 40...120),
                        x: .random(in: -150...150),
                        y1: .random(in: -200...200),
                        y2: .random(in: -200...200),
                        blur: .random(in: 10...30)
                    )
                }
            }
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
