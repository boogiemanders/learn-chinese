import AppIntents
import WidgetKit

extension Grade: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Grade"
    static let caseDisplayRepresentations: [Grade: DisplayRepresentation] = [
        .knew: "Knew it",
        .unsure: "Unsure",
        .missed: "Missed",
    ]
}

/// Flip the lock screen card to show readings and meaning.
struct RevealCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Reveal card"
    static let isDiscoverable = false

    @Parameter(title: "Word")
    var wordID: String

    init() {}
    init(wordID: String) { self.wordID = wordID }

    func perform() async throws -> some IntentResult {
        Store.shared.reload()
        Store.shared.reveal(wordID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Say the word aloud from the widget without opening the app (iOS 17 audio intent).
/// Plays Mandarin then Cantonese unless told otherwise.
struct SpeakWordIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Pronounce word"
    static let isDiscoverable = false

    @Parameter(title: "Word")
    var wordID: String

    @Parameter(title: "Mandarin", default: true)
    var mandarin: Bool

    @Parameter(title: "Cantonese", default: true)
    var cantonese: Bool

    init() {}
    init(wordID: String, mandarin: Bool = true, cantonese: Bool = true) {
        self.wordID = wordID
        self.mandarin = mandarin
        self.cantonese = cantonese
    }

    func perform() async throws -> some IntentResult {
        guard let word = Store.shared.word(id: wordID) else { return .result() }
        var dialects: [Dialect] = []
        if mandarin { dialects.append(.mandarin) }
        if cantonese { dialects.append(.cantonese) }
        await Pronouncer.shared.speakAndWait(word, dialects)
        return .result()
    }
}

/// Grade the card right from the lock screen: Knew it / Unsure / Missed.
struct GradeCardIntent: AppIntent {
    static let title: LocalizedStringResource = "Grade card"
    static let isDiscoverable = false

    @Parameter(title: "Word")
    var wordID: String

    @Parameter(title: "Grade")
    var grade: Grade

    init() {}
    init(wordID: String, grade: Grade) {
        self.wordID = wordID
        self.grade = grade
    }

    func perform() async throws -> some IntentResult {
        Store.shared.reload()
        Store.shared.grade(wordID, grade)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
