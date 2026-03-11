import SwiftUI
import StoreKit

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
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerCard
                        productListCard
                        supportStatusCard

                        if isPrompt {
                            promptControlsCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Ducky unterstützen")
            .iOSNavigationBarStyle()
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
                Text(isPrompt ? "Ducky hat Brothunger!" : "Ducky-Brotkasse")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Wenn dir Ducky taugt, kannst ihm freiwillig a bissl Brot spendieren. Jede Semmel freut den Schnabel.")
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

            if let notice = tipJarService.purchaseNotice {
                Divider()
                Text(notice)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.freshGreen)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = tipJarService.purchaseError {
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

    private var promptControlsCard: some View {
        VStack(spacing: 10) {
            Button {
                tipJarService.snoozePrompt()
                dismiss()
            } label: {
                Text("Später erinnern")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.oceanBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppTheme.oceanBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                tipJarService.setPromptsEnabled(false)
                dismiss()
            } label: {
                Text("Nicht mehr erinnern")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(AppTheme.cardStroke.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func tipProductButton(_ product: Product) -> some View {
        let isActivePurchase = tipJarService.purchaseInFlightProductID == product.id
        return Button {
            guard !isActivePurchase else { return }
            Task {
                let outcome = await tipJarService.purchase(product)
                if outcome == .success {
                    Haptics.success()
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

#Preview {
    TipJarSheet(entryPoint: .settings)
        .environment(TipJarService.shared)
}
