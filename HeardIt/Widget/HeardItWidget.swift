import AppIntents
import SwiftUI
import WidgetKit

struct CardEntry: TimelineEntry {
    let date: Date
    let word: Word?
    let revealed: Bool
    let settings: AppSettings

    static let sample = CardEntry(
        date: .now,
        word: Word(id: "sample", simplified: "叉烧", traditional: "叉燒", pinyin: "chāshāo",
                   jyutping: "caa1 siu1", meaning: "char siu (BBQ pork)", deck: .menu,
                   mandarinWord: nil, note: nil),
        revealed: false,
        settings: AppSettings()
    )
}

struct CardProvider: TimelineProvider {
    func placeholder(in context: Context) -> CardEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> Void) {
        completion(context.isPreview ? .sample : entries(now: .now).first ?? .sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> Void) {
        let list = entries(now: .now)
        let refresh = list.last.map { $0.date.addingTimeInterval(30 * 60) } ?? .now.addingTimeInterval(30 * 60)
        completion(Timeline(entries: list, policy: .after(refresh)))
    }

    /// A flipped card stays put until graded. Otherwise rotate through the top
    /// of the queue every 30 minutes, so glances keep showing the most
    /// important words even without a tap.
    private func entries(now: Date) -> [CardEntry] {
        let store = Store.shared
        store.reload()
        let settings = store.settings
        if let current = store.currentCard(now: now), store.isRevealed(current.id) {
            return [CardEntry(date: now, word: current, revealed: true, settings: settings)]
        }
        let top = Array(store.queue(now: now).prefix(6))
        guard !top.isEmpty else { return [CardEntry(date: now, word: nil, revealed: false, settings: settings)] }
        return top.enumerated().map { index, word in
            CardEntry(date: now.addingTimeInterval(Double(index) * 30 * 60), word: word, revealed: false, settings: settings)
        }
    }
}

struct CardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CardEntry

    var body: some View {
        Group {
            if let word = entry.word {
                switch family {
                case .accessoryInline: inline(word)
                case .accessoryCircular: circular(word)
                case .accessoryRectangular: rectangular(word)
                default: small(word)
                }
            } else {
                Text("All caught up").font(.caption)
            }
        }
        .widgetURL(entry.word.map { URL(string: "heardit://word/\($0.id)")! })
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func hanzi(_ w: Word) -> String { w.hanzi(entry.settings.script) }

    private func inline(_ w: Word) -> some View {
        Text("\(hanzi(w)) · \(w.readings(entry.settings.readings))")
    }

    private func circular(_ w: Word) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(hanzi(w))
                .font(.system(size: hanzi(w).count > 2 ? 14 : 22, weight: .bold))
                .minimumScaleFactor(0.5)
        }
    }

    @ViewBuilder
    private func rectangular(_ w: Word) -> some View {
        if entry.revealed {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(hanzi(w)).font(.headline)
                    Text(w.readings(entry.settings.readings)).font(.caption2).lineLimit(1)
                }
                Text(w.meaning).font(.caption2).lineLimit(1)
                gradeButtons(w).font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Button(intent: RevealCardIntent(wordID: w.id)) {
                HStack {
                    Text(hanzi(w)).font(.title2.bold()).minimumScaleFactor(0.6)
                    Spacer(minLength: 4)
                    Text("Tap to reveal").font(.caption2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func small(_ w: Word) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(hanzi(w)).font(.largeTitle.bold()).minimumScaleFactor(0.5)
            if entry.revealed {
                Text(w.readings(entry.settings.readings)).font(.caption).lineLimit(2)
                Text(w.meaning).font(.caption2).lineLimit(2)
                Spacer(minLength: 0)
                gradeButtons(w).font(.body)
            } else {
                Spacer(minLength: 0)
                Button(intent: RevealCardIntent(wordID: w.id)) {
                    Label("Reveal", systemImage: "eye")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gradeButtons(_ w: Word) -> some View {
        HStack(spacing: 10) {
            Button(intent: SpeakWordIntent(wordID: w.id)) {
                Image(systemName: "speaker.wave.2").accessibilityLabel("Pronounce")
            }
            Button(intent: GradeCardIntent(wordID: w.id, grade: .missed)) {
                Image(systemName: "xmark").accessibilityLabel("Missed")
            }
            Button(intent: GradeCardIntent(wordID: w.id, grade: .unsure)) {
                Image(systemName: "questionmark").accessibilityLabel("Unsure")
            }
            Button(intent: GradeCardIntent(wordID: w.id, grade: .knew)) {
                Image(systemName: "checkmark").accessibilityLabel("Knew it")
            }
        }
        .buttonStyle(.plain)
    }
}

struct HeardItWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeardItCard", provider: CardProvider()) { entry in
            CardWidgetView(entry: entry)
        }
        .configurationDisplayName("Heard It card")
        .description("Flip and grade a Chinese word without opening the app.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall])
    }
}

@main
struct HeardItWidgetBundle: WidgetBundle {
    var body: some Widget {
        HeardItWidget()
    }
}
