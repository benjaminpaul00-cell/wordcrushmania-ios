import Foundation

public struct LevelGenerator: Sendable {
    public static let version = 1
    public init() {}
    public func generate(_ number: Int) throws -> Level {
        guard (1...10_000).contains(number) else { throw GameError.invalidLevel }
        let rank = number <= 100 ? 0 : number <= 1000 ? 1 : number <= 2500 ? 2 : number <= 5000 ? 3 : 4
        let size = rank == 0 ? 6 : rank == 1 ? 7 : rank == 2 ? 8 : number.isMultiple(of: 2) ? 9 : 8
        let seed = UInt64(0x57434D000 + number * 104729)
        var random = SeededRandom(seed: seed)
        var pool = Vocabulary.words(theme: (number - 1) % 10, size: size)
        if number == 4 { pool = pool.filter { $0.count >= 4 } }
        guard pool.count >= 3 else { throw GameError.generationFailed }
        var targets = Array(random.shuffled(pool).prefix(3))
        if number == 5, !targets.contains(where: { $0.count == 3 }), let short = pool.first(where: { $0.count == 3 }) {
            targets[0] = short
        }
        var level = Level(number: number, size: size, rank: rank, seed: seed, targets: targets, board: [],
                          goldGoal: number % 50 == 0 ? 2 : number % 10 == 0 ? 1 : 0)
        level.board = try MatchEngine().openingBoard(level)
        return level
    }
    /// Executes the engine, including gravity, refill and recovery. Not a difficulty metric.
    public func validate(_ level: Level) throws -> Bool {
        let engine = MatchEngine()
        var game = Game(level: level)
        guard engine.matches(game).isEmpty else { return false }
        for _ in 0..<16 {
            if game.won { return true }
            if engine.legalMoves(game).isEmpty { game = try engine.reshuffle(game) }
            let turns = try engine.legalMoves(game).map { try engine.swap(game, $0) }.filter(\.valid)
            guard let best = turns.max(by: {
                let a = min($0.game.gold, level.goldGoal) * 10_000 + $0.game.used.count * 1000 + $0.game.score
                let b = min($1.game.gold, level.goldGoal) * 10_000 + $1.game.used.count * 1000 + $1.game.score
                return a < b
            }) else { return false }
            game = best.game
        }
        return game.won
    }
}
