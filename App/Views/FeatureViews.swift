import SwiftUI
import GameCore

struct LevelsView: View {
    @ObservedObject var model: AppModel
    @State private var world = 1
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Your journey").font(.largeTitle.bold())
                Text("Ten thousand little adventures. One magical world of words.").foregroundStyle(Palette.lavender)
                Picker("World", selection: $world) {
                    ForEach(1...min(100, (model.profile.unlocked-1)/100+1), id: \.self) { Text("World \($0)").tag($0) }
                }.pickerStyle(.menu).frame(minHeight: 44)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 14)], spacing: 14) {
                    ForEach(((world-1)*100+1)...(world*100), id: \.self) { level in
                        let unlocked = level <= model.profile.unlocked
                        Button { model.start(level) } label: {
                            VStack(spacing: 7) {
                                Text("\(level)").font(.title3.bold())
                                if model.profile.completed[level] != nil { Text("★★★").font(.caption).foregroundStyle(Palette.gold) }
                                else { Image(systemName: unlocked ? "play.fill" : "lock.fill").font(.caption) }
                            }.frame(maxWidth: .infinity, minHeight: 76)
                                .foregroundStyle(unlocked ? .white : Palette.lavender.opacity(0.5))
                                .background(level == model.profile.unlocked ? .purple.opacity(0.8) : Palette.panel, in: RoundedRectangle(cornerRadius: 18))
                        }.disabled(!unlocked || model.busy)
                            .accessibilityLabel("Level \(level), \(model.profile.completed[level] != nil ? "completed, three stars" : unlocked ? "unlocked" : "locked")")
                    }
                }
            }.padding(20).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.onAppear { world = (model.profile.unlocked-1)/100+1 }
    }
}

struct ShopView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ads: AdMobService
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Booster Vault").font(.largeTitle.bold())
                Text("A little magic for the trickiest words.").foregroundStyle(Palette.lavender)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                    ForEach(Booster.allCases) { booster in
                        JewelPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                BoosterArt(booster: booster).frame(width: 72, height: 72)
                                HStack { Text(booster.title).font(.title2.bold()); Spacer(); Text("×\(model.profile.inventory[booster, default: 0])").foregroundStyle(Palette.mint) }
                                Text(booster.detail).font(.subheadline).foregroundStyle(Palette.lavender).frame(minHeight: 52, alignment: .top)
                                Button("Get one · 75 coins") { model.buy(booster) }.buttonStyle(JewelButtonStyle(prominent: true))
                                    .disabled(model.profile.coins < 75)
                            }
                        }
                    }
                }
                JewelPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("A gift for your journey", systemImage: "gift.fill").font(.title3.bold())
                        Text("Choose a reward and watch an available video ad.").foregroundStyle(Palette.lavender)
                        Button("Watch an ad · +50 coins") { model.rewarded(.coins) }.buttonStyle(JewelButtonStyle())
                        Button("Watch an ad · refill 5 lives") { model.rewarded(.lives) }.buttonStyle(JewelButtonStyle())
                        Button("Watch an ad · +1 hammer") { model.rewarded(.booster) }.buttonStyle(JewelButtonStyle())
                        if !ads.rewardedReady { Text("Videos may be unavailable when offline. Your game still works.").font(.footnote).foregroundStyle(Palette.lavender) }
                    }
                }
            }.padding(20).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.disabled(ads.presenting)
    }
}

struct DailyView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Daily discoveries").font(.largeTitle.bold())
                JewelPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "gift.fill").font(.system(size: 46)).foregroundStyle(Palette.gold)
                        Text("A gift, every day").font(.title2.bold())
                        Text("Come back each day to grow your seven-day coin bonus. Current streak: \(model.profile.streak).")
                            .foregroundStyle(Palette.lavender)
                        Button("Claim today's gift") { model.claimDaily() }.buttonStyle(JewelButtonStyle(prominent: true))
                            .disabled(model.profile.rewardDay >= Int(model.profile.highTime/86_400))
                    }
                }
                JewelPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Today's challenge").font(.title2.bold())
                        Text(["Find 20 words", "Complete 3 levels", "Trigger 5 combos", "Collect 50 gold tiles"][model.profile.challengeIndex])
                        ProgressView(value: Double(min(model.profile.challengeProgress, model.profile.challengeGoal)), total: Double(model.profile.challengeGoal))
                        Text("\(model.profile.challengeProgress)/\(model.profile.challengeGoal)").monospacedDigit().foregroundStyle(Palette.lavender)
                        Button(model.profile.challengeClaimed ? "Reward claimed" : "Claim 150 coins") { model.claimChallenge() }
                            .buttonStyle(JewelButtonStyle(prominent: true))
                            .disabled(model.profile.challengeClaimed || model.profile.challengeProgress < model.profile.challengeGoal)
                    }
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }.onAppear { model.refreshDaily() }
    }
}

struct StatsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Your story so far").font(.largeTitle.bold())
                JewelPanel {
                    Grid(alignment: .leading, horizontalSpacing: 30, verticalSpacing: 18) {
                        stat("Words discovered", model.profile.words)
                        stat("Levels completed", model.profile.completed.count)
                        stat("Best score", model.profile.best)
                        stat("Combos", model.profile.combos)
                        stat("Gold collected", model.profile.gold)
                    }
                }
                Text("Achievements").font(.title2.bold())
                ForEach(0..<4, id: \.self) { index in
                    JewelPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(["Word explorer", "Trailblazer", "Combo collector", "Golden touch"][index], systemImage: "medal.fill").font(.headline)
                            let progress = model.profile.achievementProgress(index)
                            let goal = model.profile.achievementGoal(index)
                            Text("\(progress)/\(goal)").foregroundStyle(Palette.lavender)
                            Button(model.profile.achievements.contains(index) ? "Claimed" : "Claim 100 coins") { model.claimAchievement(index) }
                                .buttonStyle(JewelButtonStyle()).disabled(progress < goal || model.profile.achievements.contains(index))
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
    }
    private func stat(_ title: String, _ value: Int) -> some View {
        GridRow { Text(title).foregroundStyle(Palette.lavender); Text("\(value)").font(.headline.monospacedDigit()).foregroundStyle(Palette.gold) }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var ads: AdMobService
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Make yourself at home").font(.largeTitle.bold())
                JewelPanel {
                    VStack(spacing: 18) {
                        Toggle("Music", isOn: setting(\.music))
                        Slider(value: setting(\.musicVolume), in: 0...1) { Text("Music volume") }.disabled(!model.settings.music)
                        Toggle("Sound effects", isOn: setting(\.sound))
                        Slider(value: setting(\.effectsVolume), in: 0...1) { Text("Effects volume") }.disabled(!model.settings.sound)
                        Toggle("Haptic feedback", isOn: setting(\.haptics))
                        Toggle("Animations", isOn: setting(\.motion))
                    }
                }
                JewelPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy & play").font(.title2.bold())
                        Text("Your game progress stays on this device. The game works offline. If ads are available, Google and its advertising partners process advertising data according to your consent choices.").foregroundStyle(Palette.lavender)
                        if ads.privacyOptionsRequired {
                            Button("Advertising privacy choices") { Task { await ads.privacyOptions() } }.buttonStyle(JewelButtonStyle())
                        }
                        if let url = privacyPolicyURL { Link("Privacy policy", destination: url).frame(minHeight: 44) }
                        Text("The game does not request permission to track you across other companies' apps and websites.").font(.footnote).foregroundStyle(Palette.lavender)
                    }
                }
                Button("View statistics & achievements") { model.navigate(.stats) }.buttonStyle(JewelButtonStyle())
                Text("Word Crush Mania · iPhone & iPad").font(.footnote).foregroundStyle(Palette.lavender)
            }.padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
        }
    }
    private func setting<Value>(_ keyPath: WritableKeyPath<Settings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: keyPath] }, set: { value in model.changeSettings { $0[keyPath: keyPath] = value } })
    }
    private var privacyPolicyURL: URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "PrivacyPolicyURL") as? String,
              let url = URL(string: text), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}
