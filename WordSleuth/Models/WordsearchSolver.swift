import Foundation

public class WordsearchSolver {
    // 8 directions for searching: Right, Left, Down, Up, Down-Right, Up-Left, Down-Left, Up-Right
    private static let directions = [
        (0, 1),    // Right
        (0, -1),   // Left
        (1, 0),    // Down
        (-1, 0),   // Up
        (1, 1),    // Down-Right
        (-1, -1),  // Up-Left
        (1, -1),   // Down-Left
        (-1, 1)    // Up-Right
    ]
    
    /// Solves the wordsearch grid for a list of words.
    /// - Parameters:
    ///   - grid: A 2D array of Characters.
    ///   - words: An array of target words to find.
    /// - Returns: A dictionary mapping each found uppercase word to its WordPlacement.
    public static func solve(grid: [[Character]], words: [String]) -> [String: WordPlacement] {
        var solutions = [String: WordPlacement]()
        let numRows = grid.count
        guard numRows > 0 else { return solutions }
        let numCols = grid[0].count
        guard numCols > 0 else { return solutions }
        
        // Clean words: uppercase, remove spaces, keep only alphanumeric
        let cleanedWords = words.map { (original: $0, cleaned: $0.uppercased().replacingOccurrences(of: " ", with: "")) }
        
        // Create an uppercase copy of the grid for case-insensitive matching
        let upperGrid = grid.map { $0.map { Character($0.uppercased()) } }
        
        for wordItem in cleanedWords {
            let target = wordItem.cleaned
            guard !target.isEmpty else { continue }
            
            if let placement = findWord(target, in: upperGrid, numRows: numRows, numCols: numCols) {
                // Map the solution back to the original word string from input
                solutions[wordItem.original] = placement
            }
        }
        
        return solutions
    }
    
    private static func findWord(_ word: String, in grid: [[Character]], numRows: Int, numCols: Int) -> WordPlacement? {
        let chars = Array(word)
        let firstChar = chars[0]
        
        for r in 0..<numRows {
            for c in 0..<numCols {
                if grid[r][c] == firstChar {
                    for dir in directions {
                        if let path = checkDirection(chars: chars, from: Coordinate(row: r, col: c), direction: dir, in: grid, numRows: numRows, numCols: numCols) {
                            return WordPlacement(
                                word: word,
                                start: Coordinate(row: r, col: c),
                                end: path.last!,
                                path: path
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private static func checkDirection(chars: [Character], from start: Coordinate, direction: (Int, Int), in grid: [[Character]], numRows: Int, numCols: Int) -> [Coordinate]? {
        var path = [Coordinate]()
        var currRow = start.row
        var currCol = start.col
        
        for i in 0..<chars.count {
            guard currRow >= 0 && currRow < numRows && currCol >= 0 && currCol < numCols else {
                return nil
            }
            guard currCol < grid[currRow].count else { return nil }
            if grid[currRow][currCol] != chars[i] {
                return nil
            }
            path.append(Coordinate(row: currRow, col: currCol))
            currRow += direction.0
            currCol += direction.1
        }
        return path
    }
}
