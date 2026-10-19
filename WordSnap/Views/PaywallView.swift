import SwiftUI
import StoreKit

public struct PaywallView: View {
    @EnvironmentObject private var stateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProductID: String? = nil
    @State private var isPurchasing = false
    @State private var showingError = false
    
    // Apple gives us price/name/period from StoreKit; badge and savings copy
    // are merchandising choices we still own, keyed by product ID.
    private struct TierPresentation {
        let title: String
        let savings: String?
        let isPopular: Bool
    }
    
    private let presentation: [String: TierPresentation] = [
        AppStateManager.weeklyProductID: TierPresentation(title: "Weekly Access", savings: nil, isPopular: false),
        AppStateManager.monthlyProductID: TierPresentation(title: "Monthly Pass", savings: "Save 35%", isPopular: false),
        AppStateManager.yearlyProductID: TierPresentation(title: "Annual Premium", savings: "Save 80%", isPopular: true)
    ]
    
    private func presentation(for product: Product) -> TierPresentation {
        presentation[product.id] ?? TierPresentation(title: product.displayName, savings: nil, isPopular: false)
    }
    
    private func periodLabel(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return ""
        }
    }
    
    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            // Neon accent glow in background
            VStack {
                Circle()
                    .fill(Theme.secondary.opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(y: -100)
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Spacer()
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.body)
                            .foregroundColor(Theme.textSecondary)
                            .padding(8)
                            .background(Theme.surfaceSecondary)
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Title / Icon
                        VStack(spacing: 16) {
                            ZStack(alignment: .bottomTrailing) {
                                Image("AppLogo")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 88, height: 88)
                                    .cornerRadius(20)
                                    .shadow(color: Theme.primary.opacity(0.4), radius: 12, x: 0, y: 4)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.yellow)
                                    .padding(6)
                                    .background(Theme.surfaceSecondary)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                    .offset(x: 6, y: 6)
                            }
                            
                            Text("Unlock WordSnap Pro")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Gain unlimited solver capabilities and power up your scanning speed.")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // Feature bullets
                        VStack(alignment: .leading, spacing: 14) {
                            FeatureRow(icon: "camera.fill", title: "Instant Camera Solver", subtitle: "Point, scan, and see the answers dynamically.")
                            FeatureRow(icon: "bolt.fill", title: "Unlimited Daily Scans", subtitle: "No daily limit checks. Solve as many as you want.")
                            FeatureRow(icon: "icloud.slash.fill", title: "100% Offline Processing", subtitle: "All scanning and solving runs fully offline.")
                            FeatureRow(icon: "sparkles", title: "Ad-Free Premium Solver", subtitle: "Focus on your wordsearches without popups.")
                        }
                        .padding(.horizontal)
                        
                        // Subscription tiers — loaded live from StoreKit
                        if stateManager.products.isEmpty {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(Theme.primary)
                                Text("Loading plans…")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(stateManager.products) { product in
                                    let info = presentation(for: product)
                                    let isSelected = selectedProductID == product.id
                                    
                                    Button(action: {
                                        HapticManager.shared.impact(.light)
                                        selectedProductID = product.id
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 8) {
                                                    Text(info.title)
                                                        .font(.headline)
                                                        .foregroundColor(Theme.textPrimary)
                                                    
                                                    if info.isPopular {
                                                        Text("BEST VALUE")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Theme.secondary)
                                                            .cornerRadius(4)
                                                    }
                                                }
                                                
                                                if let savings = info.savings {
                                                    Text(savings)
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(Theme.success)
                                                }
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(product.displayPrice)
                                                    .font(.headline)
                                                    .foregroundColor(Theme.textPrimary)
                                                if let unit = product.subscription?.subscriptionPeriod.unit {
                                                    Text("/ \(periodLabel(unit))")
                                                        .font(.caption2)
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(isSelected ? Theme.surfaceSecondary : Theme.surface.opacity(0.4))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(isSelected ? Theme.primary : Theme.surfaceSecondary, lineWidth: 2)
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Action button
                        VStack(spacing: 12) {
                            Button(action: {
                                Task { await purchaseSelectedPlan() }
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                            .padding(.trailing, 8)
                                    }
                                    Text(isPurchasing ? "Connecting to App Store..." : "Subscribe Now")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Theme.primary, Theme.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(14)
                                .shadow(color: Theme.primary.opacity(0.4), radius: 10, y: 5)
                            }
                            .disabled(isPurchasing || selectedProductID == nil)
                            
                            Text("Cancel anytime. Subscription automatically renews.")
                                .font(.caption2)
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Terms of service links
                        HStack(spacing: 16) {
                            LinkButton(
                                title: "Terms of Service",
                                url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
                            )
                            Text("•")
                                .foregroundColor(Theme.textMuted)
                            LinkButton(
                                title: "Privacy Policy",
                                url: URL(string: "https://www.apple.com/legal/privacy/")!
                            )
                            Text("•")
                                .foregroundColor(Theme.textMuted)
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                Task {
                                    await stateManager.restorePurchases()
                                    if stateManager.isPremium {
                                        HapticManager.shared.notification(.success)
                                        dismiss()
                                    }
                                }
                            }) {
                                Text("Restore")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .underline()
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .onAppear {
            selectDefaultProductIfNeeded()
        }
        .onChange(of: stateManager.products) { _, _ in
            selectDefaultProductIfNeeded()
        }
        .onChange(of: stateManager.purchaseError) { _, newValue in
            showingError = newValue != nil
        }
        .alert("Something went wrong", isPresented: $showingError, presenting: stateManager.purchaseError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }
    
    private func selectDefaultProductIfNeeded() {
        guard selectedProductID == nil else { return }
        selectedProductID = stateManager.products.first(where: { presentation(for: $0).isPopular })?.id
            ?? stateManager.products.last?.id
    }
    
    private func purchaseSelectedPlan() async {
        guard let productID = selectedProductID,
              let product = stateManager.products.first(where: { $0.id == productID }) else { return }
        
        HapticManager.shared.impact(.medium)
        isPurchasing = true
        let success = await stateManager.purchase(product)
        isPurchasing = false
        
        if success {
            HapticManager.shared.notification(.success)
            dismiss()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Theme.primary)
                .frame(width: 44, height: 44)
                .background(Theme.surfaceSecondary)
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
    }
}

struct LinkButton: View {
    let title: String
    let url: URL
    
    var body: some View {
        Link(destination: url) {
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .underline()
        }
        .simultaneousGesture(TapGesture().onEnded {
            HapticManager.shared.impact(.light)
        })
    }
}
