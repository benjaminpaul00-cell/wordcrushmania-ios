import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var music = true
    public var sound = true
    public var haptics = true
    public var motion = true
    public var musicVolume: Float = 0.18
    public var effectsVolume: Float = 0.55
    public var tutorialStep = 0
    public init() {}
}

public enum SessionPhase: String, Codable, Sendable { case playing, won, lost }
public struct Session: Codable, Equatable, Sendable {
    public var id: UUID
    public var game: Game
    public var remaining: Double = 30
    public var phase: SessionPhase = .playing
    public var rewardCoins = 0
    public var doubled = false
    public init(game: Game, id: UUID = UUID()) { self.game = game; self.id = id }
    public mutating func elapse(_ seconds: Double) {
        guard phase == .playing, seconds.isFinite, seconds > 0 else { return }
        remaining = max(0, remaining - seconds)
        if remaining == 0 { phase = .lost }
    }
}

public struct Profile: Codable, Equatable, Sendable {
    public var coins = 100
    public var lives = 5
    public var inventory: [Booster: Int] = Dictionary(uniqueKeysWithValues: Booster.allCases.map { ($0, 2) })
    public var unlocked = 1
    public var words = 0
    public var completions = 0
    public var combos = 0
    public var gold = 0
    public var failed = 0
    public var best = 0
    public var completed: [Int: Int] = [:]
    public var rewardDay = -1
    public var challengeDay = -1
    public var dayWords = 0
    public var dayLevels = 0
    public var dayCombos = 0
    public var dayGold = 0
    public var challengeClaimed = false
    public var streak = 0
    public var highTime: TimeInterval = 0
    public var receipts: Set<String> = []
    public var achievements: Set<Int> = []
    public init() {}
    public mutating func updateDay(now: TimeInterval) {
        highTime = max(highTime, now)
        let day = Int(highTime / 86_400)
        if day != challengeDay {
            challengeDay = day; dayWords = 0; dayLevels = 0; dayCombos = 0; dayGold = 0; challengeClaimed = false
        }
    }
    @discardableResult public mutating func claimDaily(now: TimeInterval) -> Int {
        updateDay(now: now)
        let day = Int(highTime / 86_400)
        guard day > rewardDay else { return 0 }
        streak = rewardDay == day - 1 ? streak + 1 : 1
        rewardDay = day
        let amount = 50 + ((streak - 1) % 7) * 25
        coins += amount; return amount
    }
    public mutating func buy(_ booster: Booster) -> Bool {
        guard coins >= 75 else { return false }
        coins -= 75; inventory[booster, default: 0] += 1; return true
    }
    public mutating func consume(_ booster: Booster) -> Bool {
        guard inventory[booster, default: 0] > 0 else { return false }
        inventory[booster, default: 0] -= 1; return true
    }
    public var challengeIndex: Int { max(0, challengeDay) % 4 }
    public var challengeGoal: Int { [20, 3, 5, 50][challengeIndex] }
    public var challengeProgress: Int { [dayWords, dayLevels, dayCombos, dayGold][challengeIndex] }
    public mutating func claimChallenge() -> Bool {
        guard !challengeClaimed, challengeProgress >= challengeGoal else { return false }
        challengeClaimed = true; coins += 150; return true
    }
    public func achievementProgress(_ index: Int) -> Int { [words, completions, combos, gold][index] }
    public func achievementGoal(_ index: Int) -> Int { [50, 10, 25, 100][index] }
    public mutating func claimAchievement(_ index: Int) -> Bool {
        guard (0..<4).contains(index), !achievements.contains(index), achievementProgress(index) >= achievementGoal(index) else { return false }
        achievements.insert(index); coins += 100; return true
    }
}

public enum AdReward: String, Sendable { case lives, coins, booster, doubleCoins }
public struct Snapshot: Codable, Equatable, Sendable {
    public var schema = 1
    public var generatorVersion = LevelGenerator.version
    public var profile = Profile()
    public var settings = Settings()
    public var session: Session?
    public init() {}

    /// A single snapshot commit contains both the inventory debit and board mutation.
    public mutating func accept(_ turn: Turn, booster: Booster? = nil, now: TimeInterval) -> Bool {
        guard turn.valid, var session, session.phase == .playing,
              turn.game.level == session.game.level else { return false }
        if let booster, !profile.consume(booster) { return false }
        profile.updateDay(now: now)
        let newWords = turn.game.used.subtracting(session.game.used).count
        let combos = turn.frames.filter { $0.chain >= 2 && !$0.cleared.isEmpty }.count
        let gold = max(0, turn.game.gold - session.game.gold)
        profile.words += newWords; profile.dayWords += newWords
        profile.combos += combos; profile.dayCombos += combos
        profile.gold += gold; profile.dayGold += gold
        session.game = turn.game
        if turn.game.won {
            session.phase = .won
            let receipt = "finish:" + session.id.uuidString
            if profile.receipts.insert(receipt).inserted {
                let level = turn.game.level.number
                let reward = profile.completed[level] == nil ? turn.game.level.reward : 10
                session.rewardCoins = reward; profile.coins += reward
                profile.completed[level] = max(profile.completed[level, default: 0], turn.game.score)
                profile.unlocked = max(profile.unlocked, min(10_000, level + 1))
                profile.completions += 1; profile.dayLevels += 1
                profile.best = max(profile.best, turn.game.score)
            }
            settings.tutorialStep = max(settings.tutorialStep, min(5, turn.game.level.number))
        }
        self.session = session
        return true
    }
    public mutating func elapse(_ seconds: Double) {
        guard var session, session.phase == .playing else { return }
        session.elapse(seconds)
        if session.phase == .lost {
            profile.lives = max(0, profile.lives - 1); profile.failed += 1
        }
        self.session = session
    }
    @discardableResult public mutating func grant(_ reward: AdReward, token: String, sessionID: UUID? = nil) -> Bool {
        guard !token.isEmpty, !profile.receipts.contains("ad:" + token) else { return false }
        if reward == .doubleCoins {
            guard var session, session.id == sessionID, session.phase == .won, !session.doubled else { return false }
            profile.coins += session.rewardCoins; session.doubled = true; self.session = session
        } else {
            switch reward {
            case .lives: profile.lives = 5
            case .coins: profile.coins += 50
            case .booster: profile.inventory[.hammer, default: 0] += 1
            case .doubleCoins: break
            }
        }
        profile.receipts.insert("ad:" + token); return true
    }
    public func validate() throws {
        guard schema == 1, generatorVersion == LevelGenerator.version else { throw GameError.unsupportedSave }
        guard profile.coins >= 0, (0...5).contains(profile.lives), (1...10_000).contains(profile.unlocked),
              Booster.allCases.allSatisfy({ (0...1_000_000).contains(profile.inventory[$0, default: 0]) }),
              (0...5).contains(settings.tutorialStep), settings.musicVolume.isFinite,
              settings.effectsVolume.isFinite else { throw GameError.invalidSave }
        if let session {
            let game = session.game, n = game.level.size
            guard (6...9).contains(n), game.board.count == n*n, game.level.board.count == n*n,
                  Set(game.board.map(\.id)).count == n*n, game.nextID > (game.board.map(\.id).max() ?? 0),
                  (1...10_000).contains(game.level.number), game.level.targets.count == 3,
                  Set(game.level.targets).count == 3, game.used.isSubset(of: Set(game.level.targets)),
                  game.score >= 0, game.movesUsed >= 0, game.revision >= 0, game.refill >= 0,
                  session.remaining.isFinite, (0...30).contains(session.remaining),
                  game.board.allSatisfy({ $0.letter.count == 1 && $0.letter.utf8.allSatisfy { (65...90).contains($0) } }) else { throw GameError.invalidSave }
        }
    }
}

public struct SnapshotStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: url.path) else { return Snapshot() }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        try snapshot.validate(); return snapshot
    }
    public func save(_ snapshot: Snapshot) throws {
        try snapshot.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: [.atomic])
    }
}
