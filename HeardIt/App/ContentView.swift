import SwiftUI

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    private func tearPage(_ w: Word?, _ p: Practice, _ size: TearOffView.Size, _ wd: CGFloat, _ ht: CGFloat) -> some View {
        TearOffView(word: w, settings: model.settings, practice: p, isNew: false, size: size)
            .frame(width: wd, height: ht).background(TearOffView.paper).clipShape(RoundedRectangle(cornerRadius: 22))
    }

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoTiles") { TileCheckView() } else { main }
        #else
        main
        #endif
    }

    @ViewBuilder private var main: some View {
        if ProcessInfo.processInfo.arguments.contains("-demoTearOff") {
            // screenshot hook: preview the tear-off widget at its real sizes
            let w = model.currentCard
            let practice = Store.shared.practice()
            VStack(spacing: 18) {
                tearPage(w, practice, .medium, 364, 170)
                tearPage(w, practice, .large, 364, 382)
                tearPage(w, practice, .small, 170, 170)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(hex: 0x3B6E8F))
        } else {
        ZStack(alignment: .bottom) {
            Theme.page.ignoresSafeArea()
            // All three pages stay alive (scroll positions survive) and dissolve through
            // a soft blur: the new page settles in from a hair larger, the old one lifts away.
            ZStack {
                page(0) { TodayView() }
                page(1) { WordsView() }
                page(2) { SettingsView() }
            }
            TabBar(selection: $model.selectedTab)
            if model.showOnboarding {
                OnboardingView().transition(.opacity.combined(with: .scale(scale: 1.015)))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: model.showOnboarding)
        .foregroundStyle(Theme.ink)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func page<V: View>(_ i: Int, @ViewBuilder _ content: () -> V) -> some View {
        let on = model.selectedTab == i
        return content()
            .opacity(on ? 1 : 0)
            .blur(radius: on || reduceMotion ? 0 : 8)
            .scaleEffect(on || reduceMotion ? 1 : 1.015)
            .allowsHitTesting(on)
            .accessibilityHidden(!on)
            .zIndex(on ? 1 : 0)
    }
}

struct TabBar: View {
    @Binding var selection: Int
    private let tabs = ["Today", "Words", "Settings"]
    @Namespace private var underline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    guard selection != i else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.9)) {
                        selection = i
                    }
                } label: {
                    Text(tabs[i])
                        .font(Theme.serif(15)).tracking(2)
                        .foregroundStyle(selection == i ? Theme.ink : Theme.muted)
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            if selection == i {
                                Rectangle().fill(Theme.ink).frame(height: 1)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(selection == i ? .isSelected : [])
            }
        }
        .padding(.horizontal, 34)
        .padding(.bottom, 4)
        .padding(.top, 8)
        .background(Theme.page.ignoresSafeArea(edges: .bottom))
    }
}

/// The app's mark, top left: the brush 中 in blue, no ring and no background,
/// so it sinks into the poster when the oversized brush runs under it.
struct Seal: View {
    /// true: just the blue brush 中, no tile (every page). false: the red app-icon tile.
    var plain = true

    var body: some View {
        // the app icon in miniature: paper-white brush 中 at 80.9% on the red tile
        Text("中")
            .font(Theme.brush(33))
            .foregroundStyle(plain ? Theme.blue : Color(hex: 0xF4F0E6))
            .frame(width: 32, height: 32)
            .background(plain ? .clear : Theme.red, in: RoundedRectangle(cornerRadius: 32 * 0.2237, style: .continuous))
            .accessibilityLabel("Hear to Read")
    }
}

// MARK: - Today

enum CardPhase: Equatable {
    case question
    /// tapped: zoomed into the poster with readings and meaning, waiting for a swipe
    case revealed
    case answer(Grade)
    case leaving(Grade)
}

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var dragX: CGFloat = 0
    @State private var dragY: CGFloat = 0
    @State private var phase: CardPhase = .question
    @State private var fits: [String: Brush.Fit] = [:]
    @State private var holdTask: Task<Void, Never>?
    @State private var reveal: CGFloat = 0
    @State private var press: CGFloat = 0
    /// 0 → 1 as a graded card lifts away and the next one settles in
    @State private var exit: CGFloat = 0
    @State private var exitDir: CGFloat = 1
    /// 0 → 1: the next card settling in underneath, on its own quicker curve
    @State private var incoming: CGFloat = 0
    @State private var pastLine = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var settings: AppSettings { model.settings }

    var body: some View {
        let current = model.currentCard
        let next = model.upNext.first
        ZStack {
            if let current {
                if let next, exit > 0 {
                    card(next, zoom: 0, reveal: 0, press: 0, stamp: nil, amount: 0, overhang: false)
                        .opacity(Double(incoming))
                        .scaleEffect(0.96 + 0.04 * incoming)
                }
                card(current, zoom: zoom, reveal: reveal, press: press, stamp: stampKind, amount: stampAmount)
                    // graded: slides straight off past the poster's overhang, no shrink, no fade
                    .offset(x: dragX * 0.8 + exitDir * (reduceMotion ? 0 : UIScreen.main.bounds.width * 2.4) * exit, y: dragY * 0.15)
                    .rotationEffect(.radians(Double(dragX / 390 * 0.1)), anchor: UnitPoint(x: 0.5, y: 0.6))
                    .opacity(reduceMotion ? Double(1 - exit) : 1)
                    // a new word is a new card: it never inherits the old one's slide
                    .id(current.id)
                    .gesture(drag(current))
                    .onTapGesture {
                        switch phase {
                        case .question: show(current)
                        case .revealed: hide()
                        case .answer: leave(current)
                        case .leaving: break
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityText(current))
                    .accessibilityHint("Tap to see the reading and meaning. Swipe right if you knew it, left if you did not.")
                    .accessibilityActions {
                        Button("Show answer") { show(current) }
                        Button("Knew it") { grade(current, .knew) }
                        Button("Missed") { grade(current, .missed) }
                    }
                controls(current)
            } else {
                DoneView()
            }
            header
        }
        .task(id: fitKey(current, next)) { await computeFits([current].compactMap { $0 } + Array(model.upNext.prefix(4))) }
        .onAppear {
            // screenshot hooks: launch with -demoAnswer or -demoPanel
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-demoAnswer") { phase = .revealed; reveal = 1 }
            if args.contains("-demoStamp") { phase = .answer(.knew); reveal = 1; press = 1 }
            if let i = args.firstIndex(of: "-demoWord"), i + 1 < args.count { model.focusedID = args[i + 1] }
            if args.contains("-demoPanel") { model.updateSettings { $0.cardStyle = .panel } }
            if args.contains("-demoPoster") { model.updateSettings { $0.cardStyle = .poster } }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack {
            HStack {
                Seal()
                Spacer()
                // golden box: 5 pt top and bottom, 8 pt each side (8 / 5 ≈ φ);
                // the trailing -2 cancels the letter-spacing after the last letter so the text sits centred
                Text("\(model.store.queue().count) left")
                    .font(Theme.serif(15)).tracking(2).foregroundStyle(Theme.muted)
                    .padding(.trailing, -2)
                    .padding(.vertical, 5).padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Theme.page))
            }
            .padding(.horizontal, 26).padding(.top, 8)
            Spacer()
        }
    }

    private func controls(_ word: Word) -> some View {
        VStack(spacing: 16) {
            Spacer()
            CircleButton(label: "Hear it", border: Theme.ink) { model.speak(word, model.defaultDialects) } content: {
                Image(systemName: "speaker.wave.2").font(.system(size: 18))
            }
            HStack(spacing: 36) {
                CircleButton(label: "Missed", border: Theme.line) { grade(word, .missed) } content: {
                    Image(systemName: "xmark").font(.system(size: 18, weight: .medium))
                }
                CircleButton(label: "Not sure", border: Theme.line) { grade(word, .unsure) } content: {
                    Image(systemName: "minus").font(.system(size: 18, weight: .medium))
                }
                Button { grade(word, .knew) } label: {
                    Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 55, height: 55)
                        .background(Circle().fill(Theme.red))
                        .background(Circle().fill(Theme.page).padding(-4))
                }
                .accessibilityLabel("Got it")
            }
        }
        .padding(.bottom, 64)
        .opacity(phaseIsAnswer || phaseIsLeaving ? 0 : 1)
        .animation(.easeOut(duration: 0.2), value: phaseIsAnswer)
    }

    @ViewBuilder
    private func card(_ word: Word, zoom: CGFloat, reveal: CGFloat, press: CGFloat, stamp: Grade?, amount: CGFloat, overhang: Bool = true) -> some View {
        let hanzi = word.hanzi(settings.script)
        if settings.cardStyle == .poster {
            PosterCard(hanzi: hanzi, lines: lines(word), fit: fits[key(word)] ?? .resting,
                       zoom: zoom, reveal: reveal, press: press, stamp: stamp, stampAmount: amount,
                       overhang: overhang ? PosterCard.overhang : 0)
        } else {
            PanelCard(word: word, hanzi: hanzi, readings: word.labelledReadings(settings.readings),
                      reveal: reveal, press: press, stamp: stamp, stampAmount: amount)
        }
    }

    // MARK: State helpers

    private var phaseIsAnswer: Bool { if case .answer = phase { return true }; return false }
    private var phaseIsLeaving: Bool { if case .leaving = phase { return true }; return false }

    /// 0 shows the whole word (the question); 1 is the oversized poster (the answer).
    /// The size never changes while a card is in your hand or on its way out:
    /// it slides, and the poster draws past the screen edges so it slides out whole.
    private var zoom: CGFloat {
        switch phase {
        case .question: return 0
        case .revealed, .answer, .leaving: return 1
        }
    }

    private var stampKind: Grade? {
        switch phase {
        case .question, .revealed: return dragX > 0 ? .knew : (dragX < 0 ? .missed : nil)
        case .answer(let g), .leaving(let g): return g == .unsure ? nil : g
        }
    }

    private var stampAmount: CGFloat {
        switch phase {
        case .question, .revealed: return min(1, abs(dragX) / 110)
        default: return 1
        }
    }

    private func lines(_ w: Word) -> [Brush.Line] {
        Brush.posterLines(hanzi: w.hanzi(settings.script), readings: w.labelledReadings(settings.readings), meaning: w.meaning)
    }

    private func key(_ w: Word) -> String { "\(w.id)|\(settings.script.rawValue)|\(settings.readings.rawValue)" }
    private func fitKey(_ a: Word?, _ b: Word?) -> String { [a, b].compactMap { $0.map(key) }.joined(separator: ",") }

    private func computeFits(_ words: [Word]) async {
        for w in words where fits[key(w)] == nil {
            let k = key(w)
            if let cached = FitCache.shared.get(k) { fits[k] = cached; continue }
            fits[k] = await FitCache.shared.fit(key: k, text: w.hanzi(settings.script), lines: lines(w))
        }
    }

    /// Never animate toward a placeholder: make sure this word's fit is known first.
    private func ensureFit(_ w: Word) async {
        let k = key(w)
        if fits[k] == nil { fits[k] = await FitCache.shared.fit(key: k, text: w.hanzi(settings.script), lines: lines(w)) }
    }

    private var currentFitReady: Bool { model.currentCard.map { fits[key($0)] != nil } ?? false }

    private func accessibilityText(_ w: Word) -> String {
        if phase != .question { return "\(w.hanzi(settings.script)), \(w.labelledReadings(settings.readings)), \(w.meaning)" }
        return w.hanzi(settings.script)
    }

    // MARK: Gestures

    private func drag(_ word: Word) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                guard phase == .question || phase == .revealed else { return }
                dragX = v.translation.width; dragY = v.translation.height
                let past = abs(dragX) > 110
                if past != pastLine { pastLine = past; if past { Haptics.tick() } }
            }
            .onEnded { v in
                guard phase == .question || phase == .revealed else { return }
                let x = v.translation.width + v.predictedEndTranslation.width * 0.2
                if x > 110 { grade(word, .knew) }
                else if x < -110 { grade(word, .missed) }
                else { withAnimation(.spring(duration: 0.3)) { dragX = 0; dragY = 0 } }
            }
    }

    /// Tap: zoom into the poster and show the readings and meaning. No grade yet.
    private func show(_ word: Word) {
        guard phase == .question else { return }
        if fits[key(word)] == nil {
            Task { @MainActor in await ensureFit(word); show(word) }
            return
        }
        Haptics.tick()
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) { phase = .revealed; reveal = 1 }
        } else {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) { phase = .revealed }
            withAnimation(.easeOut(duration: 0.9).delay(0.12)) { reveal = 1 }
        }
        if settings.speakOnReveal { model.speak(word, model.defaultDialects) }
    }

    /// Tap again: back out to the whole word.
    private func hide() {
        guard phase == .revealed else { return }
        withAnimation(.easeOut(duration: 0.25)) { reveal = 0 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) { phase = .question }
    }

    /// Swipe or button. From the revealed poster: the stamp presses and the card goes.
    /// Straight from the question: the answer shows for a beat first.
    private func grade(_ word: Word, _ g: Grade) {
        pastLine = false
        switch phase {
        case .revealed:
            g == .missed ? Haptics.firm() : Haptics.success()
            phase = .answer(g)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { press = 1 }
            holdTask?.cancel()
            holdTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.45))
                if !Task.isCancelled { leave(word) }
            }
        case .question:
            if fits[key(word)] == nil {
                Task { @MainActor in await ensureFit(word); grade(word, g) }
                return
            }
            g == .missed ? Haptics.firm() : Haptics.success()
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.25)) { phase = .answer(g); dragX = 0; dragY = 0; reveal = 1; press = 1 }
            } else {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) { phase = .answer(g); dragX = 0; dragY = 0 }
                withAnimation(.easeOut(duration: 0.9).delay(0.12)) { reveal = 1; press = 1 }
            }
            if settings.speakOnReveal { model.speak(word, model.defaultDialects) }
            holdTask?.cancel()
            holdTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                if !Task.isCancelled { leave(word) }
            }
        default: break
        }
    }

    private func leave(_ word: Word) {
        guard case .answer(let g) = phase else { return }
        holdTask?.cancel()
        exitDir = g == .missed ? -1 : 1
        phase = .leaving(g)
        // the card slides off in the swipe direction: a quick start, then gone
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.4).delay(0.08)) { incoming = 1 }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .timingCurve(0.4, 0, 0.9, 0.6, duration: 0.5)) { exit = 1 } completion: {
            model.grade(word, g)
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { exit = 0; incoming = 0; dragX = 0; dragY = 0; reveal = 0; press = 0; phase = .question }
        }
    }
}

enum Haptics {
    static func tick() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7) }
    static func firm() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

struct CircleButton<Content: View>: View {
    let label: String
    let border: Color
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .foregroundStyle(Theme.ink)
                .frame(width: 55, height: 55)
                .background(Circle().fill(Theme.page))
                .overlay(Circle().stroke(border, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Poster card

/// The oversized brush card.
/// `zoom`: 0 = the whole word (the question), 1 = the fitted poster (the answer).
/// `reveal`: 0 → 1 after you let go: the printed word glides up into the answer
/// and turns white on the blue, then the readings and meaning settle in one by one.
struct PosterCard: View, Animatable {
    let hanzi: String
    let lines: [Brush.Line]
    let fit: Brush.Fit
    var zoom: CGFloat
    var reveal: CGFloat
    var press: CGFloat
    let stamp: Grade?
    var stampAmount: CGFloat
    /// the card that slides gets the overhang; the one waiting underneath doesn't need it
    var overhang: CGFloat = PosterCard.overhang

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(zoom, reveal), AnimatablePair(press, stampAmount)) }
        set { zoom = newValue.first.first; reveal = newValue.first.second; press = newValue.second.first; stampAmount = newValue.second.second }
    }

    /// How far the canvas reaches past each side of the screen, so the oversized brush
    /// is drawn whole and a card sliding sideways never shows a hard cropped edge.
    static let overhang: CGFloat = 420

    var body: some View {
        Canvas { ctx, size in
            let pad = overhang
            let k = (size.width - 2 * pad) / Brush.design.width
            ctx.translateBy(x: pad, y: (size.height - Brush.design.height * k) / 2)
            ctx.scaleBy(x: k, y: k)

            let whole = Brush.wholeView(hanzi)
            let e = smooth(zoom)
            let s = whole.size + (fit.size - whole.size) * e
            let cy = whole.centerY + (Brush.restingCenterY - whole.centerY) * e
            let brush = Path(Brush.path(hanzi, size: s, dx: fit.dx * e, dy: fit.dy * e, centerY: cy))
            let stroke = StrokeStyle(lineWidth: s * (0.02 + (Brush.strokeRatio - 0.02) * e), lineJoin: .round)
            ctx.fill(brush, with: .color(Theme.blue))
            ctx.stroke(brush, with: .color(Theme.blue), style: stroke)

            // Each line is ink on paper and white on the brush, so nothing ever sits unreadable.
            func knockout(_ line: Brush.Line, opacity: CGFloat, dy: CGFloat, outside: Color) {
                guard opacity > 0.01 else { return }
                var l = line; l.centerY += dy
                let text = Path(Brush.textPath([l]))
                var c = ctx; c.opacity = Double(opacity)
                c.fill(text, with: .color(outside))
                c.drawLayer { layer in
                    layer.clipToLayer { m in m.fill(brush, with: .color(.black)); m.stroke(brush, with: .color(.black), style: stroke) }
                    layer.fill(text, with: .color(.white))
                }
            }
            let r = smooth(reveal)
            // the printed word travels from under the brush (question) to the top of the answer
            var word = lines[0]; word.centerY = Brush.questionTextY + (lines[0].centerY - Brush.questionTextY) * r
            knockout(word, opacity: 1, dy: 0, outside: r > 0.5 ? Theme.blue : Theme.ink)
            // readings, then meaning: staggered, drifting up into place
            let a1 = stage(r, from: 0.35, to: 0.75), a2 = stage(r, from: 0.55, to: 0.95)
            knockout(lines[1], opacity: a1, dy: (1 - a1) * 13, outside: Theme.blue)
            knockout(lines[2], opacity: a2, dy: (1 - a2) * 13, outside: Theme.blue)
            drawStamp(&ctx, stamp, stampAmount, press: press)
        }
        .padding(.horizontal, -overhang)
        .ignoresSafeArea()
    }

    private func smooth(_ t: CGFloat) -> CGFloat { let x = min(1, max(0, t)); return x * x * (3 - 2 * x) }
    private func stage(_ t: CGFloat, from a: CGFloat, to b: CGFloat) -> CGFloat { smooth((t - a) / (b - a)) }
}

/// Red ✓ for knew it, ink ✕ for missed, fading in as you drag.
func drawStamp(_ ctx: inout GraphicsContext, _ kind: Grade?, _ amount: CGFloat, press: CGFloat = 1) {
    guard let kind, kind != .unsure, amount > 0 else { return }
    var c = ctx
    c.opacity = Double(min(1, amount))
    let knew = kind == .knew
    c.translateBy(x: knew ? 96 : 294, y: 236)
    c.rotate(by: .radians(knew ? -0.2 : 0.2))
    // held large while you drag, pressed down like a chop when you let go
    let scale = 1.32 - 0.32 * min(1, max(0, press))
    c.scaleBy(x: scale, y: scale)
    let ring = Path(ellipseIn: CGRect(x: -40, y: -40, width: 80, height: 80))
    var mark = Path()
    if knew {
        c.fill(ring, with: .color(Theme.red))
        mark.move(to: CGPoint(x: -18, y: 2)); mark.addLine(to: CGPoint(x: -5, y: 15)); mark.addLine(to: CGPoint(x: 20, y: -14))
        c.stroke(mark, with: .color(.white), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
    } else {
        c.fill(ring, with: .color(Theme.page)); c.stroke(ring, with: .color(Theme.ink), lineWidth: 3)
        mark.move(to: CGPoint(x: -15, y: -15)); mark.addLine(to: CGPoint(x: 15, y: 15))
        mark.move(to: CGPoint(x: 15, y: -15)); mark.addLine(to: CGPoint(x: -15, y: 15))
        c.stroke(mark, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 5, lineCap: .round))
    }
}

// MARK: - Panel card

/// R5c: the Chinese lives in the blue panel, the English meaning on the paper below.
struct PanelCard: View, Animatable {
    let word: Word
    let hanzi: String
    let readings: String
    var reveal: CGFloat
    var press: CGFloat
    let stamp: Grade?
    var stampAmount: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(reveal, AnimatablePair(press, stampAmount)) }
        set { reveal = newValue.first; press = newValue.second.first; stampAmount = newValue.second.second }
    }

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / Brush.design.width
            ctx.translateBy(x: 0, y: (size.height - Brush.design.height * k) / 2)
            ctx.scaleBy(x: k, y: k)
            ctx.fill(Path(CGRect(x: 26, y: 123, width: 338, height: 338)), with: .color(Theme.blue))
            let n = CGFloat(max(1, hanzi.count))
            let s = min(146, 300 / n)
            for (i, ch) in hanzi.enumerated() {
                let x = 195 + (CGFloat(i) - (n - 1) / 2) * s
                ctx.fill(Path(Brush.path(String(ch), size: s, centerY: 250, centerX: x)), with: .color(Theme.page))
            }
            ctx.fill(Path(Brush.textPath([Brush.Line(text: hanzi, size: 39, centerY: 362, kern: 8)])), with: .color(Theme.page))
            let r = min(1, max(0, reveal))
            var c1 = ctx; c1.opacity = Double(r)
            c1.fill(Path(Brush.textPath([Brush.Line(text: readings, size: Brush.width(readings, size: 24) > 320 ? 15 : 24,
                                                    centerY: 414 + (1 - r) * 13, kern: 0)])), with: .color(Theme.page))
            // the English sits on the paper below
            let e = r
            var c2 = ctx; c2.opacity = Double(e)
            c2.fill(Path(Brush.textPath([Brush.Line(text: word.meaning, size: 24, centerY: 507 + (1 - e) * 8, kern: 1)])), with: .color(Theme.ink))
            drawStamp(&ctx, stamp, stampAmount, press: press)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Done

struct DoneView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 21) {
            Text("好了").font(Theme.brush(146)).foregroundStyle(Theme.blue)
            Text("Done for today").font(Theme.serif(24))
            Text("New cards come back tomorrow.").font(Theme.serif(15)).tracking(1).foregroundStyle(Theme.muted)
        }
    }
}

// MARK: - Words

struct WordsView: View {
    @EnvironmentObject private var model: AppModel
    /// A base deck's raw value, or "topic:<id>".
    @State private var tab = Deck.menu.rawValue
    @State private var adding = false
    @Namespace private var underline

    private var tabs: [(id: String, title: String)] {
        Deck.base.map { ($0.rawValue, $0.title) } + model.store.activeTopics.map { ("topic:" + $0.id, $0.title) }
    }

    private var shown: [Word] {
        if tab.hasPrefix("topic:") {
            let id = String(tab.dropFirst(6))
            return model.store.words.filter { $0.topic == id }
        }
        return model.store.words.filter { $0.deck.rawValue == tab }
    }

    var body: some View {
        ScrollView {
            // lazy: Core holds 3,000+ rows and this page stays alive behind Today
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack { Seal(); Spacer()
                    Text("\(model.store.words.count) words").font(Theme.serif(15)).tracking(2).foregroundStyle(Theme.muted) }
                    .padding(.top, 8)
                Text("词表").font(Theme.brush(55)).padding(.top, 21)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 26) {
                        ForEach(tabs, id: \.id) { t in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { tab = t.id }
                            } label: {
                                Text(t.title).font(Theme.serif(15)).tracking(1)
                                    .foregroundStyle(tab == t.id ? Theme.ink : Theme.muted)
                                    .padding(.bottom, 3)
                                    .overlay(alignment: .bottom) {
                                        if tab == t.id {
                                            Rectangle().fill(Theme.ink).frame(height: 1)
                                                .matchedGeometryEffect(id: "tab", in: underline)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        Button { adding = true } label: {
                            Label("Topic", systemImage: "plus").font(Theme.serif(15)).tracking(1)
                                .foregroundStyle(Theme.blue).padding(.bottom, 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add a topic")
                    }
                    .padding(.horizontal, 26)
                }
                .padding(.horizontal, -26)
                .padding(.vertical, 21)
                Rectangle().fill(Theme.line).frame(height: 1)
                ForEach(shown) { WordRow(word: $0) }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 89)
            .id(model.version)
        }
        .sheet(isPresented: $adding) { TopicPickerView() }
        .onChange(of: model.settings.topics) { _, on in
            // a topic just switched off: fall back to a base deck
            if tab.hasPrefix("topic:"), !on.contains(String(tab.dropFirst(6))) { tab = Deck.menu.rawValue }
        }
    }
}

struct WordRow: View {
    @EnvironmentObject private var model: AppModel
    let word: Word

    var body: some View {
        let state = model.store.state(for: word.id)
        let known = state?.knownByEar ?? false
        let level = dots(state)
        HStack(spacing: 13) {
            Text(word.hanzi(model.settings.script)).font(Theme.serif(24))
            Text(word.meaning).font(Theme.serif(15)).foregroundStyle(Theme.muted).lineLimit(1)
            Spacer(minLength: 8)
            Button { model.setKnownByEar(word, !known) } label: {
                Image(systemName: known ? "ear.fill" : "ear").foregroundStyle(known ? Theme.ink : Theme.line)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(known ? "Known by ear" : "Mark as known by ear")
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(i < level ? Theme.ink : .clear)
                        .overlay(Circle().stroke(i < level ? Theme.ink : Theme.line, lineWidth: 1))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityLabel("\(level) of 3")
        }
        .frame(minHeight: 55)
        .contentShape(Rectangle())
        .onTapGesture { model.speak(word, model.defaultDialects) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func dots(_ s: ReviewState?) -> Int {
        guard let s, !s.isNew else { return 0 }
        let m = Scheduler.mastery(s, now: .now)
        return m > 0.9 ? 3 : m > 0.66 ? 2 : 1
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        let s = model.settings
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Seal().padding(.top, 8)
                Text("设定").font(Theme.brush(55)).padding(.vertical, 21)
                Rectangle().fill(Theme.line).frame(height: 1)
                row("Card style") {
                    Segmented(options: CardStyle.allCases.map { ($0, $0.title) }, selection: s.cardStyle) { v in
                        model.updateSettings { $0.cardStyle = v }
                    }
                }
                row("Characters") {
                    Segmented(options: [(Script.simplified, "简"), (Script.traditional, "繁")], selection: s.script, size: 24) { v in
                        model.updateSettings { $0.script = v }
                    }
                }
                row("普 Mandarin pinyin") { Toggle("", isOn: readingBinding(mandarin: true)).labelsHidden().tint(Theme.ink) }
                row("粵 Cantonese jyutping") { Toggle("", isOn: readingBinding(mandarin: false)).labelsHidden().tint(Theme.ink) }
                row("Say it after I swipe") {
                    Toggle("", isOn: Binding(get: { model.settings.speakOnReveal },
                                             set: { v in model.updateSettings { $0.speakOnReveal = v } })).labelsHidden().tint(Theme.ink)
                }
                row("New words a day") {
                    HStack(spacing: 13) {
                        CircleStep(symbol: "minus") { model.updateSettings { $0.newPerDay = max(3, $0.newPerDay - 1) } }
                        Text("\(s.newPerDay)").font(Theme.serif(24)).monospacedDigit().frame(minWidth: 30)
                        CircleStep(symbol: "plus") { model.updateSettings { $0.newPerDay = min(30, $0.newPerDay + 1) } }
                    }
                }
                Text("Decks").font(Theme.serif(15)).tracking(2).foregroundStyle(Theme.muted).padding(.top, 34).padding(.bottom, 8)
                Rectangle().fill(Theme.line).frame(height: 1)
                ForEach(Deck.base) { d in
                    row(d.title) {
                        Toggle("", isOn: Binding(get: { !model.settings.disabledDecks.contains(d) }, set: { on in
                            model.updateSettings { st in
                                st.disabledDecks.removeAll { $0 == d }
                                if !on { st.disabledDecks.append(d) }
                            }
                        })).labelsHidden().tint(Theme.ink)
                    }
                }
                Text("Topics").font(Theme.serif(15)).tracking(2).foregroundStyle(Theme.muted).padding(.top, 34).padding(.bottom, 8)
                Rectangle().fill(Theme.line).frame(height: 1)
                ForEach(model.store.topics) { t in TopicToggleRow(topic: t) }
                Button("Change why I'm learning") { model.updateSettings { $0.onboarded = false } }
                    .font(Theme.serif(15)).tracking(1).foregroundStyle(Theme.blue)
                    .padding(.top, 21)
                Button("Reset progress") { confirmReset = true }
                    .font(Theme.serif(15)).tracking(1).foregroundStyle(Theme.red)
                    .padding(.top, 34)
                Text("For more natural voices, download an Enhanced Chinese (Mainland) and Cantonese (Hong Kong) voice in Settings > Accessibility > Spoken Content > Voices.")
                    .font(Theme.serif(13)).foregroundStyle(Theme.muted).padding(.top, 21)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 89)
        }
        .confirmationDialog("Reset all progress? This can't be undone.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { model.resetProgress() }
        }
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack {
            Text(title).font(Theme.serif(15)).tracking(1)
            Spacer()
            control()
        }
        .frame(minHeight: 55)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    /// Two toggles stand in for the reading mode; at least one stays on.
    private func readingBinding(mandarin: Bool) -> Binding<Bool> {
        Binding(
            get: {
                let r = model.settings.readings
                return r == .both || r == (mandarin ? .mandarin : .cantonese)
            },
            set: { on in
                model.updateSettings { s in
                    let m = mandarin ? on : (s.readings != .cantonese)
                    let c = mandarin ? (s.readings != .mandarin) : on
                    s.readings = (m && c) ? .both : m ? .mandarin : c ? .cantonese : s.readings
                }
            }
        )
    }
}

struct Segmented<T: Hashable>: View {
    let options: [(T, String)]
    let selection: T
    var size: CGFloat = 15
    let pick: (T) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { i in
                let (value, title) = options[i]
                Button { pick(value) } label: {
                    Text(title).font(Theme.serif(size)).tracking(size < 20 ? 1 : 0)
                        .padding(.horizontal, 13).padding(.vertical, size < 20 ? 6 : 0)
                        .foregroundStyle(value == selection ? Theme.page : Theme.ink)
                        .background(value == selection ? Theme.ink : .clear)
                }
                .accessibilityAddTraits(value == selection ? .isSelected : [])
            }
        }
        .overlay(Rectangle().stroke(Theme.ink, lineWidth: 1))
    }
}

struct CircleStep: View {
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
        }
        .accessibilityLabel(symbol == "plus" ? "More" : "Fewer")
    }
}
