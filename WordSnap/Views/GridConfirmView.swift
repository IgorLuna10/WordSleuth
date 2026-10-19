import SwiftUI

public struct GridConfirmView: View {
    @EnvironmentObject private var stateManager: AppStateManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var grid: [[Character]]
    @State private var words: [String]
    
    // Grid editing state
    @State private var selectedCell: (row: Int, col: Int)? = nil
    @State private var editLetterText: String = ""
    @State private var showingEditCellAlert = false
    
    // Word list editing state
    @State private var newWordText: String = ""
    @State private var editingWordIndex: Int? = nil
    
    // Navigation to Solver
    @State private var navigateToSolver = false
    
    // Contextual Peak Investment Paywall & Ad Sheets
    @State private var showingContextualSolveSheet = false
    @State private var showingPaywall = false
    
    public init(initialGrid: [[Character]], initialWords: [String]) {
        _grid = State(initialValue: initialGrid)
        
        // Clean up the initial words (remove empty values and duplicates)
        let cleaned = Array(Set(initialWords.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }))
            .filter { !$0.isEmpty }
            .sorted()
        _words = State(initialValue: cleaned)
    }
    
    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation / Header title
                HStack {
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(Theme.primary)
                    }
                    Spacer()
                    Text("Verify Scan")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        setupBlankGrid()
                    }) {
                        Text("Reset")
                            .font(.subheadline)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Section 1: Letter Grid & Size Adjuster
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Puzzle Grid")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textSecondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Spacer()
                                
                                // Grid Dimensions Adjuster
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Text("Rows:")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textMuted)
                                        
                                        Button(action: { changeRows(by: -1) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(grid.count > 3 ? Theme.primary : Theme.textMuted)
                                        }
                                        .disabled(grid.count <= 3)
                                        
                                        Text("\(grid.count)")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Button(action: { changeRows(by: 1) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(grid.count < 30 ? Theme.primary : Theme.textMuted)
                                        }
                                        .disabled(grid.count >= 30)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Text("Cols:")
                                            .font(.caption2)
                                            .foregroundColor(Theme.textMuted)
                                        
                                        Button(action: { changeCols(by: -1) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.caption)
                                                .foregroundColor((grid.first?.count ?? 0) > 3 ? Theme.secondary : Theme.textMuted)
                                        }
                                        .disabled((grid.first?.count ?? 0) <= 3)
                                        
                                        Text("\(grid.first?.count ?? 0)")
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Button(action: { changeCols(by: 1) }) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.caption)
                                                .foregroundColor((grid.first?.count ?? 0) < 30 ? Theme.secondary : Theme.textMuted)
                                        }
                                        .disabled((grid.first?.count ?? 0) >= 30)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.surfaceSecondary)
                                .cornerRadius(20)
                            }
                            .padding(.horizontal)
                            
                            if grid.isEmpty {
                                Text("No grid detected. Tap Reset to create one.")
                                    .foregroundColor(Theme.textMuted)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                // Grid Renderer
                                VStack(spacing: 4) {
                                    ForEach(0..<grid.count, id: \.self) { r in
                                        HStack(spacing: 4) {
                                            ForEach(0..<grid[r].count, id: \.self) { c in
                                                let isSelected = selectedCell?.row == r && selectedCell?.col == c
                                                
                                                Button(action: {
                                                    HapticManager.shared.impact(.light)
                                                    selectedCell = (row: r, col: c)
                                                    editLetterText = String(grid[r][c])
                                                    showingEditCellAlert = true
                                                }) {
                                                    Text(String(grid[r][c]))
                                                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                                                        .foregroundColor(isSelected ? Theme.background : (grid[r][c] == "?" ? Theme.accent : Theme.textPrimary))
                                                        .frame(width: getCellWidth(cols: grid[r].count), height: getCellWidth(cols: grid[r].count))
                                                        .background(isSelected ? Theme.primary : Theme.surfaceSecondary)
                                                        .cornerRadius(6)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 6)
                                                                .stroke(grid[r][c] == "?" ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
                                                        )
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Theme.surface)
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                            
                            Text("Tip: Tap any cell to correct misread letters (marked in pink if unread).")
                                .font(.caption2)
                                .foregroundColor(Theme.textMuted)
                                .padding(.horizontal)
                        }
                        
                        // Section 2: Words to Find
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Words to Find")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(1)
                                .padding(.horizontal)
                            
                            // Word list cards
                            if words.isEmpty {
                                Text("No words added yet.")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.textMuted)
                                    .padding(.horizontal)
                            } else {
                                FlowLayout(spacing: 8, items: words) { word in
                                    HStack(spacing: 6) {
                                        Text(word)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Button(action: {
                                            HapticManager.shared.impact(.light)
                                            if let index = words.firstIndex(of: word) {
                                                words.remove(at: index)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Theme.textMuted)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.surfaceSecondary)
                                    .cornerRadius(20)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Add word inputs
                            HStack {
                                TextField("Add missing word...", text: $newWordText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(12)
                                    .background(Theme.surfaceSecondary)
                                    .cornerRadius(10)
                                    .foregroundColor(Theme.textPrimary)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled(true)
                                
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    let cleanWord = newWordText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                    if !cleanWord.isEmpty && !words.contains(cleanWord) {
                                        words.append(cleanWord)
                                        words.sort()
                                        newWordText = ""
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Theme.primary)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 120)
                }
                
                // Bottom Floating CTA Bar
                VStack {
                    Divider()
                        .background(Theme.surfaceSecondary)
                    PremiumButton(title: "Solve Wordsearch!", icon: "sparkles") {
                        handleSolveTap()
                    }
                    .padding()
                }
                .background(Theme.background.opacity(0.9))
            }
        }
        .navigationDestination(isPresented: $navigateToSolver) {
            SolverView(grid: grid, words: words)
        }
        .sheet(isPresented: $showingEditCellAlert) {
            EditCellSheet(letter: $editLetterText) { newLetter in
                if let cell = selectedCell {
                    let letterChar = newLetter.first?.uppercased().first ?? "?"
                    grid[cell.row][cell.col] = letterChar
                    showingEditCellAlert = false
                }
            }
            .presentationDetents([.height(150)])
        }
        .sheet(isPresented: $showingContextualSolveSheet) {
            ContextualSolveSheet(
                gridDimensions: "\(grid.count)×\(grid.first?.count ?? 0)",
                onWatchAd: {
                    AdMobManager.shared.showRewardedAd {
                        stateManager.grantAdRewardSolve()
                        stateManager.consumeFreeScan()
                        AdPolicyManager.shared.recordScanCompleted()
                        stateManager.addPuzzleToHistory(grid: grid, words: words)
                        showingContextualSolveSheet = false
                        navigateToSolver = true
                    }
                },
                onGoPro: {
                    showingContextualSolveSheet = false
                    showingPaywall = true
                }
            )
            .presentationDetents([.fraction(0.55), .medium])
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    private func handleSolveTap() {
        if stateManager.canScan {
            HapticManager.shared.notification(.success)
            stateManager.consumeFreeScan()
            AdPolicyManager.shared.recordScanCompleted()
            stateManager.addPuzzleToHistory(grid: grid, words: words)
            navigateToSolver = true
        } else {
            HapticManager.shared.impact(.medium)
            showingContextualSolveSheet = true
        }
    }
    
    private func getCellWidth(cols: Int) -> CGFloat {
        let availableWidth = UIScreen.main.bounds.width - 48
        let spacingCount = CGFloat(max(1, cols - 1))
        return (availableWidth - (spacingCount * 4)) / CGFloat(cols)
    }
    
    private func setupBlankGrid() {
        self.grid = [
            ["A", "B", "C", "D", "E"],
            ["F", "G", "H", "I", "J"],
            ["K", "L", "M", "N", "O"],
            ["P", "Q", "R", "S", "T"],
            ["U", "V", "W", "X", "Y"]
        ]
        self.words = []
    }
    
    private func changeRows(by delta: Int) {
        HapticManager.shared.impact(.light)
        let currentCols = grid.first?.count ?? 10
        if delta > 0 {
            for _ in 0..<delta {
                grid.append([Character](repeating: "?", count: currentCols))
            }
        } else if delta < 0 {
            let removeCount = min(abs(delta), grid.count - 3)
            if removeCount > 0 {
                grid.removeLast(removeCount)
            }
        }
    }
    
    private func changeCols(by delta: Int) {
        HapticManager.shared.impact(.light)
        if delta > 0 {
            for r in 0..<grid.count {
                grid[r].append(contentsOf: [Character](repeating: "?", count: delta))
            }
        } else if delta < 0 {
            let currentCols = grid.first?.count ?? 0
            let removeCount = min(abs(delta), currentCols - 3)
            if removeCount > 0 {
                for r in 0..<grid.count {
                    grid[r].removeLast(removeCount)
                }
            }
        }
    }
}

// Inline modal sheet for editing single cell character
struct EditCellSheet: View {
    @Binding var letter: String
    var onSave: (String) -> Void
    
    var body: some View {
        ZStack {
            Theme.surface.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Enter Character")
                    .font(.headline)
                    .foregroundColor(Theme.textPrimary)
                
                HStack {
                    TextField("A", text: $letter)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 60, height: 50)
                        .background(Theme.surfaceSecondary)
                        .cornerRadius(10)
                        .foregroundColor(Theme.textPrimary)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .onChange(of: letter) { _, newValue in
                            if newValue.count > 1 {
                                letter = String(newValue.prefix(1))
                            }
                        }
                    
                    Button(action: {
                        onSave(letter)
                    }) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(Theme.primary)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
    }
}

// Custom flow layout to display tags elegantly wraps items
struct FlowLayout<T: Hashable, V: View>: View {
    let spacing: CGFloat
    let items: [T]
    let content: (T) -> V
    
    @State private var totalHeight = CGFloat.zero
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                self.content(item)
                    .padding([.horizontal, .vertical], spacing / 2)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == self.items.last! {
                            width = 0 // last item
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if item == self.items.last! {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geo in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: geo.frame(in: .local).size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { h in
            binding.wrappedValue = h
        }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Peak Investment Contextual Solve Sheet
struct ContextualSolveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let gridDimensions: String
    let onWatchAd: () -> Void
    let onGoPro: () -> Void
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Drag Indicator Pill
                Capsule()
                    .fill(Theme.surfaceSecondary)
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Theme.success)
                    Text("\(gridDimensions) Grid Ready to Solve")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Theme.surfaceSecondary)
                .cornerRadius(20)
                
                VStack(spacing: 8) {
                    Text("Unlock Full Solution 🎯")
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("You've used all free daily solves. Watch a quick sponsor video to reveal all words right now, or unlock Pro for unlimited instant solves.")
                        .font(.footnote)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                VStack(spacing: 12) {
                    // Watch Video to Solve Button
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onWatchAd()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.tv.fill")
                                .font(.headline)
                            Text("Watch Video to Solve (Free)")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [Theme.primary, Theme.secondary], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: Theme.primary.opacity(0.4), radius: 8, y: 3)
                    }
                    
                    // Go Pro Button
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onGoPro()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Unlock Unlimited with Pro")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.surfaceSecondary)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

