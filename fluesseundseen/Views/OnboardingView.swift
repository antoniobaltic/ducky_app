import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var appear = false
    @Environment(LocationService.self) private var locationService

    var body: some View {
        ZStack {
            // Background
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Pages
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    locationPage.tag(2)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(AppTheme.gentleSpring, value: currentPage)

                // Page indicator + button
                VStack(spacing: 28) {
                    // Custom page dots
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? AppTheme.oceanBlue : AppTheme.oceanBlue.opacity(0.2))
                                .frame(width: i == currentPage ? 28 : 8, height: 8)
                                .animation(AppTheme.quickSpring, value: currentPage)
                        }
                    }

                    // Action button
                    Button {
                        if currentPage < 2 {
                            withAnimation(AppTheme.gentleSpring) {
                                currentPage += 1
                            }
                        } else {
                            withAnimation(AppTheme.springAnimation) {
                                hasCompletedOnboarding = true
                            }
                        }
                    } label: {
                        Text(currentPage == 2 ? "Los geht's!" : "Weiter")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.oceanBlue, in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                            .shadow(color: AppTheme.oceanBlue.opacity(0.3), radius: 12, y: 6)
                    }
                    .padding(.horizontal, 32)

                    if currentPage < 2 {
                        Button("Überspringen") {
                            withAnimation(AppTheme.springAnimation) {
                                hasCompletedOnboarding = true
                            }
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appear = true }
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 24) {
                Spacer()

                // Duck mascot
                ZStack {
                    Circle()
                        .fill(AppTheme.sunshine.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .scaleEffect(appear ? 1 : 0.5)

                    Circle()
                        .fill(AppTheme.skyBlue.opacity(0.1))
                        .frame(width: 260, height: 260)
                        .scaleEffect(appear ? 1 : 0.3)

                    DuckView(state: .begeistert, size: 160)
                        .scaleEffect(appear ? 1 : 0.6)
                        .offset(y: appear ? 0 : 20)
                }
                .padding(.bottom, 8)

                VStack(spacing: 12) {
                    Text("Willkommen!")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Ich bin **Ducky**, dein Bade-Buddy!")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Text("Ich helfe dir, die besten\nBadegewässer in Österreich zu finden.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)

            // Water wave at bottom
            WaterWaveView(baseColor: AppTheme.oceanBlue, height: 40, speed: 0.7)
                .frame(height: 40)
                .opacity(0.4)
        }
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Was kann Ducky?")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(spacing: 20) {
                featureRow(
                    icon: "thermometer.sun.fill",
                    color: AppTheme.coral,
                    title: "Wassertemperatur",
                    subtitle: "Aktuelle Messdaten aller Seen"
                )
                featureRow(
                    icon: "checkmark.shield.fill",
                    color: AppTheme.freshGreen,
                    title: "Wasserqualität",
                    subtitle: "Geprüft nach EU-Standard"
                )
                featureRow(
                    icon: "cloud.sun.fill",
                    color: AppTheme.skyBlue,
                    title: "Wetter vor Ort",
                    subtitle: "Lufttemperatur & UV-Index"
                )
                featureRow(
                    icon: "map.fill",
                    color: AppTheme.lavender,
                    title: "Kartenansicht",
                    subtitle: "Alle Gewässer auf einer Karte"
                )
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
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
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Location Page

    private var locationPage: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppTheme.skyBlue.opacity(0.1))
                        .frame(width: 180, height: 180)

                    FloatingBubblesView(count: 5, color: AppTheme.skyBlue.opacity(0.3))
                        .frame(width: 200, height: 200)

                    Image(systemName: "location.circle.fill")
                        .font(.system(size: 80))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.oceanBlue)
                }

                VStack(spacing: 12) {
                    Text("Seen in deiner Nähe")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Erlaube Ducky Zugriff auf deinen\nStandort, um nahe Gewässer zu finden.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                if !locationService.isAuthorized {
                    Button {
                        locationService.requestPermission()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                            Text("Standort freigeben")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.oceanBlue.opacity(0.12), in: Capsule())
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.freshGreen)
                        Text("Standort freigegeben")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.freshGreen)
                    }
                    .padding(.top, 8)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)

            // Water wave at bottom
            WaterWaveView(baseColor: AppTheme.teal, height: 35, speed: 0.6)
                .frame(height: 35)
                .opacity(0.35)
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environment(LocationService.shared)
}
