import SwiftUI

// MARK: - Animated Wave Shape

struct WaveShape: Shape {
    var offset: Angle
    var amplitude: CGFloat
    var frequency: CGFloat

    var animatableData: Double {
        get { offset.degrees }
        set { offset = .degrees(newValue) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midY = height * 0.5

        path.move(to: CGPoint(x: 0, y: midY))

        for x in stride(from: 0, through: width, by: 2) {
            let relX = x / width
            let sine = sin(relX * frequency * .pi * 2 + offset.radians)
            let y = midY + amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}
