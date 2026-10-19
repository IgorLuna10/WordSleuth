import Foundation
import StoreKit
import SwiftUI
import Combine

/// The app's single source of truth for premium status, free-scan allowance,
/// and puzzle history. Owns all StoreKit interaction — views never set
/// `isPremium` directly; it's always derived from StoreKit's own entitlement
/// records so it can't drift from what was actually purchased.
@MainActor
public final class AppStateManager: ObservableObject {

    // MARK: - Product IDs
    public static let weeklyProductID = "com.wordsnap.pro.weekly"
    public static let monthlyProductID = "com.wordsnap.pro.monthly"
    public static let yearlyProductID = "com.wordsnap.pro.yearly"
    public static let allProductIDs = [weeklyProductID, monthlyProductID, yearlyProductID]

    // MARK: - Published state

    @Published public private(set) var isPremium: Bool = false
    @Published public private(set) var products: [Product] = []
    @Published public var purchaseError: String? = nil

    @Published public private(set) var freeScansRemaining: Int
    @Published public private(set) var timeUntilResetFormatted: String = "24:00:00"
    @Published public private(set) var savedPuzzles: [SavedPuzzle] = []

    // MARK: - Private

    private let standardDailyAllowance = AdPolicyManager.standardDailyAllowance
    private let resetInterval: TimeInterval = 24 * 3600 // 24 Hours
    private let defaults = UserDefaults.standard
    private let freeScansKey = "wordsnap.freeScansRemaining"
    private let lastResetKey = "wordsnap.lastResetTimestamp"
    private let savedPuzzlesKey = "wordsnap.savedPuzzles"
    
    private var transactionListenerTask: Task<Void, Never>?
    private var timerCancellable: AnyCancellable?

    private enum StoreError: Error {
        case failedVerification
    }

    // MARK: - Init

    public init() {
        if defaults.object(forKey: freeScansKey) == nil {
            // New player welcome boost (Trait: NewPlayerWelcomeAllowanceTrait)
            self.freeScansRemaining = AdPolicyManager.newPlayerWelcomeAllowance
            defaults.set(self.freeScansRemaining, forKey: freeScansKey)
        } else {
            self.freeScansRemaining = defaults.integer(forKey: freeScansKey)
        }
        self.savedPuzzles = Self.loadSavedPuzzles(from: defaults, key: savedPuzzlesKey)

        setupResetTimer()

        // Watch for renewals, cancellations, refunds, and family-sharing
        // changes that happen while the app is running.
        transactionListenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? self.checkVerified(update) {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - StoreKit: loading products

    public func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            self.products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            self.purchaseError = "Couldn't load subscription plans. Check your connection and try again."
        }
    }

    // MARK: - StoreKit: purchasing

    /// Attempts to purchase the given product. Returns true only if the
    /// purchase completed successfully and premium is now active.
    public func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return isPremium
            case .userCancelled:
                return false
            case .pending:
                self.purchaseError = "Your purchase needs approval (e.g. Ask to Buy) before it completes."
                return false
            @unknown default:
                return false
            }
        } catch {
            self.purchaseError = error.localizedDescription
            return false
        }
    }

    public func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            self.purchaseError = "Restore failed: \(error.localizedDescription)"
        }
        await refreshEntitlements()
    }

    /// The only place `isPremium` is ever set. Walks StoreKit's own record of
    /// what this Apple ID currently owns — this is what makes the paywall
    /// tamper-proof instead of a client-side flag anyone could flip.
    public func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if Self.allProductIDs.contains(transaction.productID), transaction.revocationDate == nil {
                active = true
            }
        }
        self.isPremium = active
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Free scans

    /// Call once per scan *attempt* (camera or imported photo), not just on a
    /// successful read — the point is to gate access to the feature, not to
    /// reward only clean scans.
    public func consumeFreeScan() {
        guard !isPremium else { return }
        guard freeScansRemaining > 0 else { return }
        freeScansRemaining -= 1
        defaults.set(freeScansRemaining, forKey: freeScansKey)
    }

    public var canScan: Bool {
        isPremium || freeScansRemaining > 0
    }

    // MARK: - Timer & Reset Logic

    private func setupResetTimer() {
        checkAndResetFreeScansIfNeeded()
        updateFormattedResetTime()
        
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.checkAndResetFreeScansIfNeeded()
                self.updateFormattedResetTime()
            }
    }

    public func checkAndResetFreeScansIfNeeded() {
        let now = Date()
        let lastResetTime = defaults.object(forKey: lastResetKey) as? Date ?? now

        if defaults.object(forKey: lastResetKey) == nil {
            defaults.set(now, forKey: lastResetKey)
        } else if now.timeIntervalSince(lastResetTime) >= resetInterval {
            self.freeScansRemaining = standardDailyAllowance
            defaults.set(freeScansRemaining, forKey: freeScansKey)
            defaults.set(now, forKey: lastResetKey)
        }
    }

    private func updateFormattedResetTime() {
        let now = Date()
        let lastResetTime = defaults.object(forKey: lastResetKey) as? Date ?? now
        let nextResetTime = lastResetTime.addingTimeInterval(resetInterval)
        let remainingSeconds = max(0, Int(nextResetTime.timeIntervalSince(now)))

        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60

        self.timeUntilResetFormatted = String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
    }

    // MARK: - Ad Reward Integration

    public func grantAdRewardSolve() {
        freeScansRemaining += 1
        defaults.set(freeScansRemaining, forKey: freeScansKey)
    }

    public func resetSolvesToMax() {
        freeScansRemaining = standardDailyAllowance
        defaults.set(freeScansRemaining, forKey: freeScansKey)
        defaults.set(Date(), forKey: lastResetKey)
    }

    // MARK: - Puzzle history

    public func addPuzzleToHistory(grid: [[Character]], words: [String]) {
        let stringGrid = grid.map { row in row.map { String($0) } }
        let item = SavedPuzzle(id: UUID(), grid: stringGrid, words: words, date: Date())
        savedPuzzles.insert(item, at: 0)
        persistSavedPuzzles()
    }

    public func deletePuzzle(at offsets: IndexSet) {
        savedPuzzles.remove(atOffsets: offsets)
        persistSavedPuzzles()
    }

    private func persistSavedPuzzles() {
        if let data = try? JSONEncoder().encode(savedPuzzles) {
            defaults.set(data, forKey: savedPuzzlesKey)
        }
    }

    private static func loadSavedPuzzles(from defaults: UserDefaults, key: String) -> [SavedPuzzle] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedPuzzle].self, from: data) else {
            return []
        }
        return decoded
    }
}
