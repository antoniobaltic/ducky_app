import SwiftUI
import CoreLocation
import StoreKit
#if os(iOS)
import UIKit
#endif

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int
    @State private var hasAppeared = false
    @State private var duckBob = false
    @State private var columboBlackout = false
    @State private var showColumboPage = false
    @Environment(LocationService.self) private var locationService
    @Environment(TipJarService.self) private var tipJarService
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
        _currentPage = State(initialValue: min(max(resolvedInitialPage, 0), 2))
    }

    var body: some View {
        ZStack {
            onboardingBackground

            if showColumboPage {
                // Page 3: Columbo reveal
                VStack(spacing: 0) {
                    topBar
                    columboPage
                    columboBottomControls
                }
                .transition(.identity)
            } else {
                VStack(spacing: 0) {
                    topBar

                    TabView(selection: $currentPage) {
                        welcomePage.tag(0)
                        locationPage.tag(1)
                        readyPage.tag(2)
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #endif
                    .animation(AppTheme.gentleSpring, value: currentPage)

                    bottomControls
                }
            }

            // Columbo blackout overlay
            Color.black
                .ignoresSafeArea()
                .opacity(columboBlackout ? 1 : 0)
                .allowsHitTesting(columboBlackout)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Background

    private var onboardingBackground: some View {
        WelcomeSceneView()
            .ignoresSafeArea()
    }


    // MARK: - Controls

    private var topBar: some View {
        Color.clear
            .frame(height: 18)
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
                if currentPage == 2 {
                    // Columbo moment — fade to black, then reveal page 3
                    Haptics.medium()
                    triggerColumboReveal()
                } else if currentPage < 2 {
                    Haptics.light()
                    withAnimation(AppTheme.gentleSpring) {
                        currentPage += 1
                    }
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
        currentPage == 2 ? "Los geht's!" : currentPage == 3 ? "Jetzt wirklich!" : "Weiter"
    }

    private func completeOnboarding() {
        Haptics.medium()
        withAnimation(AppTheme.springAnimation) {
            hasCompletedOnboarding = true
        }
    }


    // MARK: - Page 0: Welcome + Preview

    private var welcomePage: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.skyBlue.opacity(0.15))
                            .frame(width: 155, height: 155)

                        Circle()
                            .stroke(AppTheme.skyBlue.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 185, height: 185)

                        FloatingBubblesView(count: 8, color: AppTheme.skyBlue.opacity(0.35))
                            .frame(width: 200, height: 175)
                            .allowsHitTesting(false)

                        DuckView(state: .begeistert, size: 120)
                            .offset(y: duckBob ? -4 : 4)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: duckBob
                            )
                    }
                    .frame(height: 185)
                    .onAppear { duckBob = true }

                    VStack(spacing: 6) {
                        Text("Servus, ich bin Ducky!")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)

                        Text("Ich zeige dir die besten Badegewässer in Österreich. Wetter, Wasser, Qualität.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.9)

                        Text("Alles in einem Score.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    previewCard
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .frame(minHeight: proxy.size.height - 6, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wörthersee")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Klagenfurt am Wörthersee")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 8) {
                            // Weather condition pill
                            HStack(spacing: 4) {
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.sunshine)
                                Text("Sonnig")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.sunshine.opacity(0.12), in: Capsule())

                            // Air temp pill
                            HStack(spacing: 4) {
                                Image(systemName: "wind")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.airTempGreen)
                                Text("26°")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.airTempGreen.opacity(0.12), in: Capsule())

                            // Water temp pill
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.skyBlue)
                                Text("22°")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.skyBlue.opacity(0.12), in: Capsule())
                        }
                    }
                    Spacer(minLength: 4)
                    SwimScoreBadge(score: previewScore, size: .large)
                }
            }
            .padding(14)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }

    private var previewScore: SwimScore {
        SwimScore(
            total: 8.4,
            baseScore: 8.8,
            weatherScore: 9.0,
            waterTempScore: 8.5,
            qualityPenalty: 0.0,
            bacteriaPenalty: 0.0,
            hasBacteriaData: false,
            qualityBand: .ausgezeichnet,
            forcedReason: nil,
            level: .perfekt
        )
    }

    // MARK: - Page 1: Location

    private var locationDuckState: DuckState {
        locationService.isAuthorized ? .zufrieden : .zoegernd
    }

    private var locationPage: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.skyBlue.opacity(0.15))
                            .frame(width: 155, height: 155)

                        Circle()
                            .stroke(AppTheme.skyBlue.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 185, height: 185)

                        FloatingBubblesView(count: 8, color: AppTheme.skyBlue.opacity(0.35))
                            .frame(width: 200, height: 175)
                            .allowsHitTesting(false)

                        DuckView(state: locationDuckState, size: 120)
                            .offset(y: duckBob ? -4 : 4)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: duckBob
                            )
                    }
                    .frame(height: 185)
                    .animation(AppTheme.gentleSpring, value: locationService.isAuthorized)

                    VStack(spacing: 6) {
                        Text("Wo bist du gerade?")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)

                        Text("Dann zeige ich dir die besten Seen\nin deiner Nähe.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.9)

                    }

                    locationCard
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .frame(minHeight: proxy.size.height - 6, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var locationCard: some View {
        VStack(spacing: 12) {
            if locationService.isAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Standort trianguliert!")
                        .foregroundStyle(.white)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.oceanBlue, in: Capsule())
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
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.oceanBlue, in: Capsule())
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
    }

    // MARK: - Page 2: Ready

    private var readyPage: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.skyBlue.opacity(0.15))
                            .frame(width: 155, height: 155)

                        Circle()
                            .stroke(AppTheme.skyBlue.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 185, height: 185)

                        FloatingBubblesView(count: 8, color: AppTheme.skyBlue.opacity(0.35))
                            .frame(width: 200, height: 175)
                            .allowsHitTesting(false)

                        DuckView(state: .begeistert, size: 120)
                            .offset(y: duckBob ? -4 : 4)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: duckBob
                            )
                    }
                    .frame(height: 185)

                    VStack(spacing: 6) {
                        Text("Gehen wir baden!")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)

                        Text("Alle Daten ready. Ducky-Algorithmus aktiviert.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                    }

                    featureCard
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .frame(minHeight: proxy.size.height - 6, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var featureCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                featureChip(icon: "star.fill", label: "Score", color: AppTheme.sunshine)
                featureChip(icon: "cloud.sun.fill", label: "Wetter", color: AppTheme.skyBlue)
                featureChip(icon: "map.fill", label: "Karte", color: AppTheme.oceanBlue)
            }
            HStack(spacing: 8) {
                featureChip(icon: "heart.fill", label: "Favs", color: AppTheme.warmPink)
                featureChip(icon: "book.fill", label: "Wiki", color: .purple)
                featureChip(icon: "arrow.triangle.turn.up.right.diamond.fill", label: "Route", color: AppTheme.freshGreen)
            }
        }
    }

    private func featureChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(AppTheme.cardBackground, in: Capsule())
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - Page 3: Columbo ("Eine Sache noch...")

    private func triggerColumboReveal() {
        withAnimation(.easeOut(duration: 0.7)) {
            columboBlackout = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            showColumboPage = true
            withAnimation(.easeIn(duration: 0.8)) {
                columboBlackout = false
            }
        }
    }

    private var columboPage: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.skyBlue.opacity(0.15))
                            .frame(width: 155, height: 155)

                        Circle()
                            .stroke(AppTheme.skyBlue.opacity(0.25), lineWidth: 1.5)
                            .frame(width: 185, height: 185)

                        FloatingBubblesView(count: 8, color: AppTheme.skyBlue.opacity(0.35))
                            .frame(width: 200, height: 175)
                            .allowsHitTesting(false)

                        DuckView(state: .columbo, size: 120)
                            .offset(y: duckBob ? -4 : 4)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: duckBob
                            )
                    }
                    .frame(height: 185)

                    VStack(spacing: 6) {
                        Text("Eine Sache noch...")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)

                        Text("Unterstütze Ducky (und seinen Indie-Entwickler) mit einer kleinen Brotspende.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.9)

                        Text("Jeder Krümel hilft!")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    tipOptions

                    if let notice = tipJarService.purchaseNotice {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.warmPink)
                            Text(notice)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                        .transition(.opacity)
                    }

                    if let error = tipJarService.purchaseError {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.coral)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 8)
                .frame(minHeight: proxy.size.height - 6, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            tipJarService.configureIfNeeded()
            await tipJarService.loadProductsIfNeeded()
        }
    }

    private var tipOptions: some View {
        HStack(spacing: 10) {
            if tipJarService.products.isEmpty {
                // Fallback with static catalog
                ForEach(TipJarService.tipCatalog) { def in
                    tipFallbackButton(def: def)
                }
            } else {
                ForEach(tipJarService.products, id: \.id) { product in
                    tipButton(product: product)
                }
            }
        }
    }

    private func tipButton(product: Product) -> some View {
        let isPurchasing = tipJarService.purchaseInFlightProductID == product.id

        return Button {
            Task {
                let outcome = await tipJarService.purchase(product)
                if outcome == .success {
                    Haptics.success()
                }
            }
        } label: {
            VStack(spacing: 6) {
                Text(product.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(height: 18)
                } else {
                    Text(product.displayPrice)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(tipJarService.purchaseInFlightProductID != nil)
    }

    private func tipFallbackButton(def: TipJarService.TipProductDefinition) -> some View {
        VStack(spacing: 6) {
            Text(def.suggestedDisplayName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Text("···")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func tipIconView(for productID: String) -> some View {
        let (icon, color): (String, Color) = {
            switch productID {
            case "antoniobaltic.ducky.tip.toast":  return ("cup.and.saucer.fill", AppTheme.sunshine)
            case "antoniobaltic.ducky.tip.medium": return ("takeoutbag.and.cup.and.straw.fill", AppTheme.oceanBlue)
            case "antoniobaltic.ducky.tip.large":  return ("fork.knife", AppTheme.warmPink)
            default: return ("cup.and.saucer.fill", AppTheme.sunshine)
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(color)
    }

    private var columboBottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == 3 ? AppTheme.oceanBlue : AppTheme.oceanBlue.opacity(0.2))
                        .frame(width: i == 3 ? 28 : 8, height: 8)
                }
            }

            Button {
                completeOnboarding()
            } label: {
                Text("Jetzt wirklich!")
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

    // MARK: - Helpers

    private var isLocationDenied: Bool {
        locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted
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
        .environment(TipJarService.shared)
}

#Preview("Onboarding - Seite 1 (SE)") {
    OnboardingView(hasCompletedOnboarding: .constant(false), initialPage: 0)
        .environment(LocationService.shared)
        .environment(TipJarService.shared)
        .frame(width: 320, height: 700)
}

#Preview("Onboarding - Seite 2 (SE)") {
    OnboardingView(hasCompletedOnboarding: .constant(false), initialPage: 1)
        .environment(LocationService.shared)
        .environment(TipJarService.shared)
        .frame(width: 320, height: 700)
}

#Preview("Onboarding - Seite 3 (SE)") {
    OnboardingView(hasCompletedOnboarding: .constant(false), initialPage: 2)
        .environment(LocationService.shared)
        .environment(TipJarService.shared)
        .frame(width: 320, height: 700)
}
