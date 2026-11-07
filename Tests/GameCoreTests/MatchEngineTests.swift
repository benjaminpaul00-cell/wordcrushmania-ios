import XCTest
@testable import GameCore

final class MatchEngineTests: XCTestCase {
    private let engine = MatchEngine()
    private func fixture(vertical: Bool = false, reversed: Bool = false) -> Game {
        let n = 6
        var board = (0..<n*n).map { Tile("Z", id: $0) }
        let word = Array(reversed ? "TAC" : "CAT").map(String.init)
        let path = [0, vertical ? n : 1, vertical ? n*2 : 2]
        for (index, cell) in path.enumerated() { board[cell].letter = index == 2 ? "X" : word[index] }
        let donor = vertical ? n*2+1 : n+2
        board[donor].letter = word[2]
        return Game(level: Level(number: 1, size: n, targets: ["CAT", "DOG", "OWL"], board: board))
    }
    func testHorizontalVerticalAndReverseMatches() throws {
        for vertical in [false, true] { for reversed in [false, true] {
            let game = fixture(vertical: vertical, reversed: reversed)
            let turn = try engine.swap(game, vertical ? Swap(12, 13) : Swap(2, 8))
            XCTAssertTrue(turn.valid); XCTAssertTrue(turn.game.used.contains("CAT"))
            XCTAssertEqual(turn.game.movesUsed, 1)
            XCTAssertGreaterThanOrEqual(turn.game.score, 66)
        } }
    }
    func testInvalidDiagonalAndWrappedSwapsAreExactNoOps() throws {
        let game = fixture()
        for move in [Swap(0, 7), Swap(5, 6), Swap(-1, 0), Swap(35, 36), Swap(0, 1)] {
            let turn = try engine.swap(game, move)
            XCTAssertFalse(turn.valid); XCTAssertEqual(turn.game, game)
        }
    }
    func testOnlyTargetsCountAndUsedWordsCannotScoreAgain() throws {
        var game = fixture()
        game.level.targets = ["DOG", "OWL", "FOX"]
        XCTAssertFalse(try engine.swap(game, Swap(2, 8)).valid)
        game = fixture(); game.used = ["CAT"]
        XCTAssertFalse(try engine.swap(game, Swap(2, 8)).valid)
    }
    func testBlockedTilesCannotBeSwappedAndIDsStayUniqueAfterGravity() throws {
        var game = fixture(); game.board[2].kind = .locked
        XCTAssertFalse(try engine.swap(game, Swap(2, 8)).valid)
        game = fixture(); let turn = try engine.swap(game, Swap(2, 8))
        XCTAssertEqual(Set(turn.game.board.map(\.id)).count, 36)
        XCTAssertLessThanOrEqual(turn.frames.count, MatchEngine.maximumCascades*2+1)
    }
    func testGuidedBoostersProduceARealMove() throws {
        for (number, booster) in [(4, Booster.hammer), (5, Booster.bomb)] {
            var game = Game(level: try LevelGenerator().generate(number))
            game.board = game.board.map { Tile($0.letter, kind: .frozen, id: $0.id) }
            let turn = try engine.booster(game, type: booster, index: 14)
            XCTAssertTrue(turn.valid); XCTAssertFalse(engine.legalMoves(turn.game).isEmpty)
            XCTAssertTrue(engine.matches(turn.game).isEmpty)
            if booster == .bomb {
                let n = game.level.size, center = 14
                for cell in game.board.indices where abs(cell/n-center/n) > 1 || abs(cell%n-center%n) > 1 {
                    XCTAssertEqual(turn.game.board[cell].kind, .frozen)
                }
            }
        }
    }
    func testDeterministicBoardsAtEveryDifficultyBoundary() throws {
        let generator = LevelGenerator()
        for number in [1, 4, 5, 10, 50, 100, 101, 1000, 1001, 2500, 2501, 5000, 5001, 9999, 10000] {
            let level = try generator.generate(number)
            XCTAssertEqual(level, try generator.generate(number))
            XCTAssertTrue(try generator.validate(level), "Level \(number)")
            XCTAssertEqual(level.targets.count, 3)
            XCTAssertTrue(level.targets.allSatisfy { Vocabulary.words(theme: level.theme, size: level.size).contains($0) })
        }
    }
    func testEntireCampaignWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["WCM_VALIDATE_CAMPAIGN"] == "1" else {
            throw XCTSkip("Full 10,000-level validation is a separate release gate.")
        }
        let generator = LevelGenerator()
        for number in 1...10_000 {
            XCTAssertTrue(try generator.validate(generator.generate(number)), "Level \(number)")
        }
    }
}
