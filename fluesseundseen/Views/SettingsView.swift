import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService
    @Environment(WeatherService.self) private var weatherService

    @AppStorage("preferredStartTab") private var preferredStartTab = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var isRefreshingData = false
    @State private var isClearingCache = false
    @State private var showClearCacheAlert = false
    @State private var showResetOnboardingAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        startupSection
                        dataAndCacheSection
                        onboardingSection
                        infoSection
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

    private var lastUpdateText: String {
        guard let lastUpdateDate else { return "Noch nicht verfügbar" }
        return Self.lastUpdateFormatter.string(from: lastUpdateDate)
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
}

#Preview {
    SettingsView()
        .environment(DataService.shared)
        .environment(WeatherService.shared)
}
