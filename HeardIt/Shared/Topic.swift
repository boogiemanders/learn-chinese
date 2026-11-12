import Foundation

/// A themed deck the learner picks for a reason of their own: family, work, therapy,
/// brush painting. Hand-made topics ship in topics.json; generated ones are saved
/// next to progress.json in the App Group so the widget sees them too.
struct Topic: Codable, Identifiable, Hashable {
    let id: String
    /// English name for tabs and settings, e.g. "Brush painting".
    let title: String
    /// Two characters for the brush heading, e.g. "国画".
    let hanzi: String
    /// Four characters for the vertical label on the card, e.g. "岭南画派".
    let label: String
    /// Short tag for the 宜 box on the tear-off page, and its longer line.
    let tag: String
    let line: String
    var keywords: [String]? = nil
    var words: [Word]
    /// True when Claude wrote this deck; its readings haven't been checked by hand.
    var generated: Bool? = nil
}

/// A reason for learning Chinese, offered on the first screen. Picking one turns on
/// its topic decks; reasons the base decks already cover (travel, menus, HSK) add none.
struct Goal: Identifiable, Hashable {
    let id: String
    let hanzi: String
    let title: String
    let topics: [String]

    static let all: [Goal] = [
        Goal(id: "travel", hanzi: "旅行", title: "Travel", topics: []),
        Goal(id: "family", hanzi: "家人", title: "Talk with family", topics: ["family"]),
        Goal(id: "heritage", hanzi: "寻根", title: "Heritage & roots", topics: ["heritage"]),
        Goal(id: "work", hanzi: "工作", title: "Work & business", topics: ["work"]),
        Goal(id: "love", hanzi: "恋爱", title: "Dating or a partner", topics: ["love"]),
        Goal(id: "food", hanzi: "美食", title: "Food & cooking", topics: ["cooking"]),
        Goal(id: "media", hanzi: "影视", title: "Shows & music", topics: ["media"]),
        Goal(id: "move", hanzi: "生活", title: "Moving there", topics: ["living"]),
        Goal(id: "read", hanzi: "认字", title: "Read signs & menus", topics: []),
        Goal(id: "exam", hanzi: "考试", title: "Exams (HSK)", topics: []),
        Goal(id: "business", hanzi: "创业", title: "Startups, VC & MBA", topics: ["business"]),
        Goal(id: "ai", hanzi: "智能", title: "AI & tech", topics: ["ai"]),
        Goal(id: "dentistry", hanzi: "牙科", title: "Dentistry", topics: ["dentistry"]),
        Goal(id: "psychology", hanzi: "心理", title: "Psychology", topics: ["psychology"]),
        Goal(id: "art", hanzi: "陶艺", title: "Art & pottery", topics: ["pottery", "lingnan"]),
        Goal(id: "dance", hanzi: "跳舞", title: "Dance", topics: ["dance"]),
        Goal(id: "music", hanzi: "音乐", title: "Music production", topics: ["music"]),
        Goal(id: "wisdom", hanzi: "经典", title: "Chinese wisdom", topics: ["wisdom"]),
    ]
}

enum TopicCatalog {
    static func loadBundled(_ bundle: Bundle = .main) -> [Topic] {
        guard let url = bundle.url(forResource: "topics", withExtension: "json"),
              let raw = try? Data(contentsOf: url),
              let topics = try? JSONDecoder().decode([Topic].self, from: raw) else { return [] }
        return topics
    }

    /// Every topic with a keyword in a free-text reason, so "be a psychologist and a
    /// Lingnan brush painter" turns on both decks.
    static func match(_ text: String, in topics: [Topic]) -> [Topic] {
        // a keyword matches the start of a word ("paint" → "painter", but "art" ≠ "start");
        // two-word keywords like "kung fu" match as a phrase
        let t = text.lowercased()
        let tokens = t.split { !$0.isLetter }.map(String.init)
        func hit(_ k: String) -> Bool { k.contains(" ") ? t.contains(k) : tokens.contains { $0.hasPrefix(k) } }
        return topics.filter { ($0.keywords ?? []).contains(where: hit) }
    }
}

extension Word {
    /// The vertical label on the card: why this word is in your deck.
    var label: String {
        if deck == .topic, let t = topic, let found = Store.shared.topic(id: t) { return found.label }
        return deck.label
    }
}
