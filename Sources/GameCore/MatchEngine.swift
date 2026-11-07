import Foundation

public struct MatchEngine: Sendable {
    public static let maximumCascades = 12
    private let alphabet = Array("AAAAAAAEEEEEEEEEEEEIIIIIIIIOOOOOOOONNNNNRRRRRRSSSSSSTTTTTLLLLUUUUDDDCCMMMBBFFGGHHPPWWYYVKJXZ").map(String.init)
    public init() {}

    public func adjacent(_ a: Int, _ b: Int, size: Int) -> Bool {
        a >= 0 && b >= 0 && a < size * size && b < size * size &&
        ((a / size == b / size && abs(a - b) == 1) || (a % size == b % size && abs(a - b) == size))
    }

    public func matches(_ game: Game, around pivots: Set<Int>? = nil) -> [WordMatch] {
        let size = game.level.size, targets = Set(game.level.targets)
        var found: [WordMatch] = []
        var keys: Set<String> = []
        for vertical in [false, true] {
            let lines = pivots.map { Set($0.map { vertical ? $0 % size : $0 / size }).sorted() } ?? Array(0..<size)
            for line in lines {
                for start in 0..<size {
                    var cells: [Int] = [], word = ""
                    for offset in start..<size {
                        let index = vertical ? offset * size + line : line * size + offset
                        if game.board[index].kind.blocked { break }
                        cells.append(index); word += game.board[index].letter
                        guard cells.count >= 3 else { continue }
                        if let pivots, pivots.isDisjoint(with: cells) { continue }
                        for (candidate, path) in [(word, cells), (String(word.reversed()), Array(cells.reversed()))] {
                            let key = candidate + ":" + cells.map(String.init).joined(separator: ",")
                            if targets.contains(candidate), keys.insert(key).inserted {
                                found.append(WordMatch(word: candidate, cells: path))
                            }
                        }
                    }
                }
            }
        }
        return found.sorted { $0.cells.count == $1.cells.count ? $0.word < $1.word : $0.cells.count > $1.cells.count }
    }

    public func legalMoves(_ game: Game) -> [Swap] {
        guard !game.won else { return [] }
        let n = game.level.size
        var result: [Swap] = []
        for a in game.board.indices where !game.board[a].kind.blocked {
            for b in [a + 1, a + n] where adjacent(a, b, size: n) && !game.board[b].kind.blocked {
                var trial = game; trial.board.swapAt(a, b)
                if matches(trial, around: [a, b]).contains(where: { !game.used.contains($0.word) }) {
                    result.append(Swap(a, b))
                }
            }
        }
        return result
    }

    public func swap(_ game: Game, _ move: Swap) throws -> Turn {
        guard !game.won, adjacent(move.first, move.second, size: game.level.size),
              !game.board[move.first].kind.blocked, !game.board[move.second].kind.blocked else { return Turn(game, valid: false) }
        var state = game
        state.board.swapAt(move.first, move.second); state.revision += 1
        var current = matches(state, around: [move.first, move.second]).filter { !game.used.contains($0.word) }
        guard !current.isEmpty else {
            return Turn(game, valid: false, frames: [MatchFrame(game: state, cleared: [], chain: 0), MatchFrame(game: game, cleared: [], chain: 0)])
        }
        state.movesUsed += 1
        var frames: [MatchFrame] = []
        for chain in 1...Self.maximumCascades {
            var counted = state.used
            for match in current where counted.insert(match.word).inserted {
                state.score += match.word.count * 22 * chain + max(0, match.word.count - 3) * 18
            }
            state.used = counted; state.combo = chain
            let cleared = expandSpecials(state, initial: Set(current.flatMap(\.cells)))
            state.gold += cleared.filter { state.board[$0].kind == .gold }.count
            frames.append(MatchFrame(game: state, cleared: cleared, chain: chain))
            let longest = current.first!
            state = collapse(state, cleared: cleared)
            let special: TileKind? = longest.cells.count >= 6 ? .rainbow : longest.cells.count >= 5 ? .bomb : longest.cells.count >= 4 ? .special : nil
            if let special { state.board[longest.cells[0]].kind = special }
            frames.append(MatchFrame(game: state, cleared: [], chain: chain))
            if state.won { break }
            current = matches(state)
            if current.isEmpty { break }
        }
        if !state.won && (!matches(state).isEmpty || legalMoves(state).isEmpty) {
            state = try reshuffle(state)
            frames.append(MatchFrame(game: state, cleared: [], chain: state.combo))
        }
        return Turn(state, valid: true, frames: frames)
    }

    public func reshuffle(_ game: Game) throws -> Game {
        guard !game.won else { return game }
        var next = game
        next.board = try openingBoard(game.level, excluding: game.used, offset: UInt64(game.refill + game.revision + 1))
        for index in next.board.indices { next.board[index].id = next.nextID; next.nextID += 1 }
        next.revision += 1; next.refill += 1
        return next
    }

    /// Every remaining target gets a non-overlapping broken word and an adjacent donor.
    /// Attempts are bounded, validated with the actual scanner, and failure is recoverable.
    public func openingBoard(_ level: Level, excluding used: Set<String> = [], offset: UInt64 = 0) throws -> [Tile] {
        let n = level.size
        let targets = level.targets.filter { !used.contains($0) }
        guard !targets.isEmpty, targets.count <= 3, targets.allSatisfy({ (3...n).contains($0.count) }) else { throw GameError.generationFailed }
        var random = SeededRandom(seed: level.seed &+ offset)
        for _ in 0..<180 {
            var board = (0..<n*n).map { Tile(alphabet[random.index(alphabet.count)], id: $0) }
            var protected: Set<Int> = [], expected: [String: Swap] = [:]
            let vertical = random.index(2) == 0
            let bands = random.shuffled(Array(0..<3))
            for (position, word) in targets.enumerated() {
                let line = bands[position] * 2
                let letters = word.map(String.init)
                let start = random.index(n - letters.count + 1)
                let gap = random.index(letters.count)
                let path = letters.indices.map { vertical ? (start + $0) * n + line : line * n + start + $0 }
                let donor = vertical ? path[gap] + 1 : path[gap] + n
                for (i, cell) in path.enumerated() {
                    let letter = i == gap ? "ZQX".map(String.init).first(where: { $0 != letters[i] })! : letters[i]
                    board[cell] = Tile(letter, id: cell)
                }
                for cell in path.enumerated().filter({ $0.offset != gap }).map(\.element).prefix(min(2, level.goldGoal)) {
                    board[cell].kind = .gold
                }
                board[donor] = Tile(letters[gap], kind: level.rank > 0 && level.number % 3 != 0 ? .bomb : .normal, id: donor)
                protected.formUnion(path + [donor]); expected[word] = Swap(path[gap], donor)
            }
            for index in board.indices where !protected.contains(index) {
                if level.rank >= 3 && random.index(26) == 0 { board[index].kind = .locked }
                else if level.rank >= 2 && random.index(20) == 0 { board[index].kind = .frozen }
            }
            var game = Game(level: level); game.board = board; game.used = used
            guard matches(game).isEmpty else { continue }
            let verified = expected.allSatisfy { word, move in
                var trial = game; trial.board.swapAt(move.first, move.second)
                return matches(trial, around: [move.first, move.second]).contains { $0.word == word }
            }
            if verified { return board }
        }
        throw GameError.generationFailed
    }

    public func booster(_ game: Game, type: Booster, index: Int, letter: String = "A") throws -> Turn {
        guard !game.won, game.board.indices.contains(index), type != .lightning else { return Turn(game, valid: false) }
        let n = game.level.size
        var next = game
        if game.board.allSatisfy({ $0.kind == .frozen }) && (type == .hammer || type == .bomb) {
            if type == .hammer {
                // The tutorial's all-ice board needs recovery after the first crack.
                next = try reshuffle(game)
            } else {
                guard let opened = guidedBomb(game, at: index) else { return Turn(game, valid: false) }
                next = opened
            }
        } else {
            let before = reachable(game)
            switch type {
            case .hammer:
                if game.board[index].kind.blocked {
                    for cell in game.board.indices where cell == index || adjacent(index, cell, size: n) {
                        if next.board[cell].kind.blocked { next.board[cell].kind = .normal }
                    }
                } else {
                    let letters = Array(Set(game.level.targets.flatMap { $0.map(String.init) })).sorted()
                    guard let replacement = letters.first(where: { letter in
                        guard letter != game.board[index].letter else { return false }
                        var trial = game; trial.board[index].letter = letter
                        return useful(trial, previous: game, protected: before)
                    }) else { return Turn(game, valid: false) }
                    next.board[index].letter = replacement
                }
            case .bomb:
                let region = game.board.indices.filter { abs($0 / n - index / n) <= 1 && abs($0 % n - index % n) <= 1 && game.board[$0].kind != .locked }
                var random = SeededRandom(seed: game.level.seed &+ UInt64(game.revision * 7919 + index))
                var candidate: Game?
                for _ in 0..<72 {
                    var trial = game
                    let tiles = random.shuffled(region.map { game.board[$0] })
                    for (offset, cell) in region.enumerated() {
                        trial.board[cell] = tiles[offset]
                        if trial.board[cell].kind == .frozen { trial.board[cell].kind = .normal }
                    }
                    if useful(trial, previous: game, protected: before) { candidate = trial; break }
                }
                guard let candidate else { return Turn(game, valid: false) }; next = candidate
            case .rainbow:
                guard letter.count == 1, letter.utf8.allSatisfy({ (65...90).contains($0) }), !game.board[index].kind.blocked else { return Turn(game, valid: false) }
                next.board[index].letter = letter; next.board[index].kind = .rainbow
                guard useful(next, previous: game, protected: before) else { return Turn(game, valid: false) }
            case .lightning: return Turn(game, valid: false)
            }
            if matches(next).isEmpty == false || legalMoves(next).isEmpty { return Turn(game, valid: false) }
        }
        guard next.board != game.board else { return Turn(game, valid: false) }
        next.revision += 1
        return Turn(next, valid: true, frames: [MatchFrame(game: next, cleared: [], chain: 0)])
    }

    private func guidedBomb(_ game: Game, at index: Int) -> Game? {
        let n = game.level.size
        let rows = Array(max(0, index/n-1)...min(n-1, index/n+1))
        let cols = Array(max(0, index%n-1)...min(n-1, index%n+1))
        for word in game.level.targets where word.count == 3 && !game.used.contains(word) {
            let letters = word.map(String.init)
            for row in rows { for col in cols { for vertical in [false, true] {
                let path = (0..<3).map { vertical ? (row+$0)*n+col : row*n+col+$0 }
                guard path.allSatisfy({ rows.contains($0/n) && cols.contains($0%n) }) else { continue }
                for gap in 0..<3 {
                    let missing = path[gap]
                    let donors = vertical ? [missing-1, missing+1] : [missing-n, missing+n]
                    for donor in donors where donor >= 0 && donor < n*n && rows.contains(donor/n) && cols.contains(donor%n) && adjacent(missing, donor, size: n) && !path.contains(donor) {
                        var next = game
                        for (offset, cell) in path.enumerated() {
                            next.board[cell].letter = offset == gap ? (letters[offset] == "X" ? "Z" : "X") : letters[offset]
                            next.board[cell].kind = .normal
                        }
                        next.board[donor].letter = letters[gap]; next.board[donor].kind = .normal
                        if matches(next).isEmpty && !legalMoves(next).isEmpty { return next }
                    }
                }
            } } }
        }
        return nil
    }

    private func reachable(_ game: Game) -> Set<String> {
        Set(legalMoves(game).flatMap { move -> [String] in
            var trial = game; trial.board.swapAt(move.first, move.second)
            return matches(trial, around: [move.first, move.second]).map(\.word).filter { !game.used.contains($0) }
        })
    }
    private func useful(_ game: Game, previous: Game, protected: Set<String>) -> Bool {
        guard matches(game).isEmpty, protected.isSubset(of: reachable(game)) else { return false }
        return !Set(legalMoves(game)).subtracting(legalMoves(previous)).isEmpty
    }
    private func expandSpecials(_ game: Game, initial: Set<Int>) -> Set<Int> {
        var result = initial, queue = Array(initial).sorted(), cursor = 0
        let n = game.level.size
        while cursor < queue.count {
            let cell = queue[cursor]; cursor += 1
            let extra: [Int]
            switch game.board[cell].kind {
            case .bomb: extra = game.board.indices.filter { abs($0 / n - cell / n) <= 1 && abs($0 % n - cell % n) <= 1 }
            case .special: extra = game.board.indices.filter { $0 / n == cell / n || $0 % n == cell % n }
            case .rainbow: extra = game.board.indices.filter { game.board[$0].letter == game.board[cell].letter }
            default: extra = []
            }
            for next in extra where result.insert(next).inserted { queue.append(next) }
        }
        return result
    }
    private func collapse(_ game: Game, cleared: Set<Int>) -> Game {
        var next = game
        let n = game.level.size
        let removed = cleared.filter { !game.board[$0].kind.blocked }
        for cell in game.board.indices where game.board[cell].kind.blocked {
            if cleared.contains(cell) || cleared.contains(where: { abs($0 / n - cell / n) <= 1 && abs($0 % n - cell % n) <= 1 }) {
                next.board[cell].kind = .normal
            }
        }
        var random = SeededRandom(seed: game.level.seed &+ UInt64(game.refill * 7919 + game.revision * 104729))
        for col in 0..<n {
            let survivors = (0..<n).map { $0*n+col }.filter { !removed.contains($0) }.map { next.board[$0] }
            let missing = n - survivors.count
            let fresh = (0..<missing).map { _ -> Tile in
                defer { next.nextID += 1; next.refill += 1 }
                return Tile(alphabet[random.index(alphabet.count)], id: next.nextID)
            }
            for (row, tile) in (fresh + survivors).enumerated() { next.board[row*n+col] = tile }
        }
        next.revision += 1
        return next
    }
}
