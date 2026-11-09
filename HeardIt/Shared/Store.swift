import Foundation

enum CardStyle: String, Codable, CaseIterable, Identifiable {
    case poster, panel
    var id: String { rawValue }
    var title: String { self == .poster ? "Poster" : "Panel" }
}

struct AppSettings: Codable, Hashable {
    var cardStyle: CardStyle = .poster
    var disabledDecks: [Deck] = []
    var script: Script = .simplified
    var readings: ReadingMode = .both
    var newPerDay: Int = 8
    /// Say the word aloud when a card is revealed in the app. The widget never auto-plays.
    var speakOnReveal: Bool = true

    init() {}

    /// Tolerant decoding so settings saved by older versions keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cardStyle = try c.decodeIfPresent(CardStyle.self, forKey: .cardStyle) ?? .poster
        disabledDecks = try c.decodeIfPresent([Deck].self, forKey: .disabledDecks) ?? []
        script = try c.decodeIfPresent(Script.self, forKey: .script) ?? .simplified
        readings = try c.decodeIfPresent(ReadingMode.self, forKey: .readings) ?? .both
        newPerDay = try c.decodeIfPresent(Int.self, forKey: .newPerDay) ?? 8
        speakOnReveal = try c.decodeIfPresent(Bool.self, forKey: .speakOnReveal) ?? true
    }
}

struct StoreData: Codable {
    var states: [String: ReviewState] = [:]
    /// The card currently flipped on the widget, if any.
    var revealedID: String?
    var settings = AppSettings()
    var newCountDay: String = ""
    var newCount: Int = 0
    /// Days with at least one graded card ("yyyy-MM-dd"). Optional so older saves still decode.
    var practiceDays: [String]?
}

/// What the tear-off page shows on its sides: the day count and this week's strip.
struct Practice: Hashable {
    var days: Int = 0
    /// Monday first. True where at least one card was graded.
    var week: [Bool] = Array(repeating: false, count: 7)
    /// 0 = Monday … 6 = Sunday.
    var today: Int = 0

    static func from(_ keys: [String], now: Date = .now) -> Practice {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let today = (cal.component(.weekday, from: now) + 5) % 7
        let set = Set(keys)
        let monday = cal.date(byAdding: .day, value: -today, to: now) ?? now
        let week = (0..<7).map { i in
            set.contains(Store.dayKey(cal.date(byAdding: .day, value: i, to: monday) ?? now))
        }
        return Practice(days: set.count, week: week, today: today)
    }
}

/// Shared state for the app and the widget, saved as one JSON file in the
/// App Group container so both processes read the same progress.
final class Store {
    static let appGroupID = "group.com.anderschan.heardit"
    static let shared = Store()

    let words: [Word]
    private(set) var data = StoreData()
    private let fileURL: URL
    private let lock = NSLock()

    init(words: [Word] = WordLoader.loadBundled(), directory: URL? = nil) {
        self.words = words
        let dir = directory
            ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Store.appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("progress.json")
        reload()
    }

    func reload() {
        lock.lock(); defer { lock.unlock() }
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder.iso.decode(StoreData.self, from: raw) {
            data = decoded
        }
    }

    private func save() {
        if let raw = try? JSONEncoder.iso.encode(data) {
            try? raw.write(to: fileURL, options: .atomic)
        }
    }

    private func mutate(_ change: (inout StoreData) -> Void) {
        lock.lock(); defer { lock.unlock() }
        change(&data)
        save()
    }

    // MARK: Reading

    var settings: AppSettings { data.settings }

    func word(id: String) -> Word? { words.first { $0.id == id } }

    func state(for id: String) -> ReviewState? { data.states[id] }

    func practice(now: Date = .now) -> Practice { Practice.from(data.practiceDays ?? [], now: now) }

    func newAllowedToday(now: Date = .now) -> Int {
        let today = Store.dayKey(now)
        let used = data.newCountDay == today ? data.newCount : 0
        return max(0, data.settings.newPerDay - used)
    }

    func queue(now: Date = .now) -> [Word] {
        let off = Set(data.settings.disabledDecks)
        return Scheduler.queue(words: words.filter { !off.contains($0.deck) }, states: data.states, now: now, newAllowed: newAllowedToday(now: now))
    }

    /// The card to show: the one already flipped, else the top of the queue.
    func currentCard(now: Date = .now) -> Word? {
        if let id = data.revealedID, let w = word(id: id) { return w }
        return queue(now: now).first
    }

    func isRevealed(_ id: String) -> Bool { data.revealedID == id }

    // MARK: Writing

    func reveal(_ id: String) {
        mutate { $0.revealedID = id }
    }

    func grade(_ id: String, _ grade: Grade, now: Date = .now) {
        mutate { d in
            let previous = d.states[id]
            if previous?.isNew ?? true {
                let today = Store.dayKey(now)
                if d.newCountDay != today { d.newCountDay = today; d.newCount = 0 }
                d.newCount += 1
            }
            d.states[id] = Scheduler.apply(grade, to: previous, now: now)
            let day = Store.dayKey(now)
            if !(d.practiceDays ?? []).contains(day) { d.practiceDays = (d.practiceDays ?? []) + [day] }
            if d.revealedID == id { d.revealedID = nil }
        }
    }

    func setKnownByEar(_ id: String, _ known: Bool) {
        mutate { d in
            var s = d.states[id] ?? ReviewState()
            s.knownByEar = known
            d.states[id] = s
        }
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        mutate { change(&$0.settings) }
    }

    func resetProgress() {
        mutate { d in
            let settings = d.settings
            d = StoreData()
            d.settings = settings
        }
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
