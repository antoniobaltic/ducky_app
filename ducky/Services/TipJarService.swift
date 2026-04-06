import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class TipJarService {
    static let shared = TipJarService()

    static func previewInstance() -> TipJarService {
        let suiteName = "TipJarServicePreview"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let instance = TipJarService(defaults: defaults, isPreview: true)
        instance.products = Self.tipCatalog.map {
            TipProduct(
                id: $0.id,
                displayName: $0.suggestedDisplayName,
                displayPrice: "—",
                description: $0.suggestedDescription,
                package: nil
            )
        }
        return instance
    }

    // MARK: - Types

    struct TipProduct: Identifiable {
        let id: String
        let displayName: String
        let displayPrice: String
        let description: String
        let package: Package?
    }

    struct TipProductDefinition: Identifiable {
        let id: String
        let referenceName: String
        let suggestedDisplayName: String
        let suggestedDescription: String
    }

    enum PurchaseOutcome {
        case success
        case cancelled
        case pending
        case failed
    }

    // MARK: - Product Catalog

    nonisolated static let tipCatalog: [TipProductDefinition] = [
        .init(
            id: "antoniobaltic.ducky.tip.toast",
            referenceName: "Ducky Tip Small",
            suggestedDisplayName: "Toast",
            suggestedDescription: "Eine Scheibe Toast fuer Ducky."
        ),
        .init(
            id: "antoniobaltic.ducky.tip.medium",
            referenceName: "Ducky Tip Medium",
            suggestedDisplayName: "Semmel",
            suggestedDescription: "Eine frische Semmel fuer Ducky."
        ),
        .init(
            id: "antoniobaltic.ducky.tip.large",
            referenceName: "Ducky Tip Large",
            suggestedDisplayName: "Sandwich",
            suggestedDescription: "Ein ordentliches Sandwich fuer Ducky."
        )
    ]

    nonisolated static let tipProductIDs = tipCatalog.map(\.id)
    nonisolated private static let tipProductIDSet = Set(tipProductIDs)

    // MARK: - State

    private enum Keys {
        static let launchCount = "tipJar.launchCount"
        static let lastPromptDate = "tipJar.lastPromptDate"
        static let promptsEnabled = "tipJar.promptsEnabled"
        static let lastTipDate = "tipJar.lastTipDate"
        static let totalTipCount = "tipJar.totalTipCount"
        static let lastRecordedTransactionID = "tipJar.lastRecordedTransactionID"
    }

    var products: [TipProduct] = []
    var isLoadingProducts = false
    var purchaseInFlightProductID: String?
    var purchaseNotice: String?
    var purchaseError: String?
    var launchCount: Int
    var promptsEnabled: Bool
    var lastTipDate: Date?
    var totalTipCount: Int

    private let defaults: UserDefaults
    private let isPreview: Bool
    private var hasConfigured = false
    private var lastRecordedTransactionID: String

    private let minLaunchesBeforePrompt = 6
    private let promptCooldown: TimeInterval = 14 * 24 * 60 * 60
    private let postTipPromptCooldown: TimeInterval = 45 * 24 * 60 * 60

    // MARK: - Init

    private init(defaults: UserDefaults = .standard, isPreview: Bool = false) {
        self.defaults = defaults
        self.isPreview = isPreview
        launchCount = defaults.integer(forKey: Keys.launchCount)
        promptsEnabled = defaults.object(forKey: Keys.promptsEnabled) as? Bool ?? true
        lastTipDate = defaults.object(forKey: Keys.lastTipDate) as? Date
        totalTipCount = defaults.integer(forKey: Keys.totalTipCount)
        lastRecordedTransactionID = defaults.string(forKey: Keys.lastRecordedTransactionID) ?? ""
    }

    // MARK: - Configuration

    func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true
    }

    // MARK: - Products

    func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard !isPreview, !isLoadingProducts else { return }

        isLoadingProducts = true
        purchaseError = nil
        defer { isLoadingProducts = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let offering = offerings.offering(identifier: "tip_jar") else {
                purchaseError = "Trinkgeld-Optionen sind gerade noch nicht verfuegbar."
                #if DEBUG
                print("RevenueCat: 'tip_jar' offering not found")
                #endif
                return
            }

            products = offering.availablePackages
                .map { pkg in
                    TipProduct(
                        id: pkg.storeProduct.productIdentifier,
                        displayName: pkg.storeProduct.localizedTitle,
                        displayPrice: pkg.storeProduct.localizedPriceString,
                        description: pkg.storeProduct.localizedDescription,
                        package: pkg
                    )
                }
                .sorted { ($0.package?.storeProduct.price ?? 0) < ($1.package?.storeProduct.price ?? 0) }

            let loadedIDs = Set(products.map(\.id))
            let missingIDs = Self.tipProductIDSet.subtracting(loadedIDs).sorted()
            if !missingIDs.isEmpty {
                purchaseError = "Trinkgeld-Optionen sind gerade noch nicht verfuegbar."
                #if DEBUG
                print("Missing tip jar product IDs: \(missingIDs.joined(separator: ", "))")
                #endif
            }
        } catch {
            purchaseError = "Trinkgeld-Optionen konnten gerade nicht geladen werden."
        }
    }

    // MARK: - Purchase

    func purchase(_ product: TipProduct) async -> PurchaseOutcome {
        guard purchaseInFlightProductID == nil, let package = product.package else { return .failed }

        purchaseInFlightProductID = product.id
        purchaseNotice = nil
        purchaseError = nil
        defer { purchaseInFlightProductID = nil }

        do {
            let (transaction, _, userCancelled) = try await Purchases.shared.purchase(package: package)
            if userCancelled { return .cancelled }
            if let transaction {
                recordSuccessfulTip(transactionID: transaction.transactionIdentifier)
                purchaseNotice = "Vielen Dank! Du hast einen wertvollen Beitrag zu Duckys Wohlbefinden geleistet."
                return .success
            }
            return .failed
        } catch {
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .paymentPendingError {
                purchaseNotice = "Zahlung ist ausstehend."
                return .pending
            }
            purchaseError = "Kauf fehlgeschlagen. Versuch es später erneut."
            return .failed
        }
    }

    // MARK: - Prompt Logic

    func registerAppLaunch() {
        launchCount += 1
        defaults.set(launchCount, forKey: Keys.launchCount)
    }

    func shouldPresentPrompt(now: Date = Date()) -> Bool {
        guard promptsEnabled else { return false }
        guard launchCount >= minLaunchesBeforePrompt else { return false }

        if let lastPromptDate = defaults.object(forKey: Keys.lastPromptDate) as? Date,
           now.timeIntervalSince(lastPromptDate) < promptCooldown {
            return false
        }

        if let lastTipDate, now.timeIntervalSince(lastTipDate) < postTipPromptCooldown {
            return false
        }

        return true
    }

    func markPromptShown(now: Date = Date()) {
        defaults.set(now, forKey: Keys.lastPromptDate)
    }

    func snoozePrompt() {
        markPromptShown()
    }

    func setPromptsEnabled(_ enabled: Bool) {
        promptsEnabled = enabled
        defaults.set(enabled, forKey: Keys.promptsEnabled)
    }

    // MARK: - Tip Recording

    private func recordSuccessfulTip(transactionID: String, now: Date = Date()) {
        guard transactionID != lastRecordedTransactionID else { return }
        lastRecordedTransactionID = transactionID

        lastTipDate = now
        totalTipCount += 1

        defaults.set(now, forKey: Keys.lastTipDate)
        defaults.set(totalTipCount, forKey: Keys.totalTipCount)
        defaults.set(now, forKey: Keys.lastPromptDate)
        defaults.set(transactionID, forKey: Keys.lastRecordedTransactionID)
    }
}
