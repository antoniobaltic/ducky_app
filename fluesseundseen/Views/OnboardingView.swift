import SwiftUI
import CoreLocation
#if os(iOS)
import UIKit
#endif

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int
    @State private var hasAppeared = false
    @Environment(LocationService.self) private var locationService
    @Environment(\.openURL) private var openURL

    private let pageCount = 4

    init(hasCompletedOnboarding: Binding<Bool>, initialPage: Int = 0) {
        _hasCompletedOnboarding = hasCompletedOnboarding
        #if DEBUG
        let envPage = ProcessInfo.processInfo.environment["ONBOARDING_PREVIEW_PAGE"].flatMap(Int.init)
        let resolvedInitialPage = envPage ?? initialPage
        #else
        let resolvedInitialPage = initialPage
        #endif
        _currentPage = State(initialValue: min(max(resolvedInitialPage, 0), 3))
    }

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    locationPage.tag(2)
                    europePage.tag(3)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(AppTheme.gentleSpring, value: currentPage)

                bottomControls
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                hasAppeared = true
            }
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            BubbleBackground(color: backgroundAccent.opacity(0.95))
                .opacity(0.35)
                .ignoresSafeArea()

            VStack {
                Spacer()
                WaterWaveView(baseColor: backgroundAccent, height: 62, speed: 0.8)
                    .frame(height: 62)
                    .opacity(0.22)
            }
            .ignoresSafeArea()
        }
        .animation(AppTheme.smoothEase, value: currentPage)
    }

    private var backgroundAccent: Color {
        switch currentPage {
        case 0: return AppTheme.sunshine
        case 1: return AppTheme.oceanBlue
        case 2: return AppTheme.teal
        default: return AppTheme.oceanBlue
        }
    }

    private var backgroundColors: [Color] {
        switch currentPage {
        case 0:
            return [
                AppTheme.sunshine.opacity(0.18),
                AppTheme.skyBlue.opacity(0.16),
                AppTheme.pageBackground
            ]
        case 1:
            return [
                AppTheme.skyBlue.opacity(0.20),
                AppTheme.teal.opacity(0.14),
                AppTheme.pageBackground
            ]
        case 2:
            return [
                AppTheme.teal.opacity(0.18),
                AppTheme.lightBlue.opacity(0.16),
                AppTheme.pageBackground
            ]
        default:
            return [
                AppTheme.oceanBlue.opacity(0.17),
                AppTheme.sunshine.opacity(0.14),
                AppTheme.pageBackground
            ]
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()
            if currentPage < pageCount - 1 {
                Button("Überspringen") {
                    completeOnboarding()
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AppTheme.cardBackground.opacity(0.85), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppTheme.cardStroke.opacity(0.55), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? AppTheme.oceanBlue : AppTheme.oceanBlue.opacity(0.2))
                        .frame(width: i == currentPage ? 28 : 8, height: 8)
                        .animation(AppTheme.quickSpring, value: currentPage)
                }
            }

            Button {
                if currentPage < pageCount - 1 {
                    Haptics.light()
                    withAnimation(AppTheme.gentleSpring) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                Text(primaryButtonTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        AppTheme.oceanBlue,
                        in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous)
                    )
                    .shadow(color: AppTheme.oceanBlue.opacity(0.3), radius: 12, y: 6)
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 10)
        .padding(.bottom, 30)
    }

    private var primaryButtonTitle: String {
        guard currentPage == pageCount - 1 else { return "Weiter" }
        return "Gemma!"
    }

    private func completeOnboarding() {
        Haptics.medium()
        withAnimation(AppTheme.springAnimation) {
            hasCompletedOnboarding = true
        }
    }

    private func onboardingPage<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    content()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .frame(minHeight: proxy.size.height - 6, alignment: .top)
            }
        }
    }

    // MARK: - Page 1

    private var welcomePage: some View {
        onboardingPage {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(AppTheme.sunshine.opacity(0.22))
                        .frame(width: 196, height: 196)

                    Circle()
                        .stroke(AppTheme.sunshine.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 232, height: 232)

                    FloatingBubblesView(count: 8, color: AppTheme.skyBlue.opacity(0.35))
                        .frame(width: 250, height: 220)
                        .allowsHitTesting(false)

                    DuckView(state: .begeistert, size: 160)
                        .scaleEffect(hasAppeared ? 1 : 0.88)
                        .animation(AppTheme.entranceSpring, value: hasAppeared)
                }
                .frame(height: 230)
            }

            VStack(spacing: 10) {
                Text("Servas, i bin da Ducky!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)

                Text("I check des Wetter, Wasser und AGES-Daten.\nDann kriegst sofort einen aussagekräftigen Score ohne Herumratn.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .lineLimit(6)
                    .minimumScaleFactor(0.9)
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.oceanBlue)
                    .padding(.top, 1)

                Text("ALLES LIVE! Alle Badegewässer in Österreich, oida!")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard(padding: 12)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.coral)
                    .padding(.top, 1)

                Text("Wenn's leiwand is, schrei i REIN DA. Wenn ned, bleibst trocken. Deal?")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard(padding: 12)
            .padding(.top, 2)
        }
    }

    // MARK: - Page 2

    private var featuresPage: some View {
        onboardingPage {
            VStack(spacing: 8) {
                Text("Alles Wichtige. Kein Blabla.")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text("So findest du in 10 Sekunden a gscheids Gewässer.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            VStack(spacing: 14) {
                featureRow(
                    icon: "star.fill",
                    color: AppTheme.sunshine,
                    title: "Score zuerst",
                    subtitle: "I sortier die Seen und Gewässer sofort nach Score. Quantum-Algorithmus!"
                )
                featureRow(
                    icon: "wind",
                    color: AppTheme.airTempGreen,
                    title: "Wetter + Wasser",
                    subtitle: "Zustand, Luft und Wasser auf einen Blick."
                )
                featureRow(
                    icon: "map.fill",
                    color: AppTheme.oceanBlue,
                    title: "Karte, Favoriten, Teilen",
                    subtitle: "Platzerl merken, Route starten und teilen."
                )
                featureRow(
                    icon: "book.pages.fill",
                    color: AppTheme.lavender,
                    title: "Wikipedia + Apple Maps",
                    subtitle: "Direkt in da App: Wissen, Infos und wiest hin kommst."
                )
            }
        }
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Spacer()
        }
        .appCard()
    }

    // MARK: - Page 3

    private var locationPage: some View {
        onboardingPage {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.skyBlue.opacity(0.18))
                        .frame(width: 176, height: 176)

                    FloatingBubblesView(count: 5, color: AppTheme.skyBlue.opacity(0.3))
                        .frame(width: 200, height: 200)

                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 82))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.oceanBlue)
                }
                .frame(height: 200)
            }

            VStack(spacing: 10) {
                Text("Zeig ma kurz deinen Standort.")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)

                Text("Dann kriegst die Top-5 rund um di. I stalk nur Gewässer, ned Menschen.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }

            VStack(spacing: 12) {
                if locationService.isAuthorized {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.freshGreen)
                        Text("Standort passt. Ducky is startklar.")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.freshGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.freshGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Button {
                        if isLocationDenied {
                            openAppSettings()
                        } else {
                            locationService.requestPermission()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isLocationDenied ? "gearshape.fill" : "location.fill")
                            Text(isLocationDenied ? "Einstellungen öffnen" : "Standort freigeben")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.oceanBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if isLocationDenied {
                        Text("Standortzugriff ist deaktiviert. Aktiviere ihn in den Einstellungen.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
            }
            .appCard()

            VStack(spacing: 8) {
                locationInfoRow(icon: "location.fill", text: "Top 5 in deiner Nähe auf Home")
                locationInfoRow(icon: "arrow.up.arrow.down", text: "Sortieren nach Distanz")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Page 4

    private var europePage: some View {
        onboardingPage {
            VStack(spacing: 18) {
                WavingEUFlagView()
                    .padding(.top, 10)

                Text("Proudly made in Europe.")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text("Gebaut in Graz, Europa. Mit Herz fürs Wossa und a bisserl Wahnsinn.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .lineLimit(3)
            }

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.oceanBlue)
                    .padding(.top, 1)

                Text("Danke fürs Reinschaun. Jetzt gemma baden.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
    }

    private var isLocationDenied: Bool {
        locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted
    }

    private func locationInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.oceanBlue)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func openAppSettings() {
#if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
#endif
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environment(LocationService.shared)
}

#Preview("Onboarding - Seite 1 (SE)") {
    OnboardingView(hasCompletedOnboarding: .constant(false), initialPage: 0)
        .environment(LocationService.shared)
        .frame(width: 320, height: 700)
}

#Preview("Onboarding - Seite 2 (SE)") {
    OnboardingView(hasCompletedOnboarding: .constant(false), initialPage: 1)
        .environment(LocationService.shared)
        .frame(width: 320, height: 700)
}

#Preview("Onboarding - Seite 3 (SE)") {
    OnboardingView(hasCompletedOnboarding: .constant(false), initialPage: 2)
        .environment(LocationService.shared)
        .frame(width: 320, height: 700)
}

#Preview("Onboarding - Seite 4 (SE)") {
    OnboardingView(hasCompletedOnboarding: .constant(false), initialPage: 3)
        .environment(LocationService.shared)
        .frame(width: 320, height: 700)
}
