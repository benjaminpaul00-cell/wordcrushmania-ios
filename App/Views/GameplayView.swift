import SwiftUI
import GameCore

struct GameplayView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var assistRow = 0
    @State private var assistColumn = 0
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let game = model.displayGame, let session = model.session {
                    VStack(spacing: 18) {
                        heading(game, session)
                        if session.phase != .playing && !model.busy { result(session) }
                        else if model.paused { pausePanel }
                        else {
                            if model.tutorialWaiting { coach(game) }
                            if geometry.size.width >= 850 && geometry.size.height >= 500 {
                                HStack(alignment: .top, spacing: 24) {
                                    board(game).frame(maxWidth: 580)
                                    VStack(spacing: 18) { goals(game); controls; assistiveSelection(game) }.frame(width: 275)
                                }.frame(maxWidth: 900)
                            } else {
                                goals(game)
                                board(game).frame(maxWidth: 520)
                                controls
                                assistiveSelection(game)
                            }
                        }
                    }.padding(16).frame(maxWidth: .infinity)
                } else { ProgressView("Preparing the board…").padding(40) }
            }
        }
    }
    private func heading(_ game: Game, _ session: Session) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Level \(game.level.number)").font(.title2.bold())
                Label(Vocabulary.themes[game.level.theme], systemImage: Vocabulary.symbols[game.level.theme])
                    .font(.subheadline).foregroundStyle(Palette.lavender)
            }
            Spacer()
            if session.phase == .playing {
                Label("\(Int(ceil(session.remaining)))s", systemImage: "timer")
                    .font(.title2.bold().monospacedDigit()).foregroundStyle(session.remaining <= 8 ? .pink : Palette.gold)
                    .accessibilityLabel("\(Int(ceil(session.remaining))) seconds remaining")
                Button { model.togglePause() } label: { Image(systemName: model.paused ? "play.fill" : "pause.fill").frame(width: 44, height: 44) }
                    .disabled(model.busy).accessibilityLabel(model.paused ? "Resume game" : "Pause game")
            }
        }.frame(maxWidth: 900)
    }
    private func goals(_ game: Game) -> some View {
        JewelPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("FIND THESE WORDS").font(.caption.bold()).tracking(1.6).foregroundStyle(Palette.lavender)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { targets(game) }
                    VStack(alignment: .leading, spacing: 10) { targets(game) }
                }
                HStack {
                    Label("\(game.score)/\(game.level.scoreGoal)", systemImage: "star.fill").foregroundStyle(Palette.gold)
                    if game.level.goldGoal > 0 {
                        Label("\(game.gold)/\(game.level.goldGoal)", systemImage: "diamond.fill").foregroundStyle(Palette.mint)
                    }
                    Spacer(minLength: 0)
                    if game.combo > 1 { Text("×\(game.combo)").font(.headline).foregroundStyle(.pink) }
                }.font(.subheadline.monospacedDigit())
            }
        }.frame(maxWidth: 900)
    }
    @ViewBuilder private func targets(_ game: Game) -> some View {
        ForEach(game.level.targets, id: \.self) { word in
            Label(word, systemImage: game.used.contains(word) ? "checkmark.circle.fill" : "circle")
                .font(.subheadline.bold()).foregroundStyle(game.used.contains(word) ? Palette.mint : .white)
                .accessibilityLabel("\(word), \(game.used.contains(word) ? "found" : "still to find")")
        }
    }
    private func board(_ game: Game) -> some View {
        GeometryReader { geometry in
            let n = game.level.size
            let spacing: CGFloat = n >= 8 ? 4 : 6
            let side = (geometry.size.width - 20 - CGFloat(n-1)*spacing)/CGFloat(n)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: n), spacing: spacing) {
                ForEach(game.board.indices, id: \.self) { index in
                    let tile = game.board[index]
                    let highlighted = model.selected == index || model.hint?.first == index || model.hint?.second == index
                    Button { model.tap(index) } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: max(5, side*0.18))
                                .fill(LinearGradient(colors: tileColors(tile), startPoint: .topLeading, endPoint: .bottomTrailing))
                            RoundedRectangle(cornerRadius: max(5, side*0.18))
                                .strokeBorder(highlighted ? Palette.gold : .white.opacity(0.35), lineWidth: highlighted ? 3 : 1)
                            Text(tile.letter).font(.system(size: max(14, side*0.48), weight: .black, design: .rounded)).foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 2)
                            if let symbol = symbol(tile.kind) {
                                Image(systemName: symbol).font(.system(size: max(8, side*0.22))).foregroundStyle(Palette.gold)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(3)
                            }
                        }.frame(height: side).opacity(model.cleared.contains(index) ? 0.25 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tile.letter), row \(index/n+1), column \(index%n+1), \(tile.kind.rawValue)")
                    .accessibilityHint("Select this tile, then an adjacent tile to swap.")
                    .accessibilityAddTraits(highlighted ? .isSelected : [])
                    .accessibilityIdentifier("tile-\(index)")
                    .highPriorityGesture(DragGesture(minimumDistance: 16).onEnded { value in
                        let horizontal = abs(value.translation.width) > abs(value.translation.height)
                        let offset = horizontal ? (value.translation.width > 0 ? 1 : -1) : (value.translation.height > 0 ? n : -n)
                        let next = index + offset
                        guard MatchEngine().adjacent(index, next, size: n) else { return }
                        model.selected = nil; model.tap(index); model.tap(next)
                    })
                }
            }.padding(10).background(Palette.ink.opacity(0.88), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.lavender.opacity(0.6), lineWidth: 2))
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(!model.busy && !model.tutorialWaiting)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Word board")
    }
    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Booster.allCases) { booster in
                    Button { model.chooseBooster(booster) } label: {
                        VStack(spacing: 5) {
                            BoosterArt(booster: booster).frame(width: 40, height: 40)
                            Text("\(model.profile.inventory[booster, default: 0])").font(.caption.bold())
                        }.foregroundStyle(model.selectedBooster == booster ? Palette.ink : Palette.gold)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(model.selectedBooster == booster ? Palette.gold : Palette.panel, in: RoundedRectangle(cornerRadius: 14))
                    }.accessibilityLabel("\(booster.title), \(model.profile.inventory[booster, default: 0]) remaining")
                }
            }
            if let booster = model.selectedBooster {
                Text(booster.detail).font(.footnote).foregroundStyle(Palette.lavender)
                if booster == .rainbow {
                    Picker("Replacement letter", selection: $model.rainbowLetter) {
                        ForEach(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init), id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).frame(minHeight: 44)
                }
                Button("Cancel booster") { model.selectedBooster = nil }.frame(minHeight: 44)
            }
            HStack {
                Button { model.showHint() } label: { Label("Hint", systemImage: "lightbulb") }.buttonStyle(JewelButtonStyle())
                Button { model.shuffle() } label: { Label("Shuffle", systemImage: "shuffle") }.buttonStyle(JewelButtonStyle())
            }
            Text("Swap two neighboring letters. Only the target words count.").font(.footnote).foregroundStyle(Palette.lavender).multilineTextAlignment(.center)
        }.frame(maxWidth: 520).disabled(model.busy || model.tutorialWaiting)
    }
    private func assistiveSelection(_ game: Game) -> some View {
        DisclosureGroup("Select a tile by row and column") {
            VStack {
                HStack {
                    Picker("Row", selection: $assistRow) { ForEach(0..<game.level.size, id: \.self) { Text("Row \($0+1)").tag($0) } }
                    Picker("Column", selection: $assistColumn) { ForEach(0..<game.level.size, id: \.self) { Text("Column \($0+1)").tag($0) } }
                }.pickerStyle(.menu)
                Button("Select tile") { model.tap(assistRow*game.level.size+assistColumn) }.buttonStyle(JewelButtonStyle())
            }
        }.padding(12).frame(maxWidth: 520).font(.footnote).disabled(model.busy || model.tutorialWaiting)
    }
    private func coach(_ game: Game) -> some View {
        JewelPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text(game.level.number == 4 ? "Break the ice" : game.level.number == 5 ? "Make room for magic" : "Make your first swap").font(.title3.bold())
                Text(game.level.number == 4 ? "Choose the hammer, then tap a frozen tile to reveal a playable word." : game.level.number == 5 ? "Choose the bomb, then tap the board to open a playable area." : "Swap two adjacent letters to make one of the target words in a straight line. Use Hint if you need a hand.")
                    .foregroundStyle(Palette.lavender)
                Button("Got it") { model.acknowledgeCoach() }.buttonStyle(JewelButtonStyle(prominent: true)).accessibilityIdentifier("dismissCoach")
            }
        }.frame(maxWidth: 600)
    }
    private var pausePanel: some View {
        JewelPanel {
            VStack(spacing: 20) {
                Image(systemName: "pause.circle.fill").font(.system(size: 54)).foregroundStyle(Palette.gold)
                Text("Take a breath").font(.title.bold())
                Text("Your timer is paused.").foregroundStyle(Palette.lavender)
                Button("Resume") { model.togglePause() }.buttonStyle(JewelButtonStyle(prominent: true))
            }.frame(maxWidth: .infinity)
        }.frame(maxWidth: 500)
    }
    private func result(_ session: Session) -> some View {
        JewelPanel {
            VStack(spacing: 20) {
                Image(systemName: session.phase == .won ? "crown.fill" : "hourglass.bottomhalf.filled")
                    .font(.system(size: 64)).foregroundStyle(Palette.gold)
                Text(session.phase == .won ? "Wonderful!" : "Time's up").font(.largeTitle.bold()).accessibilityIdentifier("resultTitle")
                if session.phase == .won {
                    Text("★ ★ ★").font(.largeTitle).foregroundStyle(Palette.gold)
                    Text("\(session.game.score) points · +\(session.rewardCoins) coins")
                    Button(session.game.level.number == 10_000 ? "Play again" : "Next level") { model.nextLevel() }.buttonStyle(JewelButtonStyle(prominent: true))
                    if !session.doubled {
                        Button("Watch an ad · double these coins") { model.rewarded(.doubleCoins) }.buttonStyle(JewelButtonStyle())
                    }
                } else {
                    Text("A fresh board is waiting. You have \(model.profile.lives) lives left.").multilineTextAlignment(.center)
                    Button("Try again") { model.start(session.game.level.number, fresh: true) }.buttonStyle(JewelButtonStyle(prominent: true))
                        .disabled(model.profile.lives == 0)
                    Button("Watch an ad · refill 5 lives") { model.rewarded(.lives) }.buttonStyle(JewelButtonStyle())
                }
                Button("Back to journey") { model.navigate(.levels) }.frame(minHeight: 44)
            }.frame(maxWidth: .infinity)
        }.frame(maxWidth: 540)
    }
    private func tileColors(_ tile: Tile) -> [Color] {
        if tile.kind == .frozen { return [.cyan.opacity(0.9), .blue.opacity(0.7)] }
        if tile.kind == .locked { return [.gray, .gray.opacity(0.4)] }
        if tile.kind == .gold { return [Color(red: 0.98, green: 0.69, blue: 0.23), Color(red: 0.66, green: 0.31, blue: 0.08)] }
        let colors: [[Color]] = [[.purple, .indigo], [.pink, .purple], [.teal, .blue], [.blue, .indigo]]
        return colors[Int(tile.letter.utf8.first ?? 65) % colors.count]
    }
    private func symbol(_ kind: TileKind) -> String? {
        switch kind {
        case .frozen: return "snowflake"
        case .locked: return "lock.fill"
        case .bomb: return "burst.fill"
        case .rainbow: return "rainbow"
        case .special: return "sparkles"
        case .gold: return "diamond.fill"
        case .normal: return nil
        }
    }
}
