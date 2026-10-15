import Foundation
import UIKit
import Vision
import CoreImage

public class OCRProcessor {
    
    public struct ScannedResult {
        public let grid: [[Character]]
        public let words: [String]
    }
    
    private static func detectGridRectangle(in cgImage: CGImage, orientation: CGImagePropertyOrientation) -> VNRectangleObservation? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.3 // The grid should occupy at least 30% of the image size
        request.maximumObservations = 1 // Get the most prominent rectangle
        
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNRectangleObservation
        } catch {
            return nil
        }
    }

    private static func cropAndPerspectiveCorrect(image: UIImage, rectangle: VNRectangleObservation) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let imageSize = ciImage.extent.size
        
        // Convert normalized corner points to image coordinates.
        // Origin is bottom-left for both Vision and Core Image.
        let topLeft = CGPoint(x: rectangle.topLeft.x * imageSize.width, y: rectangle.topLeft.y * imageSize.height)
        let topRight = CGPoint(x: rectangle.topRight.x * imageSize.width, y: rectangle.topRight.y * imageSize.height)
        let bottomLeft = CGPoint(x: rectangle.bottomLeft.x * imageSize.width, y: rectangle.bottomLeft.y * imageSize.height)
        let bottomRight = CGPoint(x: rectangle.bottomRight.x * imageSize.width, y: rectangle.bottomRight.y * imageSize.height)
        
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        
        guard let outputCIImage = filter.outputImage else { return nil }
        
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
        }
        return nil
    }

    /// Processes a wordsearch image and returns the recognized grid and list of words.
    /// - Parameters:
    ///   - image: The UIImage to scan.
    ///   - completion: A completion handler returned on the main queue with the result.
    public static func processImage(_ image: UIImage, completion: @escaping (Result<ScannedResult, Error>) -> Void) {
        // Preprocess the image to enhance letter borders and wash out gray shadows
        let preprocessedImage = preprocessImage(image)
        
        guard let cgImage = preprocessedImage.cgImage else {
            completion(.failure(NSError(domain: "OCRProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid CGImage from UIImage"])))
            return
        }
        
        let orientation = CGImagePropertyOrientation(preprocessedImage.imageOrientation)
        
        // Try to isolate the outer grid boundary box using rectangle detection
        var isolatedGridImage: UIImage? = nil
        if let rect = detectGridRectangle(in: cgImage, orientation: orientation) {
            isolatedGridImage = cropAndPerspectiveCorrect(image: preprocessedImage, rectangle: rect)
        }
        
        if let gridImg = isolatedGridImage, let gridCgImg = gridImg.cgImage {
            // We have an isolated, perspective-corrected grid image!
            // Run text recognition on the full image to get the word bank, and on the isolated grid image to get the grid cells.
            var fullObservations = [VNRecognizedTextObservation]()
            var gridObservations = [VNRecognizedTextObservation]()
            
            let group = DispatchGroup()
            
            // Task 1: Full image text recognition for word bank candidates
            group.enter()
            let fullRequest = VNRecognizeTextRequest { request, error in
                defer { group.leave() }
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    fullObservations = observations
                }
            }
            fullRequest.recognitionLevel = .accurate
            fullRequest.usesLanguageCorrection = false
            fullRequest.recognitionLanguages = ["en-US"]
            fullRequest.minimumTextHeight = 0.015
            
            // Task 2: Isolated grid image text recognition for precise grid cell characters
            group.enter()
            let gridRequest = VNRecognizeTextRequest { request, error in
                defer { group.leave() }
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    gridObservations = observations
                }
            }
            gridRequest.recognitionLevel = .accurate
            gridRequest.usesLanguageCorrection = false
            gridRequest.recognitionLanguages = ["en-US"]
            
            let fullHandler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            let gridHandler = VNImageRequestHandler(cgImage: gridCgImg, orientation: .up, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try fullHandler.perform([fullRequest])
                } catch {}
                do {
                    try gridHandler.perform([gridRequest])
                } catch {}
                
                group.notify(queue: .main) {
                    let result = parseDualObservations(fullObservations: fullObservations, gridObservations: gridObservations)
                    completion(.success(result))
                }
            }
        } else {
            // Fallback: Run standard single request on the full preprocessed image
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "OCRProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "No text recognized in image"])))
                    }
                    return
                }
                
                let result = parseObservations(observations)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            }
            
            // Configure for accurate text recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false // Crucial: do not autocorrect letter grids!
            request.recognitionLanguages = ["en-US"]
            // Ignore tiny specks/noise so they don't get picked up as stray grid letters.
            request.minimumTextHeight = 0.015
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
        }
    }
    
    private static func parseDualObservations(fullObservations: [VNRecognizedTextObservation], gridObservations: [VNRecognizedTextObservation]) -> ScannedResult {
        var potentialWords = [String]()
        for observation in fullObservations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let looksLikeWordListLine = containsMultipleWordTokens(trimmed)
            let isInWordBandRegion = observation.boundingBox.origin.y < 0.22
            
            if looksLikeWordListLine || isInWordBandRegion {
                let tokens = trimmed
                    .components(separatedBy: CharacterSet(charactersIn: " ,;:•*\n\t"))
                    .map { $0.trimmingCharacters(in: .alphanumerics.inverted) }
                    .filter { $0.count > 2 }
                potentialWords.append(contentsOf: tokens)
            }
        }
        
        var gridChars = [CharPoint]()
        for observation in gridObservations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            for (idx, char) in text.enumerated() {
                guard char.isLetter else { continue }
                let stringIndex = text.index(text.startIndex, offsetBy: idx)
                let range = stringIndex..<text.index(after: stringIndex)
                
                if let box = try? candidate.boundingBox(for: range) {
                    let rect = box.boundingBox
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    gridChars.append(CharPoint(char: Character(char.uppercased()), center: center, box: rect, confidence: candidate.confidence))
                } else {
                    let cellWidth = observation.boundingBox.width / CGFloat(max(1, text.count))
                    let charX = observation.boundingBox.origin.x + (CGFloat(idx) * cellWidth)
                    let rect = CGRect(x: charX, y: observation.boundingBox.origin.y, width: cellWidth, height: observation.boundingBox.height)
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    gridChars.append(CharPoint(char: Character(char.uppercased()), center: center, box: rect, confidence: candidate.confidence))
                }
            }
        }
        
        guard !gridChars.isEmpty else {
            return ScannedResult(grid: [], words: filterNoiseWords(potentialWords, grid: []))
        }
        
        let grid = reconstructGrid(from: gridChars)
        let cleanedWords = filterNoiseWords(potentialWords, grid: grid)
        return ScannedResult(grid: grid, words: cleanedWords)
    }
    
    private static func preprocessImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        // 1. Convert to black & white / grayscale
        let grayscale = ciImage.applyingFilter("CIPhotoEffectMono")
        
        // 2. Increase contrast and wash out gray shadows (paper wrinkles, lighting shadows)
        let filtered = grayscale.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 1.7,
            kCIInputBrightnessKey: 0.12
        ])
        
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(filtered, from: filtered.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
    
    /// A single recognized letter and where it actually sits in the image,
    /// independent of which Vision "line"/observation it happened to come from.
    private struct CharPoint {
        let char: Character
        let center: CGPoint     // Vision-normalized coords: origin bottom-left, 0...1
        let box: CGRect
        let confidence: Float
    }

    private static func isNoiseToken(_ raw: String) -> Bool {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check for URL patterns
        if lower.contains("http://") || lower.contains("https://") || lower.contains("www.") {
            return true
        }
        
        // 2. Regex for domain extensions, query parameters, emails, and web patterns
        let patterns = [
            // Domain extensions: matches .com, .org, .net, .html, .php, etc. (e.g., site.com, index.html)
            "\\.[a-z]{2,4}\\b",
            // Query parameters: matches things like ?ref=, &utm=, key=value
            "[?&][a-z0-9_]+=[a-z0-9_]*",
            // Email syntax: matches user@domain.com
            "[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,4}",
            // Web extensions explicitly (.html, .php, etc.)
            "\\.(html|php|asp|jsp)\\b"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: lower.utf16.count)
                if regex.firstMatch(in: lower, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }

    private static func parseObservations(_ observations: [VNRecognizedTextObservation]) -> ScannedResult {
        var gridChars = [CharPoint]()
        var potentialWords = [String]()

        // Calculate the bounding box of the core letter cluster first
        var tempGridChars = [CharPoint]()
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let looksLikeWordListLine = containsMultipleWordTokens(trimmed)
            let isInWordBandRegion = observation.boundingBox.origin.y < 0.22
            
            if looksLikeWordListLine || isInWordBandRegion {
                continue
            }
            
            for (idx, char) in text.enumerated() {
                guard char.isLetter else { continue }
                let stringIndex = text.index(text.startIndex, offsetBy: idx)
                let range = stringIndex..<text.index(after: stringIndex)
                
                let rect: CGRect
                if let box = try? candidate.boundingBox(for: range) {
                    rect = box.boundingBox
                } else {
                    let cellWidth = observation.boundingBox.width / CGFloat(max(1, text.count))
                    let charX = observation.boundingBox.origin.x + (CGFloat(idx) * cellWidth)
                    rect = CGRect(x: charX, y: observation.boundingBox.origin.y, width: cellWidth, height: observation.boundingBox.height)
                }
                let center = CGPoint(x: rect.midX, y: rect.midY)
                tempGridChars.append(CharPoint(char: Character(char.uppercased()), center: center, box: rect, confidence: candidate.confidence))
            }
        }
        
        let coreGridChars = filterGridCharsToCoreRegion(tempGridChars)
        
        let minX: CGFloat
        let maxX: CGFloat
        let minY: CGFloat
        let maxY: CGFloat
        
        if !coreGridChars.isEmpty {
            minX = coreGridChars.map { $0.box.minX }.min() ?? 0.0
            maxX = coreGridChars.map { $0.box.maxX }.max() ?? 1.0
            minY = coreGridChars.map { $0.box.minY }.min() ?? 0.0
            maxY = coreGridChars.map { $0.box.maxY }.max() ?? 1.0
        } else {
            minX = 0.0
            maxX = 1.0
            minY = 0.0
            maxY = 1.0
        }
        
        // Define active puzzle bounding box (covers grid + word bank below)
        let activeBoundingBox = CGRect(
            x: max(0.0, minX - 0.08),
            y: max(0.0, minY - 0.35),
            width: min(1.0, maxX + 0.08) - max(0.0, minX - 0.08),
            height: min(1.0, maxY + 0.05) - max(0.0, minY - 0.35)
        )

        for observation in observations {
            // Discard observations sitting outside the active spatial bounding box
            if !coreGridChars.isEmpty {
                if !activeBoundingBox.intersects(observation.boundingBox) {
                    continue
                }
            }

            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Decide whether this whole observation is a "word list" entry rather than
            // part of the grid. Two independent signals, either is enough:
            //  1. It contains normal inter-word spacing with multiple real-looking
            //     words (grid letters are never emitted with word-style spacing).
            //  2. It sits in the bottom portion of the image, where word banks are
            //     conventionally printed below the puzzle grid.
            let looksLikeWordListLine = containsMultipleWordTokens(trimmed)
            let isInWordBandRegion = observation.boundingBox.origin.y < 0.22

            if looksLikeWordListLine || isInWordBandRegion {
                let tokens = trimmed
                    .components(separatedBy: CharacterSet(charactersIn: " ,;:•*\n\t"))
                    .map { $0.trimmingCharacters(in: .alphanumerics.inverted) }
                    .filter { $0.count > 2 }
                potentialWords.append(contentsOf: tokens)
                continue
            }

            // Otherwise, treat every letter in this observation as its own grid cell.
            // We fetch each character's OWN bounding box directly from Vision rather
            // than relying on the observation's line/row grouping — this is what lets
            // us correctly reconstruct rows/columns even when Vision splits a single
            // grid row into several small observations (which it very often does for
            // widely, evenly spaced letters).
            for (idx, char) in text.enumerated() {
                guard char.isLetter else { continue }
                let stringIndex = text.index(text.startIndex, offsetBy: idx)
                let range = stringIndex..<text.index(after: stringIndex)

                if let box = try? candidate.boundingBox(for: range) {
                    let rect = box.boundingBox
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    gridChars.append(CharPoint(char: Character(char.uppercased()), center: center, box: rect, confidence: candidate.confidence))
                } else {
                    // Fallback: Estimate position linearly across the observation box
                    let cellWidth = observation.boundingBox.width / CGFloat(max(1, text.count))
                    let charX = observation.boundingBox.origin.x + (CGFloat(idx) * cellWidth)
                    let rect = CGRect(x: charX, y: observation.boundingBox.origin.y, width: cellWidth, height: observation.boundingBox.height)
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    gridChars.append(CharPoint(char: Character(char.uppercased()), center: center, box: rect, confidence: candidate.confidence))
                }
            }
        }

        guard !gridChars.isEmpty else {
            return ScannedResult(grid: [], words: filterNoiseWords(potentialWords, grid: []))
        }

        let grid = reconstructGrid(from: gridChars)
        let cleanedWords = filterNoiseWords(potentialWords, grid: grid)
        return ScannedResult(grid: grid, words: cleanedWords)
    }

    // UI Noise & Navigation Keywords Filter
    private static let noiseBlacklistKeywords: Set<String> = [
        "DOWNLOAD", "PRINT", "PUZZLE", "SETTINGS", "SHARE", "REPORT", "BUG",
        "THEME", "GAME", "DIFFICULTY", "EASY", "MEDIUM", "HARD", "SCORE",
        "TIME", "TIMER", "PAUSE", "RESTART", "COPYRIGHT", "RIGHTS", "RESERVED",
        "PAGE", "HTTP", "HTTPS", "WWW", "COM", "NET", "ORG", "HTML", "PHP",
        "FIND", "WORDS", "HIDDEN", "GRID", "SEARCH", "DIAGONAL", "HORIZONTAL",
        "VERTICAL", "LIST", "WORD", "WORDSEARCH", "SOLVER", "CANCEL", "CLEAR",
        "SELECT", "ENTER", "CLICK", "SUBMIT", "BACK", "MENU", "HOME", "OPTIONS",
        "NEW", "DAILY", "LEVEL", "SOLUTION", "SOLVED", "ANSWER", "ANSWERS",
        "HELP", "INFO", "ABOUT", "VERSION", "LOGIN", "SIGN", "REGISTER"
    ]
    
    private static func filterNoiseWords(_ rawTokens: [String], grid: [[Character]]) -> [String] {
        var validWords = [String]()
        
        for raw in rawTokens {
            // First check if raw token matches any noise/web pattern
            if isNoiseToken(raw) {
                continue
            }

            let upper = raw.uppercased().trimmingCharacters(in: .alphanumerics.inverted)
            
            // 1. Length check: word search words are at least 3 chars, max 20 chars
            guard upper.count >= 3 && upper.count <= 20 else { continue }
            
            // 2. Contains only letters (no numbers, punctuation, or symbols)
            guard upper.allSatisfy({ $0.isLetter }) else { continue }
            
            // 3. Blacklist check for web/app UI noise
            guard !noiseBlacklistKeywords.contains(upper) else { continue }
            
            // 4. URL / Web pattern check
            if upper.contains("HTTP") || upper.contains("WWW") || upper.contains("HTML") {
                continue
            }
            
            validWords.append(upper)
        }
        
        let uniqueWords = Array(Set(validWords)).sorted()
        
        // 5. Prioritize words that are actually found inside the grid using WordsearchSolver!
        if !grid.isEmpty {
            let solved = WordsearchSolver.solve(grid: grid, words: uniqueWords)
            let inGridWords = uniqueWords.filter { solved[$0] != nil }
            
            if !inGridWords.isEmpty {
                let otherWords = uniqueWords.filter { solved[$0] == nil }
                // Put verified in-grid words first, append up to 5 additional candidates if OCR misread 1 letter
                return inGridWords + otherWords.prefix(max(0, 5))
            }
        }
        
        return uniqueWords
    }

    /// True if a trimmed line of text reads like normal prose/word-list spacing —
    /// two or more alphabetic tokens of length >= 3 separated by whitespace or
    /// punctuation. A word search grid never produces this from a single
    /// observation because adjacent grid letters aren't separated the way words are.
    private static func containsMultipleWordTokens(_ text: String) -> Bool {
        let tokens = text
            .components(separatedBy: CharacterSet(charactersIn: " ,;:•*\t"))
            .map { $0.trimmingCharacters(in: .alphanumerics.inverted) }
            .filter { $0.count >= 3 && $0.allSatisfy { $0.isLetter } }
        return tokens.count >= 2
    }

    /// Strips out stray header/footer text observations by cropping grid points to the dense core grid region.
    private static func filterGridCharsToCoreRegion(_ chars: [CharPoint]) -> [CharPoint] {
        guard chars.count > 10 else { return chars }
        
        let avgHeight = chars.map { $0.box.height }.reduce(0, +) / CGFloat(chars.count)
        let rawYs = clusterCenters(chars.map { $0.center.y }, tolerance: max(avgHeight * 0.55, 0.008))
            .sorted(by: >)
        
        // Count characters in each Y row candidate
        let rowCounts = rawYs.map { rY in
            chars.filter { abs($0.center.y - rY) <= avgHeight * 0.6 }.count
        }
        
        let maxRowLength = rowCounts.max() ?? 0
        guard maxRowLength >= 3 else { return chars }
        
        // Find rows that belong to the main letter matrix (at least 45% of max row length)
        let gridRowYs = rawYs.enumerated()
            .filter { rowCounts[$0.offset] >= max(3, Int(Double(maxRowLength) * 0.45)) }
            .map { $0.element }
        
        guard !gridRowYs.isEmpty else { return chars }
        
        let minY = (gridRowYs.min() ?? 0) - (avgHeight * 0.8)
        let maxY = (gridRowYs.max() ?? 1) + (avgHeight * 0.8)
        
        let filtered = chars.filter { $0.center.y >= minY && $0.center.y <= maxY }
        return filtered.isEmpty ? chars : filtered
    }

    /// Reconstructs the grid purely from each letter's 2D position, by clustering
    /// character centers into rows (by Y) and columns (by X) and enforcing consistent cell spacing.
    private static func reconstructGrid(from chars: [CharPoint]) -> [[Character]] {
        let coreChars = filterGridCharsToCoreRegion(chars)
        guard !coreChars.isEmpty else { return [] }

        let avgHeight = coreChars.map { $0.box.height }.reduce(0, +) / CGFloat(coreChars.count)
        let avgWidth = coreChars.map { $0.box.width }.reduce(0, +) / CGFloat(coreChars.count)

        // Cluster tolerances: half a character's size is a safe gap to treat two
        // letters as "the same row/column" without merging genuinely adjacent rows.
        let rawRowCenters = clusterCenters(coreChars.map { $0.center.y }, tolerance: max(avgHeight * 0.55, 0.008))
            .sorted(by: >)  // Vision Y: 0 = bottom, 1 = top -> descending puts row 0 at the top
        let rawColCenters = clusterCenters(coreChars.map { $0.center.x }, tolerance: max(avgWidth * 0.55, 0.008))
            .sorted()

        guard !rawRowCenters.isEmpty, !rawColCenters.isEmpty else { return [] }

        // Filter out noise clusters that contain too few characters to be real grid lines
        let minCharsPerRow = max(2, coreChars.count / (rawRowCenters.count * 3))
        let minCharsPerCol = max(2, coreChars.count / (rawColCenters.count * 3))

        let rowCounts = rawRowCenters.map { rCenter in
            coreChars.filter { abs($0.center.y - rCenter) <= avgHeight * 0.6 }.count
        }
        let colCounts = rawColCenters.map { cCenter in
            coreChars.filter { abs($0.center.x - cCenter) <= avgWidth * 0.6 }.count
        }

        let validRowCenters = rawRowCenters.enumerated()
            .filter { rowCounts[$0.offset] >= minCharsPerRow }
            .map { $0.element }
        let validColCenters = rawColCenters.enumerated()
            .filter { colCounts[$0.offset] >= minCharsPerCol }
            .map { $0.element }

        let rowCenters = validRowCenters.isEmpty ? rawRowCenters : validRowCenters
        let colCenters = validColCenters.isEmpty ? rawColCenters : validColCenters

        // Calculate consistent cell spacing (Delta X, Delta Y) using median gap
        func calculateMedianSpacing(_ centers: [CGFloat]) -> CGFloat? {
            guard centers.count > 1 else { return nil }
            var gaps = [CGFloat]()
            for i in 0..<(centers.count - 1) {
                gaps.append(abs(centers[i+1] - centers[i]))
            }
            let sortedGaps = gaps.sorted()
            return sortedGaps[sortedGaps.count / 2]
        }

        let deltaX = calculateMedianSpacing(colCenters) ?? (avgWidth * 1.5)
        let deltaY = calculateMedianSpacing(rowCenters) ?? (avgHeight * 1.5)

        // Generate consistent regular grid line centers
        let minColX = colCenters.first ?? 0.1
        let maxColX = colCenters.last ?? 0.9
        let colStep = max(0.001, deltaX)
        let numCols = max(1, Int(round((maxColX - minColX) / colStep)) + 1)
        let regularColCenters = (0..<numCols).map { minColX + CGFloat($0) * colStep }

        let minRowY = rowCenters.last ?? 0.1
        let maxRowY = rowCenters.first ?? 0.9
        let rowStep = max(0.001, deltaY)
        let numRows = max(1, Int(round((maxRowY - minRowY) / rowStep)) + 1)
        let regularRowCenters = (0..<numRows).map { maxRowY - CGFloat($0) * rowStep } // Descending from top

        var grid = [[Character]](repeating: [Character](repeating: "?", count: numCols), count: numRows)
        var bestConfidence = [[Float]](repeating: [Float](repeating: -1, count: numCols), count: numRows)

        for point in coreChars {
            guard let r = nearestIndex(point.center.y, in: regularRowCenters),
                  let c = nearestIndex(point.center.x, in: regularColCenters) else { continue }

            // Ensure the character sits reasonably close to the regular grid cell center
            let rowCenterY = regularRowCenters[r]
            let colCenterX = regularColCenters[c]
            guard abs(point.center.y - rowCenterY) <= rowStep * 0.6,
                  abs(point.center.x - colCenterX) <= colStep * 0.6 else {
                continue
            }

            if point.confidence >= bestConfidence[r][c] {
                grid[r][c] = point.char
                bestConfidence[r][c] = point.confidence
            }
        }

        return grid
    }

    /// Groups a set of 1D positions into clusters (within `tolerance` of a running
    /// cluster mean) and returns each cluster's mean. Used to infer the grid's
    /// actual row Y-positions and column X-positions directly from where letters
    /// were detected, instead of trusting any text-level line/row grouping.
    private static func clusterCenters(_ values: [CGFloat], tolerance: CGFloat) -> [CGFloat] {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return [] }

        var clusters = [[CGFloat]]()
        for value in sorted {
            if let last = clusters.last {
                let clusterMean = last.reduce(0, +) / CGFloat(last.count)
                if abs(value - clusterMean) <= tolerance {
                    clusters[clusters.count - 1].append(value)
                    continue
                }
            }
            clusters.append([value])
        }
        return clusters.map { $0.reduce(0, +) / CGFloat($0.count) }
    }

    private static func nearestIndex(_ value: CGFloat, in centers: [CGFloat]) -> Int? {
        guard !centers.isEmpty else { return nil }
        var bestIdx = 0
        var bestDist = abs(centers[0] - value)
        for i in 1..<centers.count {
            let d = abs(centers[i] - value)
            if d < bestDist {
                bestDist = d
                bestIdx = i
            }
        }
        return bestIdx
    }
}

// Extension to map UIImage orientation to CGImagePropertyOrientation
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
