import SwiftUI

struct QualityBadge: View {
    let qualityLabel: String
    let qualityColor: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(qualityColor)
                .frame(width: 10, height: 10)
                .shadow(color: qualityColor.opacity(0.4), radius: 3)
            Text(qualityLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(qualityColor.opacity(0.12), in: Capsule())
    }
}

struct TrafficLightRow: View {
    let label: String
    let value: String?
    let status: TrafficLight
    var showValue: Bool = false

    var body: some View {
        HStack {
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
                .shadow(color: status.color.opacity(0.4), radius: 3)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            if showValue, let value {
                Text(value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text(status.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(status.color)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        QualityBadge(qualityLabel: "Ausgezeichnet", qualityColor: AppTheme.freshGreen)
        QualityBadge(qualityLabel: "Gut", qualityColor: AppTheme.teal)
        QualityBadge(qualityLabel: "Ausreichend", qualityColor: .orange)
        QualityBadge(qualityLabel: "Mangelhaft", qualityColor: AppTheme.coral)

        Divider()

        TrafficLightRow(label: "E.Coli", value: "50 KBE/100ml", status: .green)
        TrafficLightRow(label: "Enterokokken", value: "600 KBE/100ml", status: .red)
    }
    .padding()
}
