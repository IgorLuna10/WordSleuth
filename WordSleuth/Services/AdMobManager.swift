import SwiftUI
import UIKit
import Combine
import GoogleMobileAds

// MARK: - AdMob Manager Singleton & Rewarded Video Delegate
@MainActor
public final class AdMobManager: NSObject, ObservableObject, FullScreenContentDelegate {
    public static let shared = AdMobManager()
    
    // User's Real AdMob Ad Unit IDs from AdMob Console
    public static let bannerAdUnitID = "ca-app-pub-4999843502884263/2761351089"
    public static let rewardedAdUnitID = "ca-app-pub-4999843502884263/807365440"
    
    // Google Test Ad Unit IDs (used for safe simulator/dev builds)
    public static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    public static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/5224354917"
    
    @Published public private(set) var isRewardedAdLoaded = false
    @Published public private(set) var isLoadingAd = false
    
    private var rewardedAd: RewardedAd?
    private var rewardCompletion: (() -> Void)?
    
    override private init() {
        super.init()
    }
    
    public func startSDK() {
        MobileAds.shared.start(completionHandler: nil)
        loadRewardedAd()
    }
    
    public func loadRewardedAd() {
        guard !isLoadingAd && !isRewardedAdLoaded else { return }
        isLoadingAd = true
        
        #if DEBUG
        let adUnitID = Self.testRewardedAdUnitID
        #else
        let adUnitID = Self.rewardedAdUnitID
        #endif
        
        let request = Request()
        RewardedAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingAd = false
                if let error = error {
                    print("AdMob Rewarded Ad failed to load: \(error.localizedDescription)")
                    self.isRewardedAdLoaded = false
                    self.rewardedAd = nil
                } else {
                    print("AdMob Rewarded Ad loaded successfully!")
                    self.rewardedAd = ad
                    self.rewardedAd?.fullScreenContentDelegate = self
                    self.isRewardedAdLoaded = true
                }
            }
        }
    }
    
    public func showRewardedAd(from rootViewController: UIViewController? = nil, completion: @escaping () -> Void) {
        self.rewardCompletion = completion
        
        guard let rewardedAd = rewardedAd else {
            print("Rewarded Ad not ready yet, invoking reward completion directly.")
            completion()
            loadRewardedAd()
            return
        }
        
        let controller = rootViewController ?? getRootViewController()
        guard let presenter = controller else {
            completion()
            return
        }
        
        rewardedAd.present(from: presenter) { [weak self] in
            Task { @MainActor in
                print("User completed watching Rewarded Ad! Granting reward...")
                AdPolicyManager.shared.recordRewardedAdCompleted()
                self?.rewardCompletion?()
                self?.rewardCompletion = nil
            }
        }
    }
    
    // MARK: - FullScreenContentDelegate
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Rewarded Ad dismissed.")
        self.rewardedAd = nil
        self.isRewardedAdLoaded = false
        loadRewardedAd() // Preload the next ad
    }
    
    public func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Rewarded Ad failed to present: \(error.localizedDescription)")
        self.rewardedAd = nil
        self.isRewardedAdLoaded = false
        self.rewardCompletion?()
        self.rewardCompletion = nil
        loadRewardedAd()
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return root
    }
}

// MARK: - SwiftUI Banner Ad View
public struct BannerAdView: UIViewRepresentable {
    public init() {}
    
    public func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        
        #if DEBUG
        banner.adUnitID = AdMobManager.testBannerAdUnitID
        #else
        banner.adUnitID = AdMobManager.bannerAdUnitID
        #endif
        
        banner.rootViewController = getRootViewController()
        banner.load(Request())
        return banner
    }
    
    public func updateUIView(_ uiView: BannerView, context: Context) {
        // Banner updates automatically
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        return root
    }
}
