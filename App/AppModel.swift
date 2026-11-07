import SwiftUI
import UIKit
import GameCore

enum Destination: Hashable { case home, game, levels, shop, daily, stats, settings }

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var snapshot = Snapshot()
    @Published var destination: Destination = .home
    @Published private(set) var busy = false
    @Published var paused = false
    @Published var message: String?
    @Published var selected: Int?
    @Published var selectedBooster: Booster?
    @Published var rainbowLetter = "A"
    @Published var hint: Swap?
    @Published private(set) var displayGame: Game?
    @Published private(set) var cleared: Set<Int> = []
    @Published private(set) var storageBlocked = false
    @Published var coachAcknowledged = false
    let ads = AdMobService()
    let audio = GameAudio()
    private let store: SnapshotStore
    private var active = true
    private var adWasPresenting = false
    private var clockAnchor = ProcessInfo.processInfo.systemUptime
    private var uiTesting: Bool { ProcessInfo.processInfo.arguments.contains("--uitesting") }
    var settings: Settings { snapshot.settings }
    var profile: Profile { snapshot.profile }
    var session: Session? { snapshot.session }
    var tutorialWaiting: Bool {
        guard let session, session.game.level.number <= 5 else { return false }
        return settings.tutorialStep < session.game.level.number && !coachAcknowledged
    }
    init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WordCrushMania", isDirectory: true)
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        store = SnapshotStore(url: root.appendingPathComponent(testing ? "ui-test-save.json" : "save.json"))
        if testing { snapshot = Snapshot() }
        else {
            do { snapshot = try store.load() }
            catch { storageBlocked = true; message = "Your save is preserved. Loading failed: \(error.localizedDescription)" }
        }
        displayGame = snapshot.session?.game
    }
    @discardableResult private func commit(_ candidate: Snapshot) -> Bool {
        guard !storageBlocked else { return false }
        do { try store.save(candidate); snapshot = candidate; return true }
        catch { message = "Progress could not be saved: \(error.localizedDescription)"; return false }
    }
    func recoverSave() {
        do {
            if FileManager.default.fileExists(atPath: store.url.path) {
                let backup = store.url.deletingPathExtension().appendingPathExtension("backup-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: store.url, to: backup)
            }
            try store.save(Snapshot()); snapshot = Snapshot(); storageBlocked = false; displayGame = nil; message = nil
        } catch { message = "The original save is preserved. Recovery failed: \(error.localizedDescription)" }
    }
    func sceneChanged(_ phase: ScenePhase) {
        tick(); active = phase == .active; clockAnchor = ProcessInfo.processInfo.systemUptime
        audio.update(settings, active: active && !ads.presenting)
        if active { Task { await ads.preload() } }
    }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = max(0, now - clockAnchor); clockAnchor = now
        guard active, destination == .game, !busy, !paused, !ads.presenting, !tutorialWaiting,
              message == nil, !storageBlocked, snapshot.session?.phase == .playing else { return }
        var next = snapshot; next.elapse(elapsed)
        if commit(next), next.session?.phase == .lost { audio.play("failure", settings: settings) }
    }
    func adPresentationChanged(_ presenting: Bool) {
        // Reset the monotonic anchor on both edges so the ad's duration is never charged.
        if !adWasPresenting && presenting { tick() }
        adWasPresenting = presenting
        clockAnchor = ProcessInfo.processInfo.systemUptime
        audio.update(settings, active: active && !presenting)
    }
    func navigate(_ destination: Destination) {
        guard !busy, !ads.presenting else { return }
        tick(); self.destination = destination; paused = false; selected = nil; selectedBooster = nil; hint = nil
        clockAnchor = ProcessInfo.processInfo.systemUptime
    }
    func togglePause() { tick(); paused.toggle(); clockAnchor = ProcessInfo.processInfo.systemUptime }
    func acknowledgeCoach() { coachAcknowledged = true; clockAnchor = ProcessInfo.processInfo.systemUptime }
    func start(_ number: Int? = nil, fresh: Bool = false) {
        guard !busy, !storageBlocked, !ads.presenting else { return }
        let number = number ?? profile.unlocked
        guard number <= profile.unlocked else { message = "Complete the previous level first."; return }
        if !fresh, let session, session.phase == .playing, session.game.level.number == number {
            displayGame = session.game; navigate(.game); return
        }
        guard profile.lives > 0 else { message = "No lives left. You can restore lives with a rewarded ad."; return }
        tick(); busy = true
        Task {
            defer { busy = false; clockAnchor = ProcessInfo.processInfo.systemUptime }
            do {
                var level = try await Task.detached(priority: .userInitiated) { try LevelGenerator().generate(number) }.value
                var next = snapshot
                if (number == 4 || number == 5), settings.tutorialStep < number {
                    level.board = level.board.map { Tile($0.letter, kind: .frozen, id: $0.id) }
                    let booster: Booster = number == 4 ? .hammer : .bomb
                    next.profile.inventory[booster] = max(1, next.profile.inventory[booster, default: 0])
                }
                next.session = Session(game: Game(level: level))
                if commit(next) {
                    displayGame = next.session?.game; destination = .game; paused = false
                    selected = nil; selectedBooster = nil; hint = nil; coachAcknowledged = false
                }
            } catch { message = error.localizedDescription }
        }
    }
    func tap(_ index: Int) {
        guard !busy, !paused, !ads.presenting, !tutorialWaiting, session?.phase == .playing,
              let game = session?.game else { return }
        if let booster = selectedBooster { applyBooster(booster, at: index); return }
        audio.selection(settings); audio.play("select", settings: settings)
        hint = nil
        guard let first = selected, first != index, MatchEngine().adjacent(first, index, size: game.level.size) else {
            selected = selected == index ? nil : index; return
        }
        selected = nil
        resolve { try MatchEngine().swap(game, Swap(first, index)) }
    }
    private func resolve(booster: Booster? = nil, calculation: @escaping @Sendable () throws -> Turn) {
        guard !busy else { return }
        tick(); busy = true
        Task {
            defer { busy = false; clockAnchor = ProcessInfo.processInfo.systemUptime }
            do {
                let turn = try await Task.detached(priority: .userInitiated) { try calculation() }.value
                if !turn.valid {
                    audio.play("failure", settings: settings)
                    message = booster == nil ? "That swap does not form a target word." : "Choose another tile. This action would not create a useful move."
                    return
                }
                var next = snapshot
                guard next.accept(turn, booster: booster, now: Date().timeIntervalSince1970), commit(next) else { return }
                selectedBooster = nil; hint = nil
                let reduce = UIAccessibility.isReduceMotionEnabled || !settings.motion
                if !reduce {
                    for frame in turn.frames {
                        displayGame = frame.game; cleared = frame.cleared
                        try? await Task.sleep(for: .milliseconds(frame.cleared.isEmpty ? 120 : 170))
                    }
                }
                displayGame = turn.game; cleared = []
                audio.play(turn.game.won ? "victory" : turn.game.combo > 1 ? "combo" : "word", settings: settings)
                if turn.game.won { ads.recordCompletion() }
            } catch { message = error.localizedDescription }
        }
    }
    func chooseBooster(_ booster: Booster) {
        guard !busy, !paused, !tutorialWaiting, session?.phase == .playing else { return }
        guard profile.inventory[booster, default: 0] > 0 else { message = "You can get more boosters in the Booster Vault."; return }
        selected = nil; hint = nil
        if booster == .lightning { showHint(consume: true); return }
        selectedBooster = selectedBooster == booster ? nil : booster
    }
    private func applyBooster(_ booster: Booster, at index: Int) {
        guard let game = session?.game else { return }
        let letter = rainbowLetter
        resolve(booster: booster) { try MatchEngine().booster(game, type: booster, index: index, letter: letter) }
    }
    func showHint(consume: Bool = false) {
        guard !busy, session?.phase == .playing, let game = session?.game else { return }
        tick(); busy = true
        Task {
            defer { busy = false; clockAnchor = ProcessInfo.processInfo.systemUptime }
            let move = await Task.detached { MatchEngine().legalMoves(game).first }.value
            guard let move else { message = "Try a booster to open the frozen tiles."; return }
            if consume {
                var next = snapshot
                guard next.profile.consume(.lightning), commit(next) else { return }
            }
            selectedBooster = nil; hint = move
        }
    }
    func shuffle() {
        guard !busy, !tutorialWaiting, session?.phase == .playing, let game = session?.game else { return }
        resolve { Turn(try MatchEngine().reshuffle(game), valid: true) }
    }
    func changeSettings(_ transform: (inout Settings) -> Void) {
        var next = snapshot; transform(&next.settings)
        if commit(next) { audio.update(settings, active: active && !ads.presenting) }
    }
    func buy(_ booster: Booster) {
        var next = snapshot
        if next.profile.buy(booster) { _ = commit(next) }
        else { message = "You need 75 coins." }
    }
    func claimDaily() {
        var next = snapshot; let amount = next.profile.claimDaily(now: Date().timeIntervalSince1970)
        if commit(next) { message = amount > 0 ? "You received \(amount) coins!" : "Come back tomorrow for your next reward." }
    }
    func claimChallenge() {
        var next = snapshot; next.profile.updateDay(now: Date().timeIntervalSince1970)
        if next.profile.claimChallenge() { _ = commit(next) }
    }
    func claimAchievement(_ index: Int) {
        var next = snapshot
        if next.profile.claimAchievement(index) { _ = commit(next) }
    }
    func refreshDaily() {
        var next = snapshot; next.profile.updateDay(now: Date().timeIntervalSince1970)
        if next != snapshot { _ = commit(next) }
    }
    func rewarded(_ reward: AdReward) {
        guard !busy, !storageBlocked else { return }
        let id = session?.id
        if !ads.showRewarded(grant: { [weak self] token in
            guard let self else { return }
            var next = self.snapshot
            if next.grant(reward, token: token, sessionID: id) { _ = self.commit(next) }
        }) { message = "No rewarded ad is available right now. Please try again later." }
    }
    func nextLevel() {
        guard let session, !busy, !ads.presenting else { return }
        let number = session.game.level.number
        ads.transition(after: number) { [weak self] in
            self?.start(min(10_000, number + 1), fresh: true)
        }
    }
}
