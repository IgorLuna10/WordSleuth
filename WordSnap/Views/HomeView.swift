import SwiftUI
import PhotosUI
import AppTrackingTransparency

public struct HomeView: View {
    @EnvironmentObject private var stateManager: AppStateManager
    
    @State private var showingCamera = false
    @State private var showingPaywall = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var scannedImage: UIImage? = nil
    @State private var isProcessingImage = false
    @ObservedObject private var adPolicy = AdPolicyManager.shared
    
    // Grid confirm navigation
    @State private var detectedGrid: [[Character]]? = nil
    @State private var detectedWords: [String]? = nil
    @State private var navigateToConfirm = false
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                // Background decorative glow gradients
                VStack {
                    HStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.15))
                            .frame(width: 250, height: 250)
                            .blur(radius: 80)
                            .offset(x: -50, y: -50)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Theme.secondary.opacity(0.15))
                            .frame(width: 300, height: 300)
                            .blur(radius: 90)
                            .offset(x: 80, y: 80)
                    }
                }
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                        // Header
                        HStack(spacing: 12) {
                            Image("AppLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 44, height: 44)
                                .cornerRadius(10)
                                .shadow(color: Theme.primary.opacity(0.3), radius: 6, x: 0, y: 2)
                                
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WORD")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.primary)
                                    .tracking(4)
                                Text("Sleuth")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                            }
                            Spacer()
                            
                            // Premium Badge
                            Button(action: {
                                HapticManager.shared.impact(.light)
                                showingPaywall = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: stateManager.isPremium ? "crown.fill" : "bolt.fill")
                                        .foregroundColor(stateManager.isPremium ? .yellow : .purple)
                                    Text(stateManager.isPremium ? "PRO" : "GO PRO")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.surfaceSecondary)
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(LinearGradient(colors: [Theme.primary, Theme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // Status Card (Glassmorphic)
                        VStack(spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Status Dashboard")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .textCase(.uppercase)
                                        .tracking(1)
                                    
                                    if stateManager.isPremium {
                                        Text("Unlimited Solves Active ⚡")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.success)
                                    } else {
                                        Text("\(stateManager.freeScansRemaining) Free Solves Left")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundColor(Theme.secondary)
                            }
                            
                            if !stateManager.isPremium {
                                Divider()
                                    .background(Theme.surfaceSecondary)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Daily Reset In")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textMuted)
                                        Text(stateManager.timeUntilResetFormatted)
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(Theme.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        HapticManager.shared.impact(.medium)
                                        AdMobManager.shared.showRewardedAd {
                                            stateManager.grantAdRewardSolve()
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "play.tv.fill")
                                                .font(.caption)
                                            Text("Watch Ad (+1 Solve)")
                                                .font(.system(size: 12, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            LinearGradient(colors: [Theme.primary, Theme.secondary], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(16)
                                        .shadow(color: Theme.primary.opacity(0.3), radius: 4, y: 2)
                                    }
                                }
                            }
                        }
                        .padding()
                        .glassmorphic()
                        .padding(.horizontal)
                        
                        // Main Action buttons
                        VStack(spacing: 14) {
                            PremiumButton(title: "Scan Puzzle with Camera", icon: "camera.fill") {
                                showingCamera = true
                            }
                            
                            HStack(spacing: 12) {
                                // Photo picker wrapper
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle.angled")
                                        Text("Import Photo")
                                    }
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.surfaceSecondary)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.surfaceSecondary, lineWidth: 1)
                                    )
                                }
                                .onChange(of: selectedPhotoItem) { _, newItem in
                                    guard let newItem = newItem else { return }
                                    Task {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = UIImage(data: data) {
                                            self.scannedImage = image
                                            processImportedImage(image)
                                        }
                                        selectedPhotoItem = nil
                                    }
                                }
                                
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    setupDemoGrid()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.square")
                                        Text("Demo Grid")
                                    }
                                    .font(.headline)
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Theme.surfaceSecondary)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // History Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Puzzles")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                                .padding(.horizontal)
                            
                            if stateManager.savedPuzzles.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 40))
                                        .foregroundColor(Theme.textMuted)
                                    Text("No scanned puzzles yet")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                                .glassmorphic()
                                .padding(.horizontal)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(stateManager.savedPuzzles) { item in
                                         NavigationLink(destination: GridConfirmView(initialGrid: item.grid.map { $0.map { $0.first ?? "?" } }, initialWords: item.words)) {
                                            HStack(spacing: 16) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Wordsearch Puzzle")
                                                        .font(.body)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(Theme.textPrimary)
                                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                                        .font(.caption2)
                                                        .foregroundColor(Theme.textSecondary)
                                                }
                                                Spacer()
                                                
                                                // Grid size badge
                                                Text("\(item.grid.count)x\(item.grid.first?.count ?? 0)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(Theme.primary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Theme.primary.opacity(0.15))
                                                    .cornerRadius(6)
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.footnote)
                                                    .foregroundColor(Theme.textMuted)
                                            }
                                            .padding()
                                            .background(Theme.surfaceSecondary)
                                            .cornerRadius(12)
                                        }
                                    }
                                    .onDelete(perform: stateManager.deletePuzzle)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                
                // Bottom Banner Ad (Protected by Trait: NoBannerAdNewUserTrait)
                if !stateManager.isPremium && adPolicy.shouldShowBanner(isPremium: stateManager.isPremium) {
                    BannerAdView()
                        .frame(height: 50)
                        .background(Theme.surface)
                }
            }
                
                // Loading Overlay
                if isProcessingImage {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(Theme.primary)
                                .scaleEffect(1.5)
                            Text("Analyzing Grid & Words...")
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Text("Apple Vision OCR is doing its magic")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(24)
                        .glassmorphic()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToConfirm) {
                if let grid = detectedGrid, let words = detectedWords {
                    GridConfirmView(initialGrid: grid, initialWords: words)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraScanView { image in
                    showingCamera = false
                    processImportedImage(image)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .onAppear {
                requestTrackingAuthorizationIfNeeded()
            }
        }
    }
    
    private func processImportedImage(_ image: UIImage) {
        isProcessingImage = true
        OCRProcessor.processImage(image) { result in
            isProcessingImage = false
            switch result {
            case .success(let scan):
                HapticManager.shared.notification(.success)
                self.detectedGrid = scan.grid
                self.detectedWords = scan.words
                self.navigateToConfirm = true
            case .failure(let error):
                HapticManager.shared.notification(.error)
                print("OCR Error: \(error.localizedDescription)")
                // Fallback to empty grid if OCR fails completely
                self.detectedGrid = [
                    ["A", "B", "C"],
                    ["D", "E", "F"],
                    ["G", "H", "I"]
                ]
                self.detectedWords = []
                self.navigateToConfirm = true
            }
        }
    }
    
    private func setupDemoGrid() {
        // High quality mock wordsearch puzzle
        self.detectedGrid = [
            ["S", "W", "I", "F", "T", "U", "I", "R"],
            ["X", "A", "C", "D", "K", "O", "T", "L"],
            ["V", "I", "S", "I", "O", "N", "H", "K"],
            ["Q", "P", "E", "D", "S", "O", "I", "J"],
            ["W", "A", "C", "A", "M", "E", "R", "A"],
            ["C", "O", "R", "E", "M", "L", "D", "M"],
            ["P", "U", "Z", "Z", "L", "E", "U", "V"],
            ["S", "O", "L", "V", "E", "R", "Q", "B"]
        ]
        self.detectedWords = ["SWIFTUI", "VISION", "CAMERA", "COREML", "PUZZLE", "SOLVER"]
        self.navigateToConfirm = true
    }
    
    private func requestTrackingAuthorizationIfNeeded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("ATT Authorization status: \(status.rawValue)")
                }
            }
        }
    }
}


