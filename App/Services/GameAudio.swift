import AVFoundation
import UIKit
import GameCore

@MainActor final class GameAudio {
    private var music: AVAudioPlayer?
    private var effects: [String: AVAudioPlayer] = [:]
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }
    func update(_ settings: Settings, active: Bool) {
        if settings.music && active {
            if music == nil, let url = Bundle.main.url(forResource: "music", withExtension: "wav") {
                music = try? AVAudioPlayer(contentsOf: url); music?.numberOfLoops = -1
            }
            music?.volume = settings.musicVolume; music?.play()
        } else { music?.pause() }
    }
    func play(_ name: String, settings: Settings) {
        guard settings.sound else { return }
        if effects[name] == nil, let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            effects[name] = try? AVAudioPlayer(contentsOf: url)
        }
        effects[name]?.volume = settings.effectsVolume
        effects[name]?.currentTime = 0; effects[name]?.play()
    }
    func selection(_ settings: Settings) {
        guard settings.haptics else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
