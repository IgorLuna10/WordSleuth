import Foundation
import SwiftUI
import Combine

/// Manages behavioral monetization policies, dynamic trait rules, and user journey shields
/// inspired by high-yield behavioral game and utility architectures.
@MainActor
public final class AdPolicyManager: ObservableObject {
    public static let shared = AdPolicyManager()
    
    // MARK: - Trait Configuration Constants
    
    /// Welcome allowance given on first app install (builds initial habit and delight before gating).
    public static let newPlayerWelcomeAllowance: Int = 5
    
    /// Standard daily allowance restored after the 24-hour reset interval.
    public static let standardDailyAllowance: Int = 3
    
    /// Grace period (in hours) during which banner ads are suppressed for new installs to protect D1 retention.
    public static let newPlayerBannerGraceHours: Double = 24.0
    
    /// Minimum successful scans required before banner ads are enabled (ensures value was delivered first).
    public static let newPlayerBannerGraceScans: Int = 3
    
    // MARK: - Published State
    
    @Published public private(set) var totalScansCompleted: Int = 0
    @Published public private(set) var totalRewardedAdsWatched: Int = 0
    @Published public private(set) var totalHintsUnlocked: Int = 0
    @Published public private(set) var isNewUserGraceActive: Bool = false
    
    // MARK: - Storage Keys
    
    private let defaults = UserDefaults.standard
    private let installDateKey = "wordsnap.policy.installDate"
    private let totalScansKey = "wordsnap.policy.totalScans"
    private let totalAdsKey = "wordsnap.policy.totalRewardedAds"
    private let totalHintsKey = "wordsnap.policy.totalHints"
    
    private init() {
        if defaults.object(forKey: installDateKey) == nil {
            defaults.set(Date(), forKey: installDateKey)
        }
        self.totalScansCompleted = defaults.integer(forKey: totalScansKey)
        self.totalRewardedAdsWatched = defaults.integer(forKey: totalAdsKey)
        self.totalHintsUnlocked = defaults.integer(forKey: totalHintsKey)
        
        updateGraceStatus()
    }
    
    // MARK: - Trait 1: NoBannerAdNewUserTrait (D1 Retention Shield)
    
    /// Returns true if banner ads should be rendered. Suppresses banners for the first 24h
    /// or until the user has successfully solved at least 3 puzzles.
    public func shouldShowBanner(isPremium: Bool) -> Bool {
        guard !isPremium else { return false }
        
        // Check install timestamp
        let installDate = (defaults.object(forKey: installDateKey) as? Date) ?? Date()
        let hoursSinceInstall = Date().timeIntervalSince(installDate) / 3600.0
        
        let inTimeGrace = hoursSinceInstall < Self.newPlayerBannerGraceHours
        let inScanGrace = totalScansCompleted < Self.newPlayerBannerGraceScans
        
        // Shield is active if both or either grace conditions apply
        let isShielded = inTimeGrace && inScanGrace
        return !isShielded
    }
    
    public var shouldShowBannerAd: Bool {
        // Fallback helper for default non-premium state checks
        shouldShowBanner(isPremium: false)
    }
    
    // MARK: - Telemetry & Trait Feedback
    
    public func recordScanCompleted() {
        totalScansCompleted += 1
        defaults.set(totalScansCompleted, forKey: totalScansKey)
        updateGraceStatus()
    }
    
    public func recordRewardedAdCompleted() {
        totalRewardedAdsWatched += 1
        defaults.set(totalRewardedAdsWatched, forKey: totalAdsKey)
    }
    
    public func recordHintUnlocked() {
        totalHintsUnlocked += 1
        defaults.set(totalHintsUnlocked, forKey: totalHintsKey)
    }
    
    private func updateGraceStatus() {
        let installDate = (defaults.object(forKey: installDateKey) as? Date) ?? Date()
        let hoursSinceInstall = Date().timeIntervalSince(installDate) / 3600.0
        let inGrace = (hoursSinceInstall < Self.newPlayerBannerGraceHours) && (totalScansCompleted < Self.newPlayerBannerGraceScans)
        self.isNewUserGraceActive = inGrace
    }
}
