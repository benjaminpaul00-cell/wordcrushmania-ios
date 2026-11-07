import SwiftUI
import GameCore

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var ads: AdMobService
    @State private var confirmRecovery = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    init(model: AppModel) { self.model = model; ads = model.ads }
    var body: some View {
        ZStack {
            ForestBackground()
            VStack(spacing: 0) {
                topBar
                Group {
                    if model.storageBlocked { recovery }
                    else {
                        switch model.destination {
                        case .home: HomeView(model: model)
                        case .game: GameplayView(model: model)
                        case .levels: LevelsView(model: model)
                        case .shop: ShopView(model: model, ads: ads)
                        case .daily: DailyView(model: model)
                        case .stats: StatsView(model: model)
                        case .settings: SettingsView(model: model, ads: ads)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if model.destination != .game { navigationBar }
                BannerSlot(ads: ads)
            }
            if model.busy && model.displayGame == nil {
                ProgressView("Preparing your adventure…").padding(30).background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .tint(Palette.gold)
        .onReceive(ticker) { _ in model.tick() }
        .onAppear { model.ads.requestConsent(); model.audio.update(model.settings, active: true) }
        .onChange(of: ads.presenting) { _, presenting in
            model.adPresentationChanged(presenting)
        }
        .alert("Word Crush Mania", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .confirmationDialog("Start fresh and preserve a backup of this save?", isPresented: $confirmRecovery, titleVisibility: .visible) {
            Button("Preserve backup and start fresh", role: .destructive) { model.recoverSave() }
        }
    }
    private var topBar: some View {
        HStack {
            if model.destination != .home {
                Button { model.navigate(.home) } label: { Image(systemName: "house.fill").frame(width: 44, height: 44) }
                    .accessibilityLabel("Home").disabled(model.busy || ads.presenting)
            } else { Text("WORD CRUSH").font(.caption.weight(.black)).tracking(2).foregroundStyle(Palette.lavender) }
            Spacer(minLength: 4)
            Metric(symbol: "heart.fill", value: "\(model.profile.lives)/5", color: .pink)
                .accessibilityLabel("\(model.profile.lives) lives remaining")
            Metric(symbol: "circle.fill", value: "\(model.profile.coins)")
                .accessibilityLabel("\(model.profile.coins) coins")
        }.padding(.horizontal, 16).padding(.vertical, 8)
    }
    private var navigationBar: some View {
        HStack(spacing: 0) {
            nav("Play", "play.fill", .home)
            nav("Journey", "map.fill", .levels)
            nav("Vault", "shippingbox.fill", .shop)
            nav("Daily", "gift.fill", .daily)
            nav("More", "gearshape.fill", .settings)
        }.padding(.top, 8).background(Palette.ink.opacity(0.85))
    }
    private func nav(_ title: String, _ symbol: String, _ destination: Destination) -> some View {
        Button { model.navigate(destination) } label: {
            VStack(spacing: 5) { Image(systemName: symbol).font(.title3); Text(title).font(.caption2) }
                .foregroundStyle(model.destination == destination ? Palette.gold : Palette.lavender)
                .frame(maxWidth: .infinity, minHeight: 56)
        }.disabled(model.busy || model.storageBlocked)
    }
    private var recovery: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
            Text("Your save needs attention").font(.title2.bold())
            Text("Your existing save has been preserved. You can create a backup and start a new journey.").multilineTextAlignment(.center)
            Button("Back up and start fresh") { confirmRecovery = true }.buttonStyle(JewelButtonStyle(prominent: true))
        }.padding(30).frame(maxWidth: 500)
    }
}

struct HomeView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image("Logo").resizable().scaledToFit().frame(maxWidth: 440).frame(height: 210).accessibilityLabel("Word Crush Mania")
                HStack(alignment: .center, spacing: 20) {
                    Image("Raccoon").resizable().scaledToFit().frame(width: 100, height: 110).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A little swap.\nA world of words.").font(.title.bold())
                        Text("Find your targets and keep the magic flowing.").foregroundStyle(Palette.lavender)
                    }
                }
                JewelPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("YOUR NEXT ADVENTURE").font(.caption.bold()).tracking(2).foregroundStyle(Palette.lavender)
                        Text("Level \(model.profile.unlocked)").font(.largeTitle.bold())
                        Label(Vocabulary.themes[(model.profile.unlocked - 1) % 10], systemImage: Vocabulary.symbols[(model.profile.unlocked - 1) % 10])
                        if let session = model.session, session.phase == .playing {
                            Button("Continue level \(session.game.level.number)") { model.start(session.game.level.number) }
                                .buttonStyle(JewelButtonStyle(prominent: true)).accessibilityIdentifier("continueGame")
                        } else {
                            Button("Play now") { model.start() }.buttonStyle(JewelButtonStyle(prominent: true)).accessibilityIdentifier("playNow")
                        }
                    }
                }
                Button { model.navigate(.stats) } label: { Label("Your achievements & statistics", systemImage: "trophy.fill") }
                    .buttonStyle(JewelButtonStyle())
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.disabled(model.busy)
    }
}
