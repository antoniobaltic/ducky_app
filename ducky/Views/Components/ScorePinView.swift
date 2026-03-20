import SwiftUI

// MARK: - Score Pin for Map

struct ScorePinView: View {
    let score: SwimScore

    var body: some View {
        ZStack {
            // Pin shape
            Circle()
                .fill(AppTheme.scoreColor(for: score.level))
                .frame(width: 36, height: 36)
                .shadow(color: AppTheme.scoreColor(for: score.level).opacity(0.4), radius: 4, y: 2)

            Text(scoreText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private var scoreText: String {
        if score.total == 10.0 {
            return "10"
        }
        return score.total.formatted(.number.precision(.fractionLength(1)))
    }
}
