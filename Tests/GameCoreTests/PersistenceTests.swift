import XCTest
@testable import GameCore

final class PersistenceTests: XCTestCase {
    func testSettingsAndRemainingTimeSurviveDiskRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore(url: directory.appendingPathComponent("save.json"))
        var snapshot = Snapshot()
        snapshot.settings.sound = false; snapshot.settings.haptics = false; snapshot.settings.motion = false
        snapshot.session = Session(game: Game(level: try LevelGenerator().generate(1)))
        snapshot.elapse(12.75)
        try store.save(snapshot)
        let restored = try store.load()
        XCTAssertEqual(restored, snapshot)
        XCTAssertEqual(restored.session?.remaining, 17.25)
        XCTAssertFalse(restored.settings.sound)
        XCTAssertFalse(restored.settings.haptics)
        XCTAssertFalse(restored.settings.motion)
    }
    func testTimeoutCostsExactlyOneLife() throws {
        var snapshot = Snapshot(); snapshot.session = Session(game: Game(level: try LevelGenerator().generate(1)))
        snapshot.elapse(31); snapshot.elapse(31)
        XCTAssertEqual(snapshot.profile.lives, 4); XCTAssertEqual(snapshot.profile.failed, 1)
        XCTAssertEqual(snapshot.session?.phase, .lost)
    }
    func testRewardCallbacksAreIdempotentAndBoundToTheCorrectWin() throws {
        var snapshot = Snapshot()
        XCTAssertTrue(snapshot.grant(.coins, token: "same-impression"))
        XCTAssertFalse(snapshot.grant(.coins, token: "same-impression"))
        XCTAssertEqual(snapshot.profile.coins, 150)
        XCTAssertFalse(snapshot.grant(.doubleCoins, token: "wrong-session", sessionID: UUID()))
        snapshot.session = Session(game: Game(level: try LevelGenerator().generate(1)))
        snapshot.session?.phase = .won; snapshot.session?.rewardCoins = 30
        let id = snapshot.session?.id
        XCTAssertFalse(snapshot.grant(.doubleCoins, token: "wrong-id", sessionID: UUID()))
        XCTAssertTrue(snapshot.grant(.doubleCoins, token: "double", sessionID: id))
        XCTAssertFalse(snapshot.grant(.doubleCoins, token: "another", sessionID: id))
        XCTAssertEqual(snapshot.profile.coins, 180)
    }
    func testDailyRewardRejectsDuplicateAndClockRollback() {
        var profile = Profile()
        XCTAssertEqual(profile.claimDaily(now: 10*86_400), 50)
        XCTAssertEqual(profile.claimDaily(now: 10*86_400+1), 0)
        XCTAssertEqual(profile.claimDaily(now: 9*86_400), 0)
        XCTAssertEqual(profile.claimDaily(now: 11*86_400), 75)
    }
    func testInventoryCannotOverspendAndRejectedTurnIsFree() throws {
        var snapshot = Snapshot(); let game = Game(level: try LevelGenerator().generate(1))
        snapshot.session = Session(game: game)
        let original = snapshot
        XCTAssertFalse(snapshot.accept(Turn(game, valid: false), booster: .bomb, now: 0))
        XCTAssertEqual(snapshot, original)
        XCTAssertTrue(snapshot.profile.buy(.hammer))
        XCTAssertFalse(snapshot.profile.buy(.hammer))
        XCTAssertEqual(snapshot.profile.coins, 25)
    }
    func testCorruptSaveIsNotOverwrittenAndUnsupportedSchemaIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("save.json")
        let data = Data("{broken".utf8); try data.write(to: url)
        XCTAssertThrowsError(try SnapshotStore(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), data)
        var snapshot = Snapshot(); snapshot.schema = 99
        XCTAssertThrowsError(try snapshot.validate())
    }
    func testLevelCompletionCanOnlyRewardTheAttemptOnce() throws {
        var snapshot = Snapshot()
        var game = Game(level: try LevelGenerator().generate(1))
        snapshot.session = Session(game: game)
        let engine = MatchEngine()
        for _ in 0..<16 where !game.won {
            guard let move = engine.legalMoves(game).first else { XCTFail("No legal move"); return }
            let turn = try engine.swap(game, move)
            XCTAssertTrue(snapshot.accept(turn, now: 1_000_000))
            game = turn.game
        }
        XCTAssertTrue(game.won)
        let coins = snapshot.profile.coins
        XCTAssertFalse(snapshot.accept(Turn(game, valid: true), now: 1_000_000))
        XCTAssertEqual(snapshot.profile.coins, coins); XCTAssertEqual(snapshot.profile.completions, 1)
    }
}
