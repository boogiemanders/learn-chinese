import Foundation

/// Which deck a word belongs to. The weight is how much the word matters for
/// a trip to China (survival first, then menus, then Cantonese→Mandarin pairs).
enum Deck: String, Codable, CaseIterable, Identifiable {
    case survival
    case trip
    case menu
    case cantoPair
    case core

    var id: String { rawValue }

    var title: String {
        switch self {
        case .survival: return "Essentials"
        case .trip: return "My trip"
        case .menu: return "Menu"
        case .cantoPair: return "Canto pairs"
        case .core: return "Core"
        }
    }

    /// The small vertical label on the card: why this word is in your deck.
    var label: String {
        switch self {
        case .survival: return "基本必备"
        case .trip: return "旅行必备"
        case .menu: return "菜单解码"
        case .cantoPair: return "粤普对照"
        case .core: return "基本词"
        }
    }

    var weight: Double {
        switch self {
        case .survival: return 1.0
        case .trip: return 0.95
        case .menu: return 0.9
        case .cantoPair: return 0.7
        case .core: return 0.6
        }
    }
}

enum Script: String, Codable, CaseIterable, Identifiable {
    case simplified, traditional
    var id: String { rawValue }
    var title: String { self == .simplified ? "Simplified" : "Traditional" }
}

enum ReadingMode: String, Codable, CaseIterable, Identifiable {
    case both, mandarin, cantonese
    var id: String { rawValue }
    var title: String {
        switch self {
        case .both: return "Pinyin + Jyutping"
        case .mandarin: return "Pinyin only"
        case .cantonese: return "Jyutping only"
        }
    }
}

struct Word: Codable, Identifiable, Hashable {
    let id: String
    let simplified: String
    let traditional: String
    /// Mandarin reading. Empty for Cantonese-only words (see `mandarinWord`).
    let pinyin: String
    /// Cantonese reading.
    let jyutping: String
    let meaning: String
    let deck: Deck
    /// For Cantonese-only words: the Mandarin word you'd use instead, e.g. "他 tā".
    let mandarinWord: String?
    /// Short usage note, e.g. how the dish name breaks down.
    let note: String?

    func hanzi(_ script: Script) -> String {
        script == .simplified ? simplified : traditional
    }

    /// A meaning short enough for the 1×1 lock screen widget (12 characters or fewer).
    var shortMeaning: String {
        if meaning.count <= 12 { return meaning }
        let cut = meaning.components(separatedBy: CharacterSet(charactersIn: "(,;")).first?
            .trimmingCharacters(in: .whitespaces) ?? meaning
        return cut.count <= 12 ? cut : String(cut.prefix(11)) + "…"
    }

    /// Readings labelled by dialect: "普 chāshāo · 粵 caa1 siu1".
    func labelledReadings(_ mode: ReadingMode) -> String {
        let mando = pinyin.isEmpty ? (mandarinWord ?? "") : pinyin
        let m = mando.isEmpty ? nil : "普 \(mando)"
        let c = jyutping.isEmpty ? nil : "粵 \(jyutping)"
        switch mode {
        case .both: return [m, c].compactMap { $0 }.joined(separator: " · ")
        case .mandarin: return m ?? c ?? ""
        case .cantonese: return c ?? m ?? ""
        }
    }

    func readings(_ mode: ReadingMode) -> String {
        let mando = pinyin.isEmpty ? (mandarinWord.map { "→ \($0)" } ?? "") : pinyin
        switch mode {
        case .both: return [mando, jyutping].filter { !$0.isEmpty }.joined(separator: " · ")
        case .mandarin: return mando
        case .cantonese: return jyutping
        }
    }
}

enum WordLoader {
    static func load(from url: URL) throws -> [Word] {
        try JSONDecoder().decode([Word].self, from: Data(contentsOf: url))
    }

    static func loadBundled(_ bundle: Bundle = .main) -> [Word] {
        guard let url = bundle.url(forResource: "words", withExtension: "json"),
              let words = try? load(from: url) else { return [] }
        return words
    }
}
