import SwiftUI

#if os(iOS)
import UIKit
#endif

struct ShareCardView: View {
    let lake: BathingWater
    let weather: LakeWeather?

    @Environment(\.dismiss) private var dismiss

#if os(iOS)
    @State private var activityItems: [Any] = []
    @State private var showActivitySheet = false
    @State private var isPreparingShare = false
    @State private var previewImage: UIImage?
#endif

    private var score: SwimScore {
        lake.swimScore(weather: weather)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageGradient
                    .ignoresSafeArea()

                BubbleBackground(color: AppTheme.scoreColor(for: score.level))
                    .opacity(0.16)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer()

                    sharePreview
                        .padding(.horizontal, 20)

                    shareButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("Teilen")
            .iOSNavigationBarInline()
            .toolbar {
                ToolbarItem(placement: .iOSTopBarLeading) {
                    Button("Fertig") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
        }
#if os(iOS)
        .task(id: previewRenderKey) {
            previewImage = renderShareImage()
        }
        .sheet(isPresented: $showActivitySheet) {
            ShareActivitySheet(activityItems: activityItems)
                .ignoresSafeArea()
        }
#endif
    }

    @ViewBuilder
    private var shareButton: some View {
#if os(iOS)
        Button {
            shareLakeCard()
        } label: {
            HStack(spacing: 8) {
                if isPreparingShare {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isPreparingShare ? "Bereite vor…" : "Teilen")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                AppTheme.scoreColor(for: score.level),
                in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
            )
            .shadow(color: AppTheme.scoreColor(for: score.level).opacity(0.30), radius: 10, y: 5)
        }
        .disabled(isPreparingShare)
#else
        ShareLink(item: shareText) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Teilen")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                AppTheme.scoreColor(for: score.level),
                in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
            )
            .shadow(color: AppTheme.scoreColor(for: score.level).opacity(0.30), radius: 10, y: 5)
        }
#endif
    }

    @ViewBuilder
    private var sharePreview: some View {
#if os(iOS)
        Group {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(16.0 / 11.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
            } else {
                LakeSharePreviewCard(
                    lake: lake,
                    weather: weather,
                    showShadow: true,
                    emphasizeScoreBackground: true,
                    isExport: true
                )
                .aspectRatio(16.0 / 11.0, contentMode: .fit)
            }
        }
#else
        LakeSharePreviewCard(lake: lake, weather: weather)
#endif
    }

#if os(iOS)
    private var previewRenderKey: String {
        [
            String(describing: lake.id),
            (weather?.airTemperature ?? -999).formatted(.number.precision(.fractionLength(2))),
            String(weather?.weatherCode ?? -999),
            (lake.currentWaterTemperature ?? -999).formatted(.number.precision(.fractionLength(2)))
        ].joined(separator: "|")
    }

    @MainActor
    private func shareLakeCard() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        defer { isPreparingShare = false }

        guard let image = previewImage ?? renderShareImage() else { return }
        activityItems = [image]
        showActivitySheet = true
    }

    @MainActor
    private func renderShareImage() -> UIImage? {
        let canvasWidth: CGFloat = 640
        let canvasHeight: CGFloat = 440
        let cardWidth: CGFloat = 600
        let cardHeight: CGFloat = 372
        let gradientColors = exportGradientUIColor(for: score.level)
        let shareGradient = LinearGradient(
            colors: gradientColors.map { Color(uiColor: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        let exportCard = ZStack {
            Rectangle()
                .fill(shareGradient)
                .frame(width: canvasWidth, height: canvasHeight)

            LakeSharePreviewCard(
                lake: lake,
                weather: weather,
                showShadow: false,
                emphasizeScoreBackground: true,
                isExport: true
            )
            .frame(width: cardWidth, height: cardHeight)
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .background(shareGradient)
        .clipped()
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: exportCard)
        renderer.proposedSize = ProposedViewSize(width: canvasWidth, height: canvasHeight)
        renderer.scale = 3
        renderer.isOpaque = true

        guard let rawImage = renderer.uiImage else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = rawImage.scale
        format.opaque = true

        let flattened = UIGraphicsImageRenderer(size: rawImage.size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: rawImage.size)
            let cgContext = context.cgContext

            let colors = gradientColors.map(\.cgColor) as CFArray

            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0.0, 0.55, 1.0]
            ) {
                cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: rect.maxX, y: rect.maxY),
                    options: []
                )
            } else {
                gradientColors[1].setFill()
                context.fill(rect)
            }

            rawImage.draw(in: rect)
        }

        return flattened
    }

    private func exportGradientUIColor(for level: SwimScore.Level) -> [UIColor] {
        switch level {
        case .perfekt:
            return [
                UIColor(red: 0.62, green: 0.94, blue: 0.75, alpha: 1.0),
                UIColor(red: 0.24, green: 0.80, blue: 0.50, alpha: 1.0),
                UIColor(red: 0.28, green: 0.78, blue: 0.90, alpha: 1.0)
            ]
        case .gut:
            return [
                UIColor(red: 0.56, green: 0.95, blue: 0.90, alpha: 1.0),
                UIColor(red: 0.13, green: 0.77, blue: 0.68, alpha: 1.0),
                UIColor(red: 0.30, green: 0.72, blue: 0.96, alpha: 1.0)
            ]
        case .mittel:
            return [
                UIColor(red: 1.00, green: 0.93, blue: 0.58, alpha: 1.0),
                UIColor(red: 0.98, green: 0.77, blue: 0.28, alpha: 1.0),
                UIColor(red: 1.00, green: 0.56, blue: 0.34, alpha: 1.0)
            ]
        case .schlecht:
            return [
                UIColor(red: 1.00, green: 0.84, blue: 0.50, alpha: 1.0),
                UIColor(red: 0.97, green: 0.59, blue: 0.24, alpha: 1.0),
                UIColor(red: 0.96, green: 0.39, blue: 0.30, alpha: 1.0)
            ]
        case .warnung:
            return [
                UIColor(red: 1.00, green: 0.72, blue: 0.64, alpha: 1.0),
                UIColor(red: 0.93, green: 0.38, blue: 0.31, alpha: 1.0),
                UIColor(red: 0.82, green: 0.25, blue: 0.24, alpha: 1.0)
            ]
        }
    }
#endif

    private var shareText: String {
        let scoreText = "\(score.total.formatted(.number.precision(.fractionLength(1))))/10"
        return [
            "🦆 \(lake.displayName)",
            "\(score.level.label): \(scoreText)",
            "Ducky App"
        ].joined(separator: "\n")
    }
}

private struct LakeSharePreviewCard: View {
    let lake: BathingWater
    let weather: LakeWeather?
    var showShadow: Bool = true
    var emphasizeScoreBackground: Bool = false
    var isExport: Bool = false

    private var score: SwimScore {
        lake.swimScore(weather: weather)
    }

    private var scoreDuckState: DuckState {
        score.duckState
    }

    private var scoreDuckBackgroundColor: Color {
        AppTheme.scoreColor(for: score.level)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: horizontalGap) {
                scoreBubble

                VStack(alignment: .leading, spacing: titleSpacing) {
                    Text(lake.displayName)
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    metadataLine
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(scoreDuckBackgroundColor.opacity(0.20))
                        .frame(width: duckCircleSize, height: duckCircleSize)
                    DuckView(state: scoreDuckState, size: duckSize)
                }
                .fixedSize()
            }

            Spacer(minLength: sectionGap)

            weatherRow

            Spacer(minLength: sectionGap)

            Divider()
                .overlay(AppTheme.cardStroke.opacity(0.45))

            HStack(spacing: footerSpacing) {
                Image(systemName: "duck.fill")
                    .font(.system(size: footerIconSize, weight: .semibold))
                    .foregroundStyle(AppTheme.sunshine)

                Text("Ducky App")
                    .font(.system(size: footerFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.top, footerTopPadding)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: isExport ? .infinity : nil,
            alignment: .topLeading
        )
        .padding(contentPadding)
        .background(
            LinearGradient(
                colors: emphasizeScoreBackground
                    ? [
                        scoreDuckBackgroundColor.opacity(0.24),
                        Color(red: 0.98, green: 0.99, blue: 1.00)
                    ]
                    : [
                        scoreDuckBackgroundColor.opacity(0.16),
                        AppTheme.cardBackground
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .shadow(color: .black.opacity(showShadow ? 0.10 : 0.0), radius: showShadow ? 18 : 0, y: showShadow ? 8 : 0)
    }

    private var scoreBubble: some View {
        ZStack {
            Circle()
                .fill(AppTheme.scoreColor(for: score.level))
                .frame(width: scoreDiameter, height: scoreDiameter)

            Text(scoreText)
                .font(.system(size: scoreFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
    }

    private var scoreText: String {
        if score.total == 10.0 {
            return "10"
        }
        return score.total.formatted(.number.precision(.fractionLength(1)))
    }

    private var metadataLine: some View {
        HStack(spacing: 4) {
            if let municipality = municipalityLabel {
                Text(municipality)
                    .font(.system(size: metadataFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let state = stateLabel {
                if municipalityLabel != nil {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                Text(state)
                    .font(.system(size: metadataFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var municipalityLabel: String? {
        guard let text = lake.municipality?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }
        return text
    }

    private var stateLabel: String? {
        guard let text = lake.shortStateLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }
        return text
    }

    private var weatherRow: some View {
        HStack(spacing: chipSpacing) {
            weatherConditionPill
            temperatureChip(
                icon: "wind",
                iconColor: AppTheme.airTempGreen,
                value: weather?.airTemperature.map { "\($0.formatted(.number.precision(.fractionLength(0))))°C" } ?? "-"
            )
            temperatureChip(
                icon: "drop.fill",
                iconColor: AppTheme.oceanBlue,
                value: lake.currentWaterTemperature.map { "\($0.formatted(.number.precision(.fractionLength(0))))°C" } ?? "-"
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weatherConditionPill: some View {
        Group {
            if let weather {
                quickConditionChip(
                    icon: weather.conditionSymbol,
                    value: weather.conditionDescription,
                    color: weatherConditionChipStyle(for: weather)
                )
            } else {
                quickConditionChip(
                    icon: "cloud.fill",
                    value: "Unbekannt",
                    color: AppTheme.textSecondary
                )
            }
        }
    }

    private func temperatureChip(icon: String, iconColor: Color, value: String) -> some View {
        HStack(spacing: chipInnerSpacing) {
            Image(systemName: icon)
                .font(.system(size: chipIconSize, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: chipTextSize, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, chipHorizontalPadding)
        .padding(.vertical, chipVerticalPadding)
        .background(iconColor.opacity(0.10), in: Capsule())
    }

    private func weatherConditionChipStyle(for weather: LakeWeather) -> Color {
        guard let code = weather.weatherCode else {
            return AppTheme.textSecondary
        }

        switch code {
        case 0, 1:
            return AppTheme.sunshine
        case 2, 3:
            return AppTheme.textSecondary
        case 45, 48:
            return AppTheme.textSecondary
        case 51, 53, 55:
            return AppTheme.skyBlue
        case 56, 57, 66, 67:
            return AppTheme.lavender
        case 61, 63, 65, 80, 81, 82:
            return AppTheme.oceanBlue
        case 71, 73, 75, 77, 85, 86:
            return AppTheme.lightBlue
        case 95, 96, 99:
            return AppTheme.coral
        default:
            return AppTheme.textSecondary
        }
    }

    private func quickConditionChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: chipInnerSpacing) {
            Image(systemName: icon)
                .font(.system(size: chipIconSize, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: chipTextSize, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, chipHorizontalPadding)
        .padding(.vertical, chipVerticalPadding)
        .background(color.opacity(0.10), in: Capsule())
    }

    private var contentPadding: CGFloat { isExport ? 30 : 20 }
    private var horizontalGap: CGFloat { isExport ? 18 : 12 }
    private var titleSpacing: CGFloat { isExport ? 8 : 5 }
    private var sectionGap: CGFloat { isExport ? 18 : 12 }
    private var footerSpacing: CGFloat { isExport ? 10 : 8 }
    private var footerTopPadding: CGFloat { isExport ? 10 : 6 }

    private var titleFontSize: CGFloat { isExport ? 42 : 20 }
    private var metadataFontSize: CGFloat { isExport ? 26 : 13 }
    private var footerFontSize: CGFloat { isExport ? 34 : 14 }
    private var footerIconSize: CGFloat { isExport ? 24 : 12 }

    private var scoreDiameter: CGFloat { isExport ? 92 : 44 }
    private var scoreFontSize: CGFloat { isExport ? 40 : 16 }

    private var duckCircleSize: CGFloat { isExport ? 184 : 132 }
    private var duckSize: CGFloat { isExport ? 176 : 126 }

    private var chipSpacing: CGFloat { isExport ? 12 : 6 }
    private var chipInnerSpacing: CGFloat { isExport ? 8 : 5 }
    private var chipIconSize: CGFloat { isExport ? 18 : 10 }
    private var chipTextSize: CGFloat { isExport ? 26 : 11 }
    private var chipHorizontalPadding: CGFloat { isExport ? 16 : 8 }
    private var chipVerticalPadding: CGFloat { isExport ? 10 : 5 }
    private var cornerRadius: CGFloat { isExport ? 30 : 26 }
}

#if os(iOS)
private struct ShareActivitySheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#Preview("Share Screen") {
    ShareCardView(lake: .preview, weather: nil)
}

#Preview("Share Export 16:11") {
    let weather = LakeWeather(
        airTemperature: 24,
        uvIndex: 6,
        conditionSymbol: "sun.max.fill",
        conditionDescription: "Klar",
        feelsLike: 25,
        windSpeed: 6,
        precipitationProbability: 0,
        weatherCode: 0
    )
    let lake = BathingWater.preview
    let score = lake.swimScore(weather: weather)
    let gradient = LinearGradient(
        colors: [
            AppTheme.scoreColor(for: score.level).opacity(0.30),
            AppTheme.scoreColor(for: score.level).opacity(0.75),
            AppTheme.skyBlue.opacity(0.65)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    ZStack {
        gradient
        LakeSharePreviewCard(
            lake: lake,
            weather: weather,
            showShadow: false,
            emphasizeScoreBackground: true,
            isExport: true
        )
        .frame(width: 600, height: 372)
    }
    .frame(width: 640, height: 440)
}
