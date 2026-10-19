import SwiftUI

public struct SolverView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var stateManager: AppStateManager
    
    let grid: [[Character]]
    let words: [String]
    
    @State private var solutions = [String: WordPlacement]()
    @State private var selectedWord: String? = nil
    @State private var hintToastMessage: String? = nil
    
    public init(grid: [[Character]], words: [String]) {
        self.grid = grid
        self.words = words
    }
    
    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header navigation
                HStack {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Edit Grid")
                        }
                        .foregroundColor(Theme.primary)
                    }
                    Spacer()
                    Text("Solution")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    
                    // Share / Export button placeholder
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        shareSolution()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.primary)
                    }
                }
                .padding()
                
                // Animated Clue Toast Notification
                if let toast = hintToastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(colors: [Theme.primary, Theme.secondary], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: Theme.primary.opacity(0.4), radius: 8, y: 3)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.bottom, 8)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Header Stats Card
                        VStack(spacing: 12) {
                            let foundCount = solutions.count
                            let totalCount = words.count
                            let successRate = totalCount > 0 ? Double(foundCount) / Double(totalCount) : 0.0
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Progress")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                        .textCase(.uppercase)
                                        .tracking(1)
                                    Text("\(foundCount) of \(totalCount) Words Found")
                                        .font(.title2)
                                        .fontWeight(.black)
                                        .foregroundColor(Theme.textPrimary)
                                }
                                Spacer()
                                
                                // Circular progress ring
                                ZStack {
                                    Circle()
                                        .stroke(Theme.surfaceSecondary, lineWidth: 6)
                                        .frame(width: 50, height: 50)
                                    Circle()
                                        .trim(from: 0.0, to: CGFloat(successRate))
                                        .stroke(
                                            LinearGradient(colors: [Theme.primary, Theme.secondary], startPoint: .top, endPoint: .bottom),
                                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                        )
                                        .frame(width: 50, height: 50)
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text("\(Int(successRate * 100))%")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                            
                            if foundCount == totalCount && totalCount > 0 {
                                Text("Perfect! All hidden words have been discovered.")
                                    .font(.caption)
                                    .foregroundColor(Theme.success)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else if foundCount < totalCount && foundCount > 0 {
                                Text("Tap any word below or tap highlighted letters in the grid to isolate paths.")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("Could not find any of the words. Check grid alignment or letters.")
                                    .font(.caption)
                                    .foregroundColor(Theme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                        .glassmorphic()
                        .padding(.horizontal)
                        
                        // Interactive Solved Grid View
                        VStack(spacing: 4) {
                            ForEach(0..<grid.count, id: \.self) { r in
                                HStack(spacing: 4) {
                                    ForEach(0..<grid[r].count, id: \.self) { c in
                                        let coord = Coordinate(row: r, col: c)
                                        let highlights = getCellHighlights(for: coord)
                                        let isCellSelected = isCellPartofSelectedWord(coord)
                                        let hasAnyHighlight = !highlights.isEmpty
                                        
                                        // Background highlight determination
                                        let cellBgColor: Color = {
                                            if let selectedWord = selectedWord,
                                               let placement = solutions[selectedWord],
                                               placement.path.contains(coord) {
                                                // Isolated single word highlight
                                                return getWordColor(selectedWord).opacity(0.8)
                                            } else if selectedWord == nil && hasAnyHighlight {
                                                // Show all overlays
                                                return highlights.first!.color.opacity(0.3)
                                            }
                                            return Theme.surfaceSecondary
                                        }()
                                        
                                        let textOpacity: Double = {
                                            if selectedWord != nil {
                                                return isCellSelected ? 1.0 : 0.25
                                            }
                                            return 1.0
                                        }()
                                        
                                        Button(action: {
                                            HapticManager.shared.impact(.light)
                                            if let primaryHighlight = highlights.first {
                                                if selectedWord == primaryHighlight.word {
                                                    selectedWord = nil // Deselect
                                                } else {
                                                    selectedWord = primaryHighlight.word // Select
                                                }
                                            } else {
                                                selectedWord = nil
                                            }
                                        }) {
                                            Text(String(grid[r][c]))
                                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                                .foregroundColor(isCellSelected || (selectedWord == nil && hasAnyHighlight) ? .white : Theme.textPrimary)
                                                .opacity(textOpacity)
                                                .frame(width: getCellWidth(cols: grid[r].count), height: getCellWidth(cols: grid[r].count))
                                                .background(cellBgColor)
                                                .cornerRadius(6)
                                                .scaleEffect(isCellSelected ? 1.08 : 1.0)
                                                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isCellSelected)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Theme.surface)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // Trait: SolverHintTrait (In-Solver Reveal Word Assist)
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                                .font(.title2)
                                .foregroundStyle(LinearGradient(colors: [Theme.primary, Theme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Need a Clue?")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.textPrimary)
                                Text(stateManager.isPremium ? "Tap to instantly highlight any word's path." : "Watch a short video to reveal the exact path of a hidden word.")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                triggerNextWordHint()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: stateManager.isPremium ? "sparkles" : "play.tv.fill")
                                        .font(.caption2)
                                    Text(stateManager.isPremium ? "Reveal Clue" : "Watch Clue")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(LinearGradient(colors: [Theme.primary, Theme.secondary], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(14)
                                .shadow(color: Theme.primary.opacity(0.35), radius: 5, y: 2)
                            }
                        }
                        .padding(14)
                        .glassmorphic()
                        .padding(.horizontal)
                        
                        // Word list drawer
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Word Tracker")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(1)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                ForEach(words, id: \.self) { word in
                                    let isFound = solutions[word] != nil
                                    let isWordSelected = selectedWord == word
                                    
                                    Button(action: {
                                        HapticManager.shared.impact(.light)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if isWordSelected {
                                                selectedWord = nil
                                            } else {
                                                selectedWord = word
                                            }
                                        }
                                    }) {
                                        HStack {
                                            // Left Status Dot
                                            Circle()
                                                .fill(isFound ? getWordColor(word) : Theme.textMuted)
                                                .frame(width: 8, height: 8)
                                            
                                            Text(word)
                                                .font(.headline)
                                                .foregroundColor(isFound ? Theme.textPrimary : Theme.textMuted)
                                                .strikethrough(isFound && !isWordSelected, color: Theme.textMuted)
                                            
                                            Spacer()
                                            
                                            if isFound {
                                                Text("Found")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(getWordColor(word))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(getWordColor(word).opacity(0.15))
                                                    .cornerRadius(4)
                                            } else {
                                                Text("Not Found")
                                                    .font(.caption2)
                                                    .foregroundColor(Theme.textMuted)
                                            }
                                        }
                                        .padding()
                                        .background(isWordSelected ? Theme.surfaceSecondary : Theme.surface.opacity(0.4))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isWordSelected ? getWordColor(word).opacity(0.5) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .disabled(!isFound) // Disable tapping if not found
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .onAppear {
            solvePuzzle()
        }
    }
    
    private func solvePuzzle() {
        self.solutions = WordsearchSolver.solve(grid: grid, words: words)
    }
    
    private func getCellWidth(cols: Int) -> CGFloat {
        let availableWidth = UIScreen.main.bounds.width - 48
        let spacingCount = CGFloat(max(1, cols - 1))
        return (availableWidth - (spacingCount * 4)) / CGFloat(cols)
    }
    
    // Struct to store highlight color mapped to word
    private struct HighlightInfo {
        let word: String
        let color: Color
    }
    
    private func getCellHighlights(for coord: Coordinate) -> [HighlightInfo] {
        var list = [HighlightInfo]()
        for (word, placement) in solutions {
            if placement.path.contains(coord) {
                list.append(HighlightInfo(word: word, color: getWordColor(word)))
            }
        }
        return list
    }
    
    private func isCellPartofSelectedWord(_ coord: Coordinate) -> Bool {
        guard let selectedWord = selectedWord,
              let placement = solutions[selectedWord] else {
            return false
        }
        return placement.path.contains(coord)
    }
    
    private func getWordColor(_ word: String) -> Color {
        guard let index = words.firstIndex(of: word) else { return Theme.primary }
        return Theme.solvedColors[index % Theme.solvedColors.count]
    }
    
    private func shareSolution() {
        let text = "I just solved this wordsearch using WordSnap iOS! Found \(solutions.count) of \(words.count) words."
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        // Present Activity View
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            // Handle iPad popovers correctly
            if let popoverController = av.popoverPresentationController {
                popoverController.sourceView = rootVC.view
                popoverController.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            rootVC.present(av, animated: true, completion: nil)
        }
    }
    
    // MARK: - Clue / Hint Assist (Trait: SolverHintTrait)
    private func triggerNextWordHint() {
        let foundWords = words.filter { solutions[$0] != nil }
        guard !foundWords.isEmpty else { return }
        
        let targetWord: String
        if let current = selectedWord, let currentIndex = foundWords.firstIndex(of: current) {
            let nextIndex = (currentIndex + 1) % foundWords.count
            targetWord = foundWords[nextIndex]
        } else {
            targetWord = foundWords.first!
        }
        
        if stateManager.isPremium {
            HapticManager.shared.impact(.light)
            revealWordWithToast(targetWord)
        } else {
            HapticManager.shared.impact(.medium)
            AdMobManager.shared.showRewardedAd {
                AdPolicyManager.shared.recordHintUnlocked()
                HapticManager.shared.notification(.success)
                revealWordWithToast(targetWord)
            }
        }
    }
    
    private func revealWordWithToast(_ word: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            selectedWord = word
            hintToastMessage = "Clue Revealed: '\(word)' highlighted! 🔍"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                if hintToastMessage?.contains(word) == true {
                    hintToastMessage = nil
                }
            }
        }
    }
}
