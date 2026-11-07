import SwiftUI
import UIKit
import GameCore

enum Palette {
    static let ink = Color(red: 0.09, green: 0.04, blue: 0.19)
    static let panel = Color(red: 0.20, green: 0.11, blue: 0.34)
    static let lavender = Color(red: 0.77, green: 0.68, blue: 0.95)
    static let gold = Color(red: 1, green: 0.82, blue: 0.39)
    static let mint = Color(red: 0.43, green: 0.91, blue: 0.76)
}

struct ForestBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("Forest").resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                .overlay(LinearGradient(colors: [Palette.ink.opacity(0.35), Palette.ink.opacity(0.94)], startPoint: .top, endPoint: .bottom))
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}

struct JewelPanel<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.panel.opacity(0.94), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.lavender.opacity(0.22)))
    }
}

struct JewelButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 18).padding(.vertical, 14)
            .frame(minHeight: 48)
            .foregroundStyle(prominent ? Palette.ink : .white)
            .background(prominent ? Palette.gold : Palette.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.16)))
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.4)
    }
}

struct Metric: View {
    let symbol: String
    let value: String
    var color: Color = Palette.gold
    var body: some View {
        Label(value, systemImage: symbol).font(.headline.monospacedDigit()).foregroundStyle(color)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Palette.ink.opacity(0.75), in: Capsule())
    }
}

extension Booster {
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .hammer: return "hammer.fill"; case .bomb: return "burst.fill"; case .lightning: return "bolt.fill"; case .rainbow: return "rainbow" }
    }
    var detail: String {
        switch self {
        case .hammer: return "Open ice or chains, or change a letter to create a useful swap."
        case .bomb: return "Rearrange a nearby patch to open a new move."
        case .lightning: return "Reveal a verified swap for one of your target words."
        case .rainbow: return "Choose a letter, then a tile to create a new useful swap."
        }
    }
}

@MainActor struct BoosterArt: View {
    let booster: Booster
    private static let sprites: [Booster: UIImage] = {
        guard let atlas = UIImage(named: "Boosters")?.cgImage else { return [:] }
        let width = atlas.width/2, height = atlas.height/2
        return Dictionary(uniqueKeysWithValues: Booster.allCases.enumerated().compactMap { index, booster in
            let rect = CGRect(x: CGFloat(index%2*width), y: CGFloat(index/2*height), width: CGFloat(width), height: CGFloat(height))
            guard let crop = atlas.cropping(to: rect) else { return nil }
            return (booster, UIImage(cgImage: crop))
        })
    }()
    var body: some View {
        Group {
            if let image = Self.sprites[booster] { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: booster.symbol).resizable().scaledToFit().foregroundStyle(Palette.gold) }
        }.accessibilityHidden(true)
    }
}
