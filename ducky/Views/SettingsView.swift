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
                AppTheme.settingsGradient.ignoresSafeArea()

                SettingsBubblesView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        tipSupportSection
                        startupSection
                        dataAndCacheSection
                        onboardingSection
                        infoSection
                        legalSection
                        europeSignatureSection
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
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
                    color: AppTheme.oceanBlue
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
                        .foregroundStyle(AppTheme.oceanBlue)

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
                infoRow(icon: "cloud.sun.fill", label: "Wetter", value: "Open-Meteo", color: AppTheme.oceanBlue)
                Divider().padding(.leading, 62)
                infoRow(icon: "map.fill", label: "Karten", value: "Apple Maps", color: AppTheme.oceanBlue)
                Divider().padding(.leading, 62)
                infoRow(icon: "book.fill", label: "Wiki", value: "Wikipedia", color: AppTheme.oceanBlue)
                Divider().padding(.leading, 62)
                infoRow(icon: "swift", label: "Version", value: "1.1.0", color: AppTheme.oceanBlue)
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
                    color: AppTheme.oceanBlue
                ) {
                    activeLegalSheet = .imprint
                }
            }
            .appCard(padding: 0)
            .padding(.horizontal, 16)
        }
    }

    private var europeSignatureSection: some View {
        Text("Made in Austria, by Antonio Baltic")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
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
        Haptics.medium()
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
        Haptics.medium()
        isClearingCache = true

        dataService.clearCache()
        weatherService.clearCache()
        isClearingCache = false
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.oceanBlue)
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
        .environment(TipJarService.previewInstance())
}

// MARK: - Settings Bubbles

private struct SettingsBubbleData: Identifiable {
    let id: Int
    let xRatio: CGFloat
    let size: CGFloat
    let speed: Double
    let startDelay: Double
    let opacity: Double
}

struct SettingsBubblesView: View {
    var color: Color = AppTheme.oceanBlue
    @State private var bubbles: [SettingsBubbleData] = []

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(bubbles) { b in
                        let elapsed = now - b.startDelay
                        let cycle = b.speed > 0 ? elapsed / b.speed : 0
                        let progress = cycle.truncatingRemainder(dividingBy: 1.0)
                        let y = h + 20 - progress * (h + 60)
                        let wobble = sin(elapsed * 1.8 + Double(b.id)) * 12

                        Circle()
                            .fill(color.opacity(b.opacity))
                            .frame(width: b.size, height: b.size)
                            .position(x: b.xRatio * w + wobble, y: y)
                    }
                }
            }
        }
        .onAppear { generateBubbles() }
        .allowsHitTesting(false)
    }

    private func generateBubbles() {
        let now = Date.now.timeIntervalSinceReferenceDate
        bubbles = (0..<10).map { i in
            SettingsBubbleData(
                id: i,
                xRatio: .random(in: 0.05...0.95),
                size: .random(in: 8...28),
                speed: .random(in: 14...24),
                startDelay: now - .random(in: 0...20),
                opacity: .random(in: 0.06...0.15)
            )
        }
    }
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
        static let appName = "Ducky"
        static let version = "1.1.0"
        static let postalAddress = "Schörgelgasse 55\n8010 Graz\nÖsterreich"
        static let contactEmail = "antoniobaltic@icloud.com"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.settingsGradient.ignoresSafeArea()

                SettingsBubblesView()
                    .ignoresSafeArea()

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
                    "\(LegalMeta.postalAddress)",
                    "E-Mail: \(LegalMeta.contactEmail)"
                ]
            )

            legalCard(
                heading: "2. Welche Daten verarbeitet die App?",
                lines: [
                    "Standort (nur mit deiner Freigabe): Wird verwendet, um Gewässer in deiner Nähe zu sortieren und Entfernungen anzuzeigen. Der Standort wird nicht gespeichert oder übertragen.",
                    "Netzwerk-Anfragen: Beim Abruf von Wetter-, Badegewässer-, Karten- und Wikipedia-Daten werden technische Anfragen an externe Dienste gestellt. Dabei wird deine IP-Adresse übermittelt.",
                    "Lokaler Cache: Gewässer- und Wetterdaten werden auf deinem Gerät zwischengespeichert (Caches-Verzeichnis), damit die App schneller startet.",
                    "Lokale Nutzerdaten: Favoriten, besuchte Seen und persönliche Notizen werden ausschließlich auf deinem Gerät gespeichert (SwiftData). Es erfolgt keine Übertragung an Server.",
                    "In-App-Käufe: Trinkgeld-Käufe werden über Apple StoreKit und RevenueCat abgewickelt. RevenueCat verarbeitet anonyme Kaufdaten zur Umsatzanalyse. Der Entwickler erhält keine persönlichen Zahlungsdaten.",
                    "Kein Tracking, keine Werbung, keine Benutzerkonten, kein Profiling."
                ]
            )

            legalCard(
                heading: "3. Rechtsgrundlagen (DSGVO)",
                lines: [
                    "Einwilligung (Art. 6 Abs. 1 lit. a): Standortzugriff — nur nach ausdrücklicher Freigabe in iOS.",
                    "Vertragserfüllung (Art. 6 Abs. 1 lit. b): Abruf von Gewässer- und Wetterdaten zur Bereitstellung der Kernfunktionen.",
                    "Berechtigtes Interesse (Art. 6 Abs. 1 lit. f): Lokale Zwischenspeicherung zur Verbesserung der Ladezeiten."
                ]
            )

            legalCard(
                heading: "4. Empfänger und externe Dienste",
                lines: [
                    "AGES — Österreichische Agentur für Gesundheit und Ernährungssicherheit (Badegewässerqualität)",
                    "Open-Meteo — Wetterdaten (Open-Source-API, Server in der EU)",
                    "Wikipedia / Wikimedia — Beschreibungen zu Gewässern (deutschsprachige API)",
                    "Apple Maps / MapKit — Kartenanzeige, Routen und Ortssuche",
                    "Apple StoreKit — Abwicklung von In-App-Käufen",
                    "RevenueCat — Verwaltung und Analyse von In-App-Käufen (Server in den USA, DSGVO-konform)",
                    "Hinweis: Bei diesen Anfragen kann deine IP-Adresse technisch bedingt vom jeweiligen Dienst verarbeitet werden. Es werden keine personenbezogenen Daten aktiv übermittelt."
                ]
            )

            legalCard(
                heading: "5. Speicherdauer und Löschung",
                lines: [
                    "Gewässer-Cache: 24 Stunden, danach automatische Aktualisierung.",
                    "Wetter-Cache: 30 Minuten, danach automatische Aktualisierung.",
                    "Wikipedia-Cache: 30 Tage.",
                    "Favoriten, Besuche und Notizen: Solange die App installiert ist.",
                    "Du kannst den Cache jederzeit in den Einstellungen löschen. Favoriten, Besuche und Notizen werden beim Deinstallieren der App gelöscht."
                ]
            )

            legalCard(
                heading: "6. Deine Rechte",
                lines: [
                    "Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung und Datenübertragbarkeit (Art. 15–20 DSGVO).",
                    "Du kannst den Standortzugriff jederzeit in den iOS-Einstellungen widerrufen.",
                    "Alle lokalen Daten kannst du durch Deinstallation der App vollständig löschen.",
                    "Anfragen richtest du an: \(LegalMeta.contactEmail)",
                    "Beschwerderecht: Österreichische Datenschutzbehörde (dsb.gv.at)"
                ]
            )

            legalCard(
                heading: "7. Sonstiges",
                lines: [
                    "Die App richtet sich nicht an Kinder unter 16 Jahren.",
                    "Es findet keine automatisierte Entscheidungsfindung oder Profiling statt.",
                    "Stand: April 2026"
                ]
            )
        }
    }

    private var imprintContent: some View {
        Group {
            legalCard(
                heading: "Angaben gemäß §5 ECG / §25 MedienG",
                lines: [
                    "\(LegalMeta.ownerName)",
                    "\(LegalMeta.postalAddress)",
                    "E-Mail: \(LegalMeta.contactEmail)"
                ]
            )

            legalCard(
                heading: "App",
                lines: [
                    "\(LegalMeta.appName) — Version \(LegalMeta.version)",
                    "Plattform: iOS",
                    "Einzelunternehmer (nicht im Firmenbuch eingetragen, keine UID-Nummer)"
                ]
            )

            legalCard(
                heading: "Unternehmensgegenstand",
                lines: [
                    "Entwicklung und Betrieb von Software-Produkten (Mobile Apps).",
                    "Ort der Tätigkeit: Graz, Österreich"
                ]
            )

            legalCard(
                heading: "Inhaltliche Verantwortung",
                lines: [
                    "Für sämtliche Inhalte der App verantwortlich: \(LegalMeta.ownerName)",
                    "Die in der App angezeigten Daten (Badegewässerqualität, Wetter, Karten, Wikipedia-Texte) stammen von externen Quellen und werden unverändert dargestellt."
                ]
            )

            legalCard(
                heading: "Haftungsausschluss",
                lines: [
                    "Trotz sorgfältiger Prüfung wird keine Gewähr für Vollständigkeit, Aktualität und Richtigkeit externer Daten übernommen.",
                    "Die App ersetzt keine offizielle Badegewässer-Beurteilung. Badeentscheidungen erfolgen auf eigene Verantwortung.",
                    "Maßgeblich sind die Bedingungen und Verfügbarkeit der jeweiligen Drittanbieter (AGES, Open-Meteo, Apple Maps, Wikipedia, RevenueCat)."
                ]
            )

            legalCard(
                heading: "Streitbeilegung",
                lines: [
                    "Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung bereit: ec.europa.eu/consumers/odr",
                    "Wir sind weder verpflichtet noch bereit, an einem Streitbeilegungsverfahren vor einer Verbraucherschlichtungsstelle teilzunehmen."
                ]
            )

            legalCard(
                heading: "Urheberrecht",
                lines: [
                    "App-Design, Code und Texte: © 2026 \(LegalMeta.ownerName)",
                    "Badegewässerdaten: AGES (ages.at), öffentlich zugänglich",
                    "Wetterdaten: Open-Meteo (open-meteo.com), Open-Source",
                    "Kartendaten: Apple Maps / MapKit",
                    "Gewässerbeschreibungen: Wikipedia (CC BY-SA 3.0)"
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
