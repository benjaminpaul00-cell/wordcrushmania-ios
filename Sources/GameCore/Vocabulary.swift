import Foundation

public enum Vocabulary {
    public static let themes = ["Animals", "Nature", "Food", "Travel", "Science", "Technology", "Sport", "History", "Space", "Music"]
    public static let symbols = ["pawprint.fill", "leaf.fill", "carrot.fill", "airplane", "atom", "desktopcomputer", "sportscourt.fill", "building.columns.fill", "moon.stars.fill", "music.note"]
    private static let lists: [[String]] = {
        guard let url = Bundle.module.url(forResource: "vocabulary-en", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lists = try? JSONDecoder().decode([[String]].self, from: data), lists.count == 10 else {
            return Array(repeating: [], count: 10)
        }
        return lists
    }()
    public static func words(theme: Int, size: Int) -> [String] {
        lists[theme % 10].filter { (3...size).contains($0.count) }
    }
}
