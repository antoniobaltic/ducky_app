import SwiftUI

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        appearanceSection
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
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.lavender)
                Text("Erscheinungsbild")
                    .font(AppTheme.sectionTitle)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(AppearanceMode.allCases.enumerated()), id: \.element.id) { index, mode in
                    Button {
                        withAnimation(AppTheme.quickSpring) {
                            appearanceMode = mode
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(mode == appearanceMode ? AppTheme.oceanBlue : AppTheme.textSecondary)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.label)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text(mode.subtitle)
                                    .font(.system(size: 12, weight: .regular, design: .rounded))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            if mode == appearanceMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(AppTheme.oceanBlue)
                            }
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)

                    if index < AppearanceMode.allCases.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.teal)
                Text("Info")
                    .font(AppTheme.sectionTitle)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                infoRow(icon: "drop.fill", label: "Daten", value: "AGES Badegewässer", color: AppTheme.oceanBlue)
                Divider().padding(.leading, 62)
                infoRow(icon: "cloud.sun.fill", label: "Wetter", value: "Open-Meteo", color: AppTheme.skyBlue)
                Divider().padding(.leading, 62)
                infoRow(icon: "swift", label: "Version", value: "1.0.0", color: AppTheme.coral)
            }
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
            .padding(.horizontal, 16)
        }
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

// MARK: - AppearanceMode Subtitle

extension AppearanceMode {
    var subtitle: String {
        switch self {
        case .system: return "Folgt den Geräteeinstellungen"
        case .light: return "Immer heller Hintergrund"
        case .dark: return "Immer dunkler Hintergrund"
        }
    }
}

#Preview {
    SettingsView()
}
