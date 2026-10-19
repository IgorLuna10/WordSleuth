# WordSnap 🔍 — Real-Time Word Search Scanner & Solver for iOS

> **TL;DR (FR)** : Application iOS native développée en **Swift / SwiftUI** utilisant les frameworks **Apple Vision** et **AVFoundation** pour scanner et résoudre en temps réel des grilles de mots mêlés (sur papier ou écran). Elle intègre un pipeline OCR avec filtrage spatial et suppression de bruit, un algorithme de résolution matricielle 8-directionnel $O(R \times C \times L)$, et une interface interactive avec visualisation dynamique des trajectoires de mots et gestion des abonnements via **StoreKit 2**.

A native iOS puzzle-solving application that uses on-device computer vision and optical character recognition (OCR) to capture physical word search puzzle grids, extract the matrix of letters, and instantly solve and visualize all hidden word trajectories.

---

## 📸 How It Works

```text
┌─────────────────┐       ┌────────────────────────┐       ┌──────────────────────┐
│  Live Camera /  │ ───►  │  Apple Vision + CI     │ ───►  │  Spatial Clustering  │
│  AVFoundation   │       │ (Contrast & Grayscale) │       │ (Matrix & Word List) │
└─────────────────┘       └────────────────────────┘       └──────────┬───────────┘
                                                                      │
┌─────────────────┐       ┌────────────────────────┐       ┌──────────▼───────────┐
│ Solution View   │ ◄───  │ 8-Directional Solver   │ ◄───  │ Interactive Grid     │
│ (Path Highlight)│       │ Algorithm O(R x C x L) │       │ Verification UI      │
└─────────────────┘       └────────────────────────┘       └──────────────────────┘
```

1. **Camera Capture**: Streams live video via `AVFoundation` with bounding crop guidance.
2. **Vision OCR Pipeline**: Preprocesses frames with CoreImage filters and extracts character bounding boxes using Apple's `VNRecognizeTextRequest`.
3. **Spatial Clustering & Noise Filtering**: Isolates the character grid from surrounding website/page text and UI artifacts.
4. **Interactive Verification**: Users confirm or edit the scanned grid and target word list.
5. **Matrix Word Search Solver**: Executes an optimized 8-way directional search across the grid matrix and overlays color-coded paths on the puzzle.

---

## ⚡ Key Highlights

- **On-Device Vision OCR**: Powered entirely by native Apple Vision (`VNRecognizeTextRequest`) — fast, private, and works offline without cloud API roundtrips.
- **8-Directional Matrix Solver**: Scans horizontal, vertical, and diagonal paths in forward and reverse orientations with early termination.
- **Noise Rejection**: Custom regex and bounding box filters discard headers, footers, website URLs, and copyright strings from scans.
- **Modern SwiftUI Architecture**: Clean MVVM separation with reactive state management (`AppStateManager`).
- **In-App Monetization & Subscriptions**: Integrated StoreKit 2 paywall with free scan quota tracking.

---

## 🛠 Tech Stack

| Component | Technology |
| :--- | :--- |
| **Platform** | iOS 17.0+ (iPhone & iPad) |
| **Language & UI** | Swift 5.9+, SwiftUI |
| **Computer Vision & OCR** | Apple Vision (`VisionKit`), `CoreImage` |
| **Camera & Video** | `AVFoundation` |
| **Persistence & Architecture** | `Codable`, MVVM, Combine |
| **Monetization** | StoreKit 2, Google Mobile Ads (AdMob) |

---

## 🚀 Quick Start

### Prerequisites
- macOS Sonoma or later
- [Xcode 15+](https://developer.apple.com/xcode/)
- Physical iOS device or iOS Simulator (Physical device recommended for camera features)

### Setup & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/IgorLuna10/WordSnap.git
   cd WordSnap
   ```

2. **Open in Xcode:**
   ```bash
   open WordSnap.xcodeproj
   ```

3. **Configure Signing:**
   - In Xcode, select the `WordSnap` target.
   - Go to **Signing & Capabilities** and select your Apple Developer team.

4. **Build & Run:**
   - Select your target device or simulator and press `Cmd + R`.

---

## 💡 What I Learned

- **Spatial Text Clustering**: Real-world puzzle grids often feature non-uniform spacing and perspective skew. Grouping individual letter observations into a reliable 2D matrix required adaptive spatial tolerance algorithms.
- **Zero-Latency Traversal**: Built an 8-way directional wordsearch traversal in Swift that evaluates hundreds of candidate word vectors across large matrices in sub-millisecond execution times.
- **Camera Buffer Memory Management**: Managed `CMSampleBuffer` conversion into `CIImage` pipelines without frame drops or memory leaks during continuous live scanning.
