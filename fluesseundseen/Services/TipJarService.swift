import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class TipJarService {
    static let shared = TipJarService()

    enum PurchaseOutcome {
        case success
        case cancelled
        case pending
        case failed
    }

    // Replace these product identifiers with the exact IDs from App Store Connect.
    nonisolated static let tipProductIDs: [String] = [
        "balticstudios.ducky.tip.small",
        "balticstudios.ducky.tip.medium",
        "balticstudios.ducky.tip.large"
    ]

    nonisolated private static let tipProductIDSet = Set(tipProductIDs)

    private enum Keys {
        static let launchCount = "tipJar.launchCount"
        static let lastPromptDate = "tipJar.lastPromptDate"
        static let promptsEnabled = "tipJar.promptsEnabled"
        static let lastTipDate = "tipJar.lastTipDate"
        static let totalTipCount = "tipJar.totalTipCount"
        static let lastRecordedTransactionID = "tipJar.lastRecordedTransactionID"
    }

    var products: [Product] = []
    var isLoadingProducts = false
    var purchaseInFlightProductID: String?
    var purchaseNotice: String?
    var purchaseError: String?
    var launchCount: Int
    var promptsEnabled: Bool
    var lastTipDate: Date?
    var totalTipCount: Int

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?
    private var hasConfigured = false
    private var lastRecordedTransactionID: UInt64

    private let minLaunchesBeforePrompt = 6
    private let promptCooldown: TimeInterval = 14 * 24 * 60 * 60
    private let postTipPromptCooldown: TimeInterval = 45 * 24 * 60 * 60

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        launchCount = defaults.integer(forKey: Keys.launchCount)
        promptsEnabled = defaults.object(forKey: Keys.promptsEnabled) as? Bool ?? true
        lastTipDate = defaults.object(forKey: Keys.lastTipDate) as? Date
        totalTipCount = defaults.integer(forKey: Keys.totalTipCount)
        let storedID = defaults.string(forKey: Keys.lastRecordedTransactionID)
        lastRecordedTransactionID = storedID.flatMap(UInt64.init) ?? 0
    }

    func configureIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true
        startTransactionListener()
    }

    func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }

        isLoadingProducts = true
        purchaseError = nil
        defer { isLoadingProducts = false }

        do {
            let fetched = try await Product.products(for: Self.tipProductIDs)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Trinkgeld-Optionen konnten gerade nicht geladen werden."
        }
    }

    func purchase(_ product: Product) async -> PurchaseOutcome {
        guard purchaseInFlightProductID == nil else { return .failed }

        purchaseInFlightProductID = product.id
        purchaseNotice = nil
        purchaseError = nil
        defer { purchaseInFlightProductID = nil }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                do {
                    let transaction = try Self.checkVerified(verification)
                    await transaction.finish()
                    recordSuccessfulTip(transactionID: transaction.id)
                    purchaseNotice = "Danke dir! Ducky hat jetzt Brot im Schnabel."
                    return .success
                } catch {
                    purchaseError = "Kauf konnte nicht verifiziert werden."
                    return .failed
                }
            case .pending:
                purchaseNotice = "Zahlung ist ausstehend."
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                purchaseError = "Unbekanntes Kauf-Ergebnis."
                return .failed
            }
        } catch {
            purchaseError = "Kauf fehlgeschlagen. Versuch es später erneut."
            return .failed
        }
    }

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

    private func startTransactionListener() {
        guard updatesTask == nil else { return }

        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                guard Self.tipProductIDSet.contains(transaction.productID) else { continue }
                await transaction.finish()
                await self?.recordSuccessfulTipFromListener(transactionID: transaction.id)
            }
        }
    }

    private func recordSuccessfulTipFromListener(transactionID: UInt64) {
        recordSuccessfulTip(transactionID: transactionID)
    }

    private func recordSuccessfulTip(transactionID: UInt64, now: Date = Date()) {
        guard transactionID != lastRecordedTransactionID else { return }
        lastRecordedTransactionID = transactionID

        lastTipDate = now
        totalTipCount += 1

        defaults.set(now, forKey: Keys.lastTipDate)
        defaults.set(totalTipCount, forKey: Keys.totalTipCount)
        defaults.set(now, forKey: Keys.lastPromptDate)
        defaults.set(String(transactionID), forKey: Keys.lastRecordedTransactionID)
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
