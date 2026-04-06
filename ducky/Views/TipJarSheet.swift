import SwiftUI

struct TipJarSheet: View {
    enum EntryPoint {
        case settings
        case prompt
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(TipJarService.self) private var tipJarService

    let entryPoint: EntryPoint

    private var isPrompt: Bool { entryPoint == .prompt }

    var body: some View {
        if isPrompt {
            promptView
        } else {
            settingsView
        }
    }

    // MARK: - Prompt View (Columbo-style)

    @State private var duckBob = false
    @State private var settingsTipNotice: String?

    private var promptView: some View {
        NavigationStack {
            ZStack {
                WelcomeSceneView()
                    .ignoresSafeArea()

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
                                Text("Unterstütze die App")
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

                            promptTipOptions

                            // Dismiss button
                            Button {
                                tipJarService.snoozePrompt()
                                dismiss()
                            } label: {
                                Text("Nicht jetzt, Ducky...")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.oceanBlue, in: RoundedRectangle(cornerRadius: AppTheme.buttonRadius, style: .continuous))
                            }
                            .padding(.top, 4)

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
            .navigationBarHidden(true)
            .onAppear { duckBob = true }
            .task {
                tipJarService.configureIfNeeded()
                await tipJarService.loadProductsIfNeeded()
            }
        }
    }

    private var promptTipOptions: some View {
        HStack(spacing: 10) {
            if tipJarService.products.isEmpty {
                ForEach(TipJarService.tipCatalog) { def in
                    promptFallbackTip(def: def)
                }
            } else {
                ForEach(tipJarService.products, id: \.id) { product in
                    promptTipButton(product: product)
                }
            }
        }
    }

    private func promptTipButton(product: TipJarService.TipProduct) -> some View {
        let isPurchasing = tipJarService.purchaseInFlightProductID == product.id
        return Button {
            guard !isPurchasing else { return }
            Task {
                let outcome = await tipJarService.purchase(product)
                if outcome == .success {
                    Haptics.success()
                    dismiss()
                }
            }
        } label: {
            VStack(spacing: 6) {
                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(height: 20)
                } else {
                    Text(product.displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Text(product.displayPrice)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.oceanBlue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(tipJarService.purchaseInFlightProductID != nil)
    }

    private func promptFallbackTip(def: TipJarService.TipProductDefinition) -> some View {
        VStack(spacing: 6) {
            Text(def.suggestedDisplayName)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text("—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }

    // MARK: - Settings View (full detail)

    private var settingsView: some View {
        NavigationStack {
            ZStack {
                AppTheme.favouritesGradient.ignoresSafeArea()

                SettingsBubblesView(color: AppTheme.warmPink)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerCard
                        productListCard
                        supportStatusCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .iOSTopBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
            .task {
                tipJarService.configureIfNeeded()
                await tipJarService.loadProductsIfNeeded()
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            DuckView(state: .zufrieden, size: 56)
                .frame(width: 62, height: 62)
                .background(AppTheme.oceanBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Ducky-Brotkassa")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Unterstütze Ducky (und seinen Indie-Entwickler) mit einer kleinen Brotspende. Jeder Krümel hilft!")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var productListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wähle ein Trinkgeld")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            if tipJarService.isLoadingProducts {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Trinkgeld-Optionen werden geladen...")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if !tipJarService.products.isEmpty {
                VStack(spacing: 10) {
                    ForEach(tipJarService.products, id: \.id) { product in
                        tipProductButton(product)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Noch keine Trinkgeld-Optionen verfügbar.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Die Trinkgeld-Optionen werden freigeschaltet, sobald sie in App Store Connect fertig eingerichtet sind.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(TipJarService.tipCatalog) { definition in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(definition.suggestedDisplayName)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(definition.suggestedDescription)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .background(AppTheme.searchBarBackground.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        Task { await tipJarService.loadProducts() }
                    } label: {
                        Label("Erneut laden", systemImage: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.oceanBlue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(AppTheme.oceanBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var supportStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusLine(
                icon: "heart.circle.fill",
                title: "Gegebene Trinkgelder",
                value: "\(tipJarService.totalTipCount)",
                color: AppTheme.warmPink
            )

            Divider()

            statusLine(
                icon: "clock.fill",
                title: "Letztes Trinkgeld",
                value: lastTipText,
                color: AppTheme.teal
            )

            if let notice = settingsTipNotice {
                Divider()
                Text(notice)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.freshGreen)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = tipJarService.purchaseError, !tipJarService.products.isEmpty {
                Divider()
                Text(error)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func tipProductButton(_ product: TipJarService.TipProduct) -> some View {
        let isActivePurchase = tipJarService.purchaseInFlightProductID == product.id
        return Button {
            guard !isActivePurchase else { return }
            Task {
                let outcome = await tipJarService.purchase(product)
                if outcome == .success {
                    Haptics.success()
                    settingsTipNotice = tipJarService.purchaseNotice
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    if !product.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(product.description)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                if isActivePurchase {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.oceanBlue)
                        .frame(width: 44)
                } else {
                    Text(product.displayPrice)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(AppTheme.oceanBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(AppTheme.searchBarBackground.opacity(0.85), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(tipJarService.purchaseInFlightProductID != nil)
    }

    private func statusLine(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var lastTipText: String {
        guard let lastTipDate = tipJarService.lastTipDate else { return "Noch keines" }
        return Self.lastTipFormatter.string(from: lastTipDate)
    }

    private static let lastTipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_AT")
        formatter.dateFormat = "d. MMM yyyy 'um' HH:mm"
        formatter.shortMonthSymbols = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
        return formatter
    }()
}

#Preview("From Settings") {
    TipJarSheet(entryPoint: .settings)
        .environment(TipJarService.previewInstance())
}

#Preview("Prompt") {
    TipJarSheet(entryPoint: .prompt)
        .environment(TipJarService.previewInstance())
}
