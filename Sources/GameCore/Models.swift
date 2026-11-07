import Foundation

public enum TileKind: String, Codable, Sendable, CaseIterable {
    case normal, gold, frozen, locked, bomb, rainbow, special
    public var blocked: Bool { self == .frozen || self == .locked }
}

public enum Booster: String, Codable, Sendable, CaseIterable, Identifiable {
    case hammer, bomb, lightning, rainbow
    public var id: String { rawValue }
}

public struct Tile: Codable, Equatable, Sendable, Identifiable {
    public var letter: String
    public var kind: TileKind
    public var id: Int
    public init(_ letter: String, kind: TileKind = .normal, id: Int) {
        self.letter = letter; self.kind = kind; self.id = id
    }
}

public struct Level: Codable, Equatable, Sendable {
    public var number: Int
    public var size: Int
    public var rank: Int
    public var seed: UInt64
    public var targets: [String]
    public var board: [Tile]
    public var scoreGoal: Int
    public var goldGoal: Int
    public var reward: Int
    public var theme: Int { (number - 1) % 10 }
    public var world: Int { (number - 1) / 100 + 1 }
    public init(number: Int, size: Int, rank: Int = 0, seed: UInt64 = 1,
                targets: [String], board: [Tile], scoreGoal: Int? = nil, goldGoal: Int = 0) {
        self.number = number; self.size = size; self.rank = rank; self.seed = seed
        self.targets = targets; self.board = board; self.scoreGoal = scoreGoal ?? targets.count * 60
        self.goldGoal = goldGoal; self.reward = 30 + rank * 20 + (number % 50 == 0 ? 100 : 0)
    }
}

public struct Game: Codable, Equatable, Sendable {
    public var level: Level
    public var board: [Tile]
    public var used: Set<String> = []
    public var score = 0
    public var movesUsed = 0
    public var gold = 0
    public var combo = 0
    public var refill = 0
    public var nextID = 1000
    public var revision = 0
    public init(level: Level) { self.level = level; board = level.board }
    public var won: Bool {
        Set(level.targets).isSubset(of: used) && score >= level.scoreGoal && gold >= level.goldGoal
    }
}

public struct Swap: Codable, Equatable, Hashable, Sendable {
    public let first: Int
    public let second: Int
    public init(_ first: Int, _ second: Int) { self.first = first; self.second = second }
}

public struct WordMatch: Equatable, Sendable {
    public let word: String
    public let cells: [Int]
}

public struct MatchFrame: Sendable {
    public var game: Game
    public var cleared: Set<Int>
    public var chain: Int
}

public struct Turn: Sendable {
    public var game: Game
    public var valid: Bool
    public var frames: [MatchFrame] = []
    public init(_ game: Game, valid: Bool, frames: [MatchFrame] = []) {
        self.game = game; self.valid = valid; self.frames = frames
    }
}

public enum GameError: Error, LocalizedError {
    case invalidLevel, generationFailed, invalidSave, unsupportedSave
    public var errorDescription: String? {
        switch self {
        case .invalidLevel: return "The level number is outside the campaign."
        case .generationFailed: return "This board could not be prepared. Please try again."
        case .invalidSave: return "The saved progress could not be read."
        case .unsupportedSave: return "This save needs a newer version of the app."
        }
    }
}

/// Versioned iOS generator. Deliberately independent of Kotlin Random.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
    public mutating func index(_ count: Int) -> Int {
        precondition(count > 0)
        return Int(next() % UInt64(count))
    }
    public mutating func shuffled<T>(_ values: [T]) -> [T] {
        var result = values
        if result.count > 1 {
            for index in stride(from: result.count - 1, through: 1, by: -1) {
                result.swapAt(index, self.index(index + 1))
            }
        }
        return result
    }
}
