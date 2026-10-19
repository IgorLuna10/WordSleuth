import Foundation

public struct Coordinate: Codable, Hashable, Equatable {
    public let row: Int
    public let col: Int
    
    public init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }
}

public struct WordPlacement: Codable, Hashable {
    public let word: String
    public let start: Coordinate
    public let end: Coordinate
    public let path: [Coordinate]
    
    public init(word: String, start: Coordinate, end: Coordinate, path: [Coordinate]) {
        self.word = word
        self.start = start
        self.end = end
        self.path = path
    }
}
