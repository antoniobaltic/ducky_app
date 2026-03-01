import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @Environment(WeatherService.self) private var weatherService
    @Environment(TipJarService.self) private var tipJarService

    @AppStorage("preferredStartTab") private var preferredStartTab = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var isRefreshingData = false
    @State private var isClearingCache = false
    @State private var showClearCacheAlert = false
    @State private var showResetOnboardingAlert = false
    @State private var activeLegalSheet: LegalDocumentType?
    @State private var showTipJarSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        startupSection
                        dataAndCacheSection
                        onboardingSection
                        tipSupportSection
                        infoSection
                        legalSection
                        europeSignatureSection
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Einstellungen")
            .iOSNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .iOSTopBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
            .alert("Cache wirklich leeren?", isPresented: $showClearCacheAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Cache leeren", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("Gespeicherte Gewässer- und Wetterdaten werden entfernt. Die App lädt sie beim nächsten Aktualisieren neu.")
            }
            .alert("Onboarding wiederholen?", isPresented: $showResetOnboardingAlert) {
                Button("Abbrechen", role: .cancel) {}
                Button("Wiederholen", role: .destructive) {
                    hasCompletedOnboarding = false
                    dismiss()
                }
            } message: {
                Text("Das Intro wird jetzt sofort erneut angezeigt.")
            }
            .sheet(item: $activeLegalSheet) { document in
                legalSheet(for: document)
            }
            .sheet(isPresented: $showTipJarSheet) {
                TipJarSheet(entryPoint: .settings)
            }
            .task {
                tipJarService.configureIfNeeded()
                await tipJarService.loadProductsIfNeeded()
            }
        }
    }

    // MARK: - Startup Section

    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "rectangle.3.group.fill", title: "Start")
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 14) {
                Text("Start-Tab beim App-Start")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Picker("Start-Tab beim App-Start", selection: $preferredStartTab) {
                    Text("Home").tag(0)
                    Text("Karte").tag(1)
                    Text("Favoriten").tag(2)
                }
                .pickerStyle(.segmented)
            }
            .appCard()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Data Section

    private var dataAndCacheSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "externaldrive.fill", title: "Daten & Cache")
                .padding(.horizontal, 20)

            VStack(spacing: 14) {
                settingRow(
                    icon: "clock.fill",
                    label: "Letztes Update",
                    value: lastUpdateText,
                    color: AppTheme.skyBlue
                )

                Divider()

                HStack(spacing: 10) {
                    actionButton(
                        title: "Jetzt aktualisieren",
                        systemImage: "arrow.clockwise",
                        color: AppTheme.oceanBlue,
                        isLoading: isRefreshingData
                    ) {
                        refreshNow()
                    }
                    .disabled(isRefreshingData || isClearingCache)

                    actionButton(
                        title: "Cache leeren",
                        systemImage: "trash.fill",
                        color: AppTheme.coral
                    ) {
                        showClearCacheAlert = true
                    }
                    .disabled(isRefreshingData || isClearingCache)
                }
            }
            .appCard()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Onboarding Section

    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "sparkles", title: "Onboarding")
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showResetOnboardingAlert = true
                } label: {
                    Label("Onboarding wiederholen", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(AppTheme.oceanBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshingData || isClearingCache)
            }
            .appCard()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Tip Section

    private var tipSupportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "heart.circle.fill", title: "Ducky unterstützen")
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.warmPink)

                    Text(lastTipSupportText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    showTipJarSheet = true
                } label: {
                    Label("Trinkgeld geben", systemImage: "heart.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(AppTheme.oceanBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Toggle(isOn: Binding(
                    get: { tipJarService.promptsEnabled },
                    set: { tipJarService.setPromptsEnabled($0) }
                )) {
                    Text("Gelegentliche Trinkgeld-Erinnerung")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .tint(AppTheme.oceanBlue)
            }
            .appCard()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "info.circle.fill", title: "Info")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                infoRow(icon: "drop.fill", label: "Daten", value: "AGES Badegewässer", color: AppTheme.oceanBlue)
                Divider().padding(.leading, 62)
                infoRow(icon: "cloud.sun.fill", label: "Wetter", value: "Open-Meteo", color: AppTheme.skyBlue)
                Divider().padding(.leading, 62)
                infoRow(icon: "swift", label: "Version", value: "1.0.0", color: AppTheme.coral)
            }
            .appCard(padding: 0)
            .padding(.horizontal, 16)
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "doc.text.fill", title: "Rechtliches")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                legalRow(
                    icon: "hand.raised.fill",
                    title: "Datenschutz",
                    subtitle: "Welche Daten verarbeitet werden und warum",
                    color: AppTheme.oceanBlue
                ) {
                    activeLegalSheet = .privacy
                }

                Divider().padding(.leading, 62)

                legalRow(
                    icon: "building.2.fill",
                    title: "Impressum",
                    subtitle: "Angaben zu Anbieter, Kontakt und Haftung",
                    color: AppTheme.teal
                ) {
                    activeLegalSheet = .imprint
                }
            }
            .appCard(padding: 0)
            .padding(.horizontal, 16)
        }
    }

    private var europeSignatureSection: some View {
        VStack(spacing: 10) {
            WavingEUFlagView(width: 124, height: 80)
                .padding(.top, 2)

            VStack(spacing: 2) {
                Text("Proudly made in Europe")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("by Baltic Studios")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .appCard()
        .padding(.horizontal, 16)
    }

    private var lastUpdateText: String {
        guard let lastUpdateDate else { return "Noch nicht verfügbar" }
        return Self.lastUpdateFormatter.string(from: lastUpdateDate)
    }

    private var lastTipSupportText: String {
        guard let lastTipDate = tipJarService.lastTipDate else {
            return "Noch kein Trinkgeld gegeben."
        }
        return "Letztes Trinkgeld: \(Self.lastTipFormatter.string(from: lastTipDate))"
    }

    private var lastUpdateDate: Date? {
        [dataService.lastUpdated, weatherService.lastCacheUpdate].compactMap { $0 }.max()
    }

    private static let lastUpdateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_AT")
        formatter.dateFormat = "d. MMM yyyy\n'um' HH:mm"
        formatter.shortMonthSymbols = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
        return formatter
    }()

    private static let lastTipFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_AT")
        formatter.dateFormat = "d. MMM yyyy 'um' HH:mm"
        formatter.shortMonthSymbols = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
        return formatter
    }()

    private func refreshNow() {
        guard !isRefreshingData else { return }
        isRefreshingData = true

        Task {
            await dataService.refresh()
            let lakes = dataService.lakes
            if !lakes.isEmpty {
                await weatherService.hydrateAllWeather(for: lakes, forceRefresh: true)
            }
            isRefreshingData = false
        }
    }

    private func clearCache() {
        guard !isClearingCache else { return }
        isClearingCache = true

        dataService.clearCache()
        weatherService.clearCache()
        isClearingCache = false
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.teal)
            Text(title)
                .font(AppTheme.sectionTitle)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func settingRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        color: Color,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(color)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .padding(.horizontal, 10)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func infoRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 32)

            Text(label)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
    }

    private func legalRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func legalSheet(for document: LegalDocumentType) -> some View {
        switch document {
        case .privacy:
            LegalDocumentView(
                type: .privacy,
                title: "Datenschutzerklärung",
                icon: "hand.raised.fill",
                accent: AppTheme.oceanBlue
            )
        case .imprint:
            LegalDocumentView(
                type: .imprint,
                title: "Impressum",
                icon: "building.2.fill",
                accent: AppTheme.teal
            )
        }
    }
}

#Preview {
    SettingsView()
        .environment(DataService.shared)
        .environment(WeatherService.shared)
        .environment(TipJarService.shared)
}

private enum LegalDocumentType: String, Identifiable {
    case privacy
    case imprint

    var id: String { rawValue }
}

private struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss

    let type: LegalDocumentType
    let title: String
    let icon: String
    let accent: Color

    private enum LegalMeta {
        static let ownerName = "Antonio Baltic"
        static let publisher = "Baltic Studios"
        static let appName = "Ducky"
        static let version = "1.0.0"
        static let postalAddress = "Schörgelgasse 55\n8010 Graz\nÖsterreich"
        static let contactEmail = "balticstudios@icloud.com"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        headerCard

                        if type == .privacy {
                            privacyContent
                        } else {
                            imprintContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(title)
            .iOSNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .iOSTopBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.oceanBlue)
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(type == .privacy ? "Datenschutz in Kürze" : "Rechtliche Anbieterangaben")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(type == .privacy ? "Transparenz zu Daten, Rechten und Diensten" : "Angaben zu Anbieter, Kontakt und Haftung")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var privacyContent: some View {
        Group {
            legalCard(
                heading: "1. Verantwortlicher",
                lines: [
                    "\(LegalMeta.ownerName)",
                    "\(LegalMeta.publisher)",
                    "Adresse:\n\(LegalMeta.postalAddress)",
                    "Kontakt: \(LegalMeta.contactEmail)"
                ]
            )

            legalCard(
                heading: "2. Welche Daten verarbeitet die App?",
                lines: [
                    "Standortdaten: Nur nach deiner Freigabe, um Gewässer in deiner Nähe zu zeigen und Distanzen zu berechnen.",
                    "Technische Anfragen: Beim Laden von Wetter-, Qualitäts- und Karteninhalten werden API-Anfragen an externe Dienste gestellt.",
                    "Lokaler Cache: Gewässer- und Wetterdaten werden auf dem Gerät zwischengespeichert, damit die App schneller startet.",
                    "Keine Konten, keine Tracking-ID, keine Werbung, kein Profiling."
                ]
            )

            legalCard(
                heading: "3. Wofür und auf welcher Grundlage?",
                lines: [
                    "Die Verarbeitung erfolgt zur Bereitstellung der Kernfunktionen der App.",
                    "Standortdaten nur mit deiner Einwilligung (Berechtigung in iOS).",
                    "Sonstige Verarbeitung zur Vertragserfüllung bzw. zur technischen Funktionsfähigkeit."
                ]
            )

            legalCard(
                heading: "4. Empfänger / externe Dienste",
                lines: [
                    "AGES (Badegewässerdaten)",
                    "Open-Meteo (Wetterdaten, aktueller Stand der App)",
                    "Wikipedia API (Wissensinhalte pro Gewässer)",
                    "Apple Maps (Routen- und Ortsfunktionen)",
                    "Hinweis: Dabei kann deine IP-Adresse technisch bedingt beim jeweiligen Dienst verarbeitet werden."
                ]
            )

            legalCard(
                heading: "5. Speicherdauer",
                lines: [
                    "Zwischengespeicherte Gewässer- und Wetterdaten werden lokal im App-Cache gespeichert.",
                    "Du kannst den Cache jederzeit in den Einstellungen löschen.",
                    "Es gibt keine Benutzerkonten in der App."
                ]
            )

            legalCard(
                heading: "6. Deine Rechte",
                lines: [
                    "Du hast Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung und Datenübertragbarkeit nach DSGVO.",
                    "Du kannst Standortzugriff jederzeit in iOS entziehen.",
                    "Beschwerdestelle in Österreich: Datenschutzbehörde (DSB)."
                ]
            )
        }
    }

    private var imprintContent: some View {
        Group {
            legalCard(
                heading: "Medieninhaber & Herausgeber",
                lines: [
                    LegalMeta.ownerName,
                    "Publishing-Name: \(LegalMeta.publisher)",
                    "App: \(LegalMeta.appName) (\(LegalMeta.version))"
                ]
            )

            legalCard(
                heading: "Kontakt",
                lines: [
                    "Adresse:\n\(LegalMeta.postalAddress)",
                    "E-Mail: \(LegalMeta.contactEmail)"
                ]
            )

            legalCard(
                heading: "Unternehmensgegenstand",
                lines: [
                    "Entwicklung und Betrieb von Software-Produkten (Mobile Apps)."
                ]
            )

            legalCard(
                heading: "Inhaltliche Verantwortung",
                lines: [
                    "Für Inhalte der App verantwortlich: \(LegalMeta.ownerName)",
                    "Ort der inhaltlichen Tätigkeit: Graz, Österreich"
                ]
            )

            legalCard(
                heading: "Haftung & Quellen",
                lines: [
                    "Trotz sorgfältiger Prüfung wird keine Gewähr für Vollständigkeit, Aktualität und Richtigkeit externer Daten übernommen.",
                    "Die App verwendet Datenquellen und Dienste Dritter (AGES, Open-Meteo, Apple Maps, Wikipedia).",
                    "Maßgeblich sind die Bedingungen und Verfügbarkeit der jeweiligen Anbieter."
                ]
            )
        }
    }

    private func legalCard(heading: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(accent.opacity(0.35))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(line)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}
