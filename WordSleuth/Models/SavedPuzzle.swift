import Foundation

public struct SavedPuzzle: Identifiable, Codable {
    public let id: UUID
    public let grid: [[String]]
    public let words: [String]
    public let date: Date
}
