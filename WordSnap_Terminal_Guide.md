# WordSnap Project Audit & Refactoring Guide for Terminal Gemini

## 1. Executive Summary & Architecture Overview
**WordSnap** is a native iOS application written in **SwiftUI** designed to scan and solve word search puzzles in real time using **Apple Vision (OCR)**, **AVFoundation**, and **StoreKit 2**.

### Codebase Structure:
```text
WordSnap/
├── Models/
│   ├── Coordinate.swift        # Matrix coordinates (row, col) & solution paths (WordPlacement)
│   └── SavedPuzzle.swift       # Codable persistence model for historical scans
├── Services/
│   ├── WordsearchSolver.swift  # 8-directional O(R * C * L) matrix word search algorithm
│   ├── OCRProcessor.swift      # Core Vision OCR, CI filter pipeline, spatial clustering & word filtering
│   └── AppStateManager.swift   # Main StoreKit 2 entitlement manager, free scan limits, and puzzle storage
├── Views/
│   ├── HomeView.swift          # Main dashboard, scan triggers, recent puzzle history, ad modal trigger
│   ├── CameraScanView.swift    # AVFoundation live camera preview with target bounding crop
│   ├── GridConfirmView.swift   # Interactive post-scan grid/word verification and manual editor UI
│   ├── SolverView.swift        # Solution visualizer highlighting word paths on matrix with dynamic colors
│   └── PaywallView.swift       # StoreKit 2 paywall interface
```

---

## 2. Technical Pain Points & Issues to Fix

### Issue 1: Web UI Noise & Stray Word Detection
* **Symptom:** Scans of web pages, apps, or printed media incorrectly extract surrounding text (e.g., `https://...`, `Download`, `Share`, `Report Bug`, `Print`, `Copyright`, web navigation links) into the word list or grid matrix.
* **Root Cause in `OCRProcessor.swift`:** `filterNoiseWords()` relies on a simple static keyword set without Regex filtering for complex URLs/web structures, and text observations from the top/bottom regions outside the grid are not strictly cropped spatially.

### Issue 2: Inaccurate Grid Isolation & Matrix Misalignment
* **Symptom:** OCR struggles to reliably locate and align the 2D letter grid, sometimes treating whole rows as continuous text lines or missing columns.
* **Root Cause in `OCRProcessor.swift`:** Text detection uses basic 1D axis-aligned coordinate clustering (`clusterCenters`) without initial shape detection of the grid's outer boundary box.

### Issue 3: Ad Monetization Implementation Status
* **Symptom:** The current rewarded ad system (`RewardedAdModalView` in `HomeView.swift`) uses a local 5-second timer simulation instead of an actual mobile advertising network SDK (Google AdMob or AppLovin MAX).

---

## 3. Targeted Refactoring Plan for Terminal Gemini

When prompted to modify or improve this project, execute the following specific code updates:

### Refactoring Step 1: Upgrade `OCRProcessor.swift` Noise & Spatial Filtering
1. **Regex URL/Domain Stripping:** Update `filterNoiseWords()` to evaluate string tokens against regex patterns for web addresses (`http`, `https`, `www.`, domain extensions like `.com`, `.org`, `.net`, `.html`, `.php`), query parameters, and email syntax.
2. **Spatial Bounding Crop:** Calculate the bounding box ($X_{\text{min}}, Y_{\text{min}}, X_{\text{max}}, Y_{\text{max}}$) of the core letter cluster. Discard any `VNRecognizedTextObservation` sitting outside this bounding box before extracting word candidates or grid cells.

### Refactoring Step 2: Integrate Rectangle Detection for Grid Isolation
1. Add a pre-processing step using Vision’s `VNDetectRectanglesRequest` before running `VNRecognizeTextRequest`.
2. Locate the prominent outer rectangle of the puzzle grid, apply `CIPerspectiveCorrection` (or bounding rect crop), and feed the isolated grid image into the OCR pipeline.
3. Enforce consistent cell spacing ($\Delta X, \Delta Y$) across the detected grid matrix to automatically populate missing characters with `"?"` placeholders rather than corrupting row lengths.

### Refactoring Step 3: Implement Real Ad SDK (Google AdMob / AppLovin)
1. Replace `RewardedAdModalView` in `HomeView.swift` with Google AdMob `GADRewardedAd` integration.
2. Bind the `rewardedAd.present(fromRootViewController:)` completion handler to call `stateManager.grantAdRewardSolve()` upon successful reward verification.

---

## 4. Prompting Quick Reference for Terminal Gemini

* **To fix OCR/noise issues:** *"Refactor `OCRProcessor.swift` to add regex URL filtering and strict spatial bounding box isolation around the detected letter grid."*
* **To fix grid detection:** *"Update `OCRProcessor.swift` to use `VNDetectRectanglesRequest` for cropping and perspective-correcting the puzzle grid before text recognition."*
* **To integrate real ads:** *"Replace the simulated ad modal in `HomeView.swift` and `AppStateManager.swift` with Google Mobile Ads SDK GADRewardedAd integration."*
