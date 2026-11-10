import SwiftUI
import WidgetKit

struct CardEntry: TimelineEntry {
    let date: Date
    let word: Word?
    let settings: AppSettings
    var practice = Practice()
    var isNew = true
    /// Small Home Screen poster: the text block and the brush placed so all of it sits on blue.
    var tileLines: [Brush.Line] = []
    var tileFit: Brush.Fit?

    static let sample = CardEntry(
        date: .now,
        word: Word(id: "sample", simplified: "叉烧", traditional: "叉燒", pinyin: "chāshāo",
                   jyutping: "caa1 siu1", meaning: "barbecued pork", deck: .menu,
                   mandarinWord: nil, note: nil),
        settings: AppSettings(),
        practice: Practice(days: 128, week: [true, true, true, true, false, false, false], today: 4),
        isNew: false
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

    /// Rotate through the top of the queue every 30 minutes, so each glance at the
    /// lock screen shows one of the words that matter most right now.
    private func entries(now: Date) -> [CardEntry] {
        let store = Store.shared
        store.reload()
        let top = Array(store.queue(now: now).prefix(6))
        let practice = store.practice(now: now)
        guard !top.isEmpty else { return [CardEntry(date: now, word: nil, settings: store.settings, practice: practice)] }
        return top.enumerated().map { i, w in
            var e = CardEntry(date: now.addingTimeInterval(Double(i) * 30 * 60), word: w, settings: store.settings,
                              practice: practice, isNew: store.state(for: w.id)?.isNew ?? true)
            // usually measured ahead by the app (AppModel.prepareTiles); measured here only as a fallback
            if store.settings.cardStyle == .poster { (e.tileLines, e.tileFit) = Brush.tile(w, store.settings) }
            return e
        }
    }
}

/// Plain characters, pinyin and English. No buttons, no frills.
/// In poster mode a large brush sits behind the words.
struct CardWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CardEntry

    private var poster: Bool { entry.settings.cardStyle == .poster }

    var body: some View {
        Group {
            if let w = entry.word {
                switch family {
                case .accessoryInline: Text("\(hanzi(w)) \(reading(w)) · \(w.meaning)")
                case .accessoryCircular: circular(w)
                case .accessoryRectangular: rectangular(w)
                default: small(w)
                }
            } else {
                Text("All caught up").font(Theme.serif(13))
            }
        }
        .widgetURL(URL(string: "heardit://today"))
        .containerBackground(for: .widget) { family == .systemSmall ? Theme.page : Color.clear }
    }

    private func hanzi(_ w: Word) -> String { w.hanzi(entry.settings.script) }
    private func reading(_ w: Word) -> String { Brush.tileReading(w, entry.settings) }

    /// A soft brush ghost: iOS tints lock screen widgets one colour, so it can't be blue here.
    private func ghost(_ text: String, size: CGFloat, center: CGPoint, canvas: CGSize) -> some View {
        BrushShape(text: text, size: size, center: center, designSize: canvas)
            .fill(Color.white.opacity(0.24))
    }

    private func rectangular(_ w: Word) -> some View {
        ZStack(alignment: .leading) {
            AccessoryWidgetBackground()
            if poster { ghost(hanzi(w), size: 150, center: CGPoint(x: 150, y: 34), canvas: CGSize(width: 170, height: 72)) }
            VStack(alignment: .leading, spacing: 0) {
                Text(hanzi(w)).font(Theme.serif(20)).tracking(3)
                Text(reading(w)).font(Theme.serif(13)).lineLimit(1)
                Text(w.meaning).font(Theme.serif(13)).lineLimit(1)
            }
            .padding(.horizontal, 10)
        }
        .clipShape(ContainerRelativeShape())
    }

    private func circular(_ w: Word) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            if poster, let first = hanzi(w).first {
                ghost(String(first), size: 130, center: CGPoint(x: 36, y: 40), canvas: CGSize(width: 72, height: 72))
            }
            VStack(spacing: 0) {
                Text(hanzi(w)).font(Theme.serif(hanzi(w).count > 2 ? 12 : 15)).minimumScaleFactor(0.6)
                Text(reading(w)).font(Theme.serif(9)).lineLimit(1).minimumScaleFactor(0.7)
                Text(w.shortMeaning).font(Theme.serif(9)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(4)
        }
        .clipShape(Circle())
    }

    /// Home screen: full colour. The brush bleeds off the edges and is sized and placed
    /// (Brush.tileFit) so every line of text sits on blue and reads white.
    private func small(_ w: Word) -> some View {
        let (lines, fit) = entry.tileFit.map { (entry.tileLines, $0) } ?? Brush.tile(w, entry.settings)
        let c = Brush.tileCenter
        let shape = BrushShape(text: hanzi(w), size: fit.size, center: CGPoint(x: c.x + fit.dx, y: c.y + fit.dy), designSize: Brush.tile)
        let words = BrushTextShape(lines: lines, centerX: c.x, designSize: Brush.tile)
        return ZStack {
            if poster {
                shape.fill(Theme.blue)
                // any sliver the fit couldn't cover stays blue on paper, never white on paper
                words.fill(Theme.blue)
                words.fill(.white).mask(shape)
            } else {
                VStack(spacing: 6) {
                    Text(hanzi(w)).font(Theme.serif(34)).foregroundStyle(Theme.blue)
                    Text(reading(w)).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                    Text(w.meaning).font(Theme.serif(15)).foregroundStyle(Theme.muted).lineLimit(2).multilineTextAlignment(.center)
                }
            }
        }
    }
}

struct HeardItWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeardItCard", provider: CardProvider()) { entry in
            CardWidgetView(entry: entry)
        }
        .configurationDisplayName("Hear to Read word")
        .description("A Chinese word with its pinyin and meaning, on your lock screen or home screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall])
        .contentMarginsDisabled()
    }
}


// MARK: - Tear-off widget

struct TearOffHost: View {
    @Environment(\.widgetFamily) private var family
    let entry: CardEntry
    var body: some View {
        TearOffView(word: entry.word, settings: entry.settings, practice: entry.practice, isNew: entry.isNew,
                    size: family == .systemSmall ? .small : family == .systemLarge ? .large : .medium)
            .widgetURL(URL(string: "heardit://today"))
            .containerBackground(TearOffView.paper, for: .widget)
    }
}

struct TearOffWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HearToReadTearOff", provider: CardProvider()) { entry in
            TearOffHost(entry: entry)
        }
        .configurationDisplayName("Tear-off word")
        .description("One word a page, set like a Chinese almanac: readings, meaning, where you'll hear it, and your practice days.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct HeardItWidgetBundle: WidgetBundle {
    var body: some Widget {
        HeardItWidget()
        TearOffWidget()
    }
}
