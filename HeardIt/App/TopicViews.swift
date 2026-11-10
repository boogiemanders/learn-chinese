import SwiftUI

// MARK: - First screen: why are you learning?

/// 初心, "the heart you started with". Picks the goal decks.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var picked: Set<String> = []
    @State private var shown = false

    private let columns = [GridItem(.flexible(), spacing: 13), GridItem(.flexible(), spacing: 13)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Seal().padding(.top, 8)
                Text("初心").font(Theme.brush(110)).foregroundStyle(Theme.blue)
                    .padding(.top, 21)
                    .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 13)
                Text("Why are you learning Chinese?").font(Theme.serif(24)).padding(.top, 8)
                Text("Pick every reason that fits. Your decks follow.")
                    .font(Theme.serif(15)).tracking(1).foregroundStyle(Theme.muted).padding(.top, 8)

                LazyVGrid(columns: columns, spacing: 13) {
                    ForEach(Goal.all) { g in
                        GoalChip(goal: g, on: picked.contains(g.id)) {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                if picked.contains(g.id) { picked.remove(g.id) } else { picked.insert(g.id) }
                            }
                        }
                    }
                }
                .padding(.top, 34)

                Text("Change these any time in Settings.")
                    .font(Theme.serif(13)).foregroundStyle(Theme.muted).padding(.top, 21)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    model.finishOnboarding(goals: picked)
                } label: {
                    Text("Begin").font(Theme.serif(17)).tracking(3)
                        .foregroundStyle(Theme.page)
                        .frame(maxWidth: .infinity, minHeight: 55)
                        .background(Theme.ink)
                }
                .buttonStyle(.plain)
                .padding(.top, 34)

                Button("Skip for now") { model.finishOnboarding(goals: []) }
                    .font(Theme.serif(15)).tracking(1).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity).padding(.top, 21)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 55)
        }
        .background(Theme.page.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.1)) { shown = true } }
    }
}

struct GoalChip: View {
    let goal: Goal
    let on: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            VStack(spacing: 5) {
                Text(goal.hanzi).font(Theme.brush(34))
                Text(goal.title).font(Theme.serif(13)).tracking(0.5)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(on ? Theme.page : Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 89)
            .background(on ? Theme.blue : .clear)
            .overlay(Rectangle().stroke(on ? Theme.blue : Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Pick topics (from Words)

struct TopicPickerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Seal()
                    Spacer()
                    Button("Done") { dismiss() }.font(Theme.serif(15)).tracking(1)
                }
                .padding(.top, 21)
                Text("专题").font(Theme.brush(55)).padding(.top, 21)
                Text("Pick the topics you want to talk about.").font(Theme.serif(24)).padding(.top, 8)
                Text("Each one adds its words to your daily cards.")
                    .font(Theme.serif(15)).tracking(1).foregroundStyle(Theme.muted).padding(.top, 8)
                    .padding(.bottom, 21)
                Rectangle().fill(Theme.line).frame(height: 1)
                ForEach(model.store.topics) { t in TopicToggleRow(topic: t) }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 55)
            .id(model.version)
        }
        .background(Theme.page.ignoresSafeArea())
        .foregroundStyle(Theme.ink)
    }
}

struct TopicToggleRow: View {
    @EnvironmentObject private var model: AppModel
    let topic: Topic

    var body: some View {
        HStack(spacing: 13) {
            Text(topic.hanzi).font(Theme.brush(28)).foregroundStyle(Theme.blue).frame(minWidth: 55, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title).font(Theme.serif(15)).tracking(1)
                Text("\(topic.words.count) words" + (topic.generated == true ? " · new" : ""))
                    .font(Theme.serif(13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { model.settings.topics.contains(topic.id) },
                                     set: { model.setTopic(topic, $0) }))
                .labelsHidden().tint(Theme.ink)
        }
        .frame(minHeight: 55)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

#if DEBUG
// MARK: - Debug: small-widget poster check (-demoTiles)

/// Draws the small Home Screen widget's poster for a spread of words (short, long,
/// many strokes, long meanings), the same way the widget does, to check every line
/// lands on blue. `-demoTiles 12` starts at the 12th word of the sample.
struct TileCheckView: View {
    private let words: [Word] = {
        let all = Store.shared.words
        let picks = ["厕所", "你好", "谢谢", "多少钱", "叉烧", "红烧", "凉拌", "买单", "出口", "麻婆豆腐", "一", "鬱", "身体好吗", "外婆", "心理学家", "岭南画派"]
        var out = picks.compactMap { p in all.first { $0.simplified == p } }
        out += all.filter { $0.meaning.count > 20 }.prefix(8)
        out += all.filter { $0.simplified.count >= 4 }.prefix(6)
        return out
    }()
    private let start: Int = {
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-demoTiles"), i + 1 < a.count { return Int(a[i + 1]) ?? 0 }
        return 0
    }()

    var body: some View {
        let shown = Array(words.dropFirst(start).prefix(12))
        LazyVGrid(columns: [GridItem(.fixed(170)), GridItem(.fixed(170))], spacing: 10) {
            ForEach(shown) { w in tile(w).frame(width: 170, height: 170).clipShape(RoundedRectangle(cornerRadius: 22)) }
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.gray.opacity(0.4))
    }

    private func tile(_ w: Word) -> some View {
        let lines = Brush.tileLines(hanzi: w.simplified, reading: w.pinyin.isEmpty ? w.jyutping : w.pinyin, meaning: w.shortMeaning)
        let fit = Brush.tileFit(text: w.simplified, lines: lines)
        let c = Brush.tileCenter
        let shape = BrushShape(text: w.simplified, size: fit.size, center: CGPoint(x: c.x + fit.dx, y: c.y + fit.dy), designSize: Brush.tile)
        let text = BrushTextShape(lines: lines, centerX: c.x, designSize: Brush.tile)
        return ZStack {
            Theme.page
            shape.fill(Theme.blue)
            text.fill(Theme.blue)
            text.fill(.white).mask(shape)
            Text(fit.coverage >= 0.999 ? "" : String(format: "%.0f%%", fit.coverage * 100))
                .font(.caption.bold()).foregroundStyle(.red).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(6)
        }
    }
}
#endif
