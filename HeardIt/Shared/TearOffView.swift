import SwiftUI

/// A tear-off almanac page for one word (no calendar in it). The word, its readings and
/// its English own the centre. The ruled side columns hold the almanac functions:
/// the day count and this week's practice, 宜 (where you'll meet it) and 忌 (its look-alike).
///
/// Every size comes from golden steps (φ) of the widget's own height, and each row
/// shares one centre line across all three columns.
struct TearOffView: View {
    let word: Word?
    let settings: AppSettings
    var practice: Practice = Practice()
    var isNew: Bool = false
    var size: Size = .medium

    enum Size { case small, medium, large }

    static let paper = Color(hex: 0xF4F1EA)
    private let ink = Theme.blue
    private static let φ = (1 + sqrt(5.0)) / 2

    var body: some View {
        GeometryReader { geo in
            if let w = word {
                switch size {
                case .small: small(w, geo.size)
                case .medium: medium(w, geo.size)
                case .large: large(w, geo.size)
                }
            } else {
                Text("All caught up").font(latin(13)).foregroundStyle(ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(ink)
    }

    // MARK: golden ladder

    private func step(_ h: CGFloat, _ n: Double) -> CGFloat { h / CGFloat(pow(Self.φ, n)) }

    // MARK: fonts (system faces, so nothing extra to license or bundle)

    private func cjk(_ s: CGFloat) -> Font { .system(size: s, weight: .black) }
    private func latin(_ s: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: s, weight: w).width(.condensed) }

    // MARK: pieces

    private func hanzi(_ w: Word) -> String { w.hanzi(settings.script) }

    private func readings(_ w: Word, size s: CGFloat) -> some View {
        let mando = w.pinyin.isEmpty ? (w.mandarinWord ?? "") : w.pinyin
        let showM = settings.readings != .cantonese && !mando.isEmpty
        let showC = settings.readings != .mandarin && !w.jyutping.isEmpty
        return HStack(spacing: s * 1.2) {
            if showM { tagged("普", mando.uppercased(), s) }
            if showC { tagged("粵", w.jyutping.uppercased(), s) }
        }
        .lineLimit(1).minimumScaleFactor(0.6)
    }

    private func tagged(_ tag: String, _ text: String, _ s: CGFloat) -> some View {
        HStack(spacing: s * 0.5) {
            Text(tag).font(cjk(s))
            Text(text).font(latin(s, .medium)).tracking(s * 0.16)
        }
    }

    private func bigWord(_ w: Word, size s: CGFloat, width: CGFloat) -> some View {
        let h = hanzi(w)
        let fit = min(s, width / CGFloat(max(h.count, 1)))
        return Text(h).font(cjk(fit)).lineLimit(1).minimumScaleFactor(0.5)
    }

    private func english(_ w: Word, size s: CGFloat) -> some View {
        Text(w.meaning.uppercased()).font(latin(s)).tracking(s * 0.055)
            .lineLimit(1).minimumScaleFactor(0.55)
    }

    private func ornament(_ name: String, _ s: CGFloat) -> some View {
        Image(name).renderingMode(.template).resizable().scaledToFit().frame(width: s, height: s)
    }

    /// The day count sits on the week grid's rows: 第 on the first row, the number across
    /// the middle rows, 天 on the last, so the two side columns line up row for row.
    private func dayCount(cell: CGFloat, rows: Int) -> some View {
        let mid = cell * CGFloat(rows - 2) + 3 * CGFloat(rows - 3)
        return VStack(spacing: 3) {
            Text("第").font(cjk(cell * 0.8)).frame(height: cell)
            Text("\(practice.days)").font(latin(min(mid * 0.95, cell * 2.6))).lineLimit(1).minimumScaleFactor(0.4)
                .frame(height: mid)
            Text("天").font(cjk(cell * 0.8)).frame(height: cell)
        }
    }

    private func week(cell: CGFloat, columns: Int) -> some View {
        let rows = stride(from: 0, to: 7, by: columns).map { Array($0..<min($0 + columns, 7)) }
        return VStack(spacing: 3) {
            ForEach(rows, id: \.self) { row in
                // a lone Sunday sits centred under the pairs
                HStack(spacing: 3) { ForEach(row, id: \.self) { dayCell($0, cell) } }
            }
        }
    }

    private func dayCell(_ i: Int, _ cell: CGFloat) -> some View {
        let done = practice.week[i]
        return Text(["一", "二", "三", "四", "五", "六", "日"][i]).font(cjk(cell * 0.68))
            .foregroundStyle(done ? Self.paper : ink)
            .frame(width: cell, height: cell)
            .background(done ? ink : .clear)
            .overlay { if !done && i == practice.today { Rectangle().stroke(ink, lineWidth: 1) } }
            .opacity(!done && i > practice.today ? 0.4 : 1)
    }

    /// The bordered almanac box: 宜 on the left, 忌 on the right.
    private func almanacBox(_ seal: String, _ text: String, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(seal).font(cjk(11))
            Text(text).font(latin(8, .medium)).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 2)
        .frame(width: width, height: height)
        .overlay(Rectangle().stroke(ink, lineWidth: 1.2))
    }

    /// 忌 names the look-alike; with none, the box says whether the word is new or a review.
    private func avoidBox(_ w: Word, width: CGFloat, height: CGFloat) -> some View {
        if let l = Almanac.avoid(hanzi(w)) {
            return almanacBox("忌", "\(l.char) \(l.pinyin.uppercased())", width: width, height: height)
        }
        return almanacBox(isNew ? "新" : "复", isNew ? "NEW" : "REVIEW", width: width, height: height)
    }

    private func columnRules(_ size: CGSize, col: CGFloat, margin: CGFloat) -> some View {
        ForEach([col, size.width - col], id: \.self) { x in
            Rectangle().frame(width: 1.5, height: size.height - 2 * margin)
                .position(x: x, y: size.height / 2)
        }
    }

    // MARK: medium (the main page)
    // 15.3 · 24.8 · 64.9 · 9.5 · 40.1 · 15.3 at 170 tall: margin, top row, word, gap, bottom row, margin.

    private func medium(_ w: Word, _ sz: CGSize) -> some View {
        let H = sz.height, W = sz.width
        let m = step(H, 5), row = step(H, 4), wordH = step(H, 2), gap = step(H, 6), band = step(H, 3)
        let cw = band, pad = gap, col = pad * 2 + cw
        let r1 = m + row / 2, r2 = m + row + wordH / 2, ruleY = m + row + wordH + gap, r3 = ruleY + band / 2
        let lx = col / 2, rx = W - col / 2, cx = W / 2, centreW = W - 2 * col - 2 * pad
        let good = Almanac.goodFor(w.deck)
        return ZStack {
            columnRules(sz, col: col, margin: m)
            ornament("plum", row).position(x: lx, y: r1)
            ornament("knot", row).position(x: rx, y: r1)
            readings(w, size: H * 0.059).frame(width: centreW).position(x: cx, y: r1)

            dayCount(cell: H * 0.076, rows: 4).frame(width: cw).position(x: lx, y: r2)
            bigWord(w, size: wordH, width: centreW).position(x: cx, y: r2)
            week(cell: H * 0.076, columns: 2).position(x: rx, y: r2)

            Rectangle().frame(width: W - 2 * col - 2 * pad, height: 1.5).position(x: cx, y: ruleY)

            almanacBox("宜", good.tag, width: cw, height: band * 0.9).position(x: lx, y: r3)
            english(w, size: H * 0.106).frame(width: centreW).position(x: cx, y: r3)
            avoidBox(w, width: cw, height: band * 0.9).position(x: rx, y: r3)
        }
    }

    // MARK: large: rule on H/φ, two rows beneath it

    private func large(_ w: Word, _ sz: CGSize) -> some View {
        let H = sz.height, W = sz.width
        let m = step(H, 6), row = step(H, 5), gap = step(H, 7), ruleY = H / CGFloat(Self.φ)
        let cw = W * 0.11, pad = W * 0.026, col = pad * 2 + cw
        let r1 = m + row / 2, r2 = (m + row + ruleY) / 2
        let band = (H - m - ruleY - gap) / 2, r3 = ruleY + band / 2, r4 = ruleY + band + gap + band / 2
        let lx = col / 2, rx = W - col / 2, cx = W / 2, centreW = W - 2 * col - 2 * pad
        let good = Almanac.goodFor(w.deck)
        return ZStack {
            columnRules(sz, col: col, margin: m)
            ornament("plum", row * 0.85).position(x: lx, y: r1)
            ornament("knot", row * 0.85).position(x: rx, y: r1)
            readings(w, size: H * 0.031).frame(width: centreW).position(x: cx, y: r1)

            dayCount(cell: H * 0.042, rows: 7).frame(width: cw).position(x: lx, y: r2)
            bigWord(w, size: H * 0.293, width: centreW).position(x: cx, y: r2)
            week(cell: H * 0.042, columns: 1).position(x: rx, y: r2)

            Rectangle().frame(width: centreW, height: 1.5).position(x: cx, y: ruleY)

            vertical(w.deck.label, size: 13).position(x: lx, y: r3)
            english(w, size: H * 0.058).frame(width: centreW).position(x: cx, y: r3)
            if w.traditional != w.simplified { traditionalBox(w).position(x: rx, y: r3) }

            almanacBox("宜", good.tag, width: cw, height: 36).position(x: lx, y: r4)
            Text(good.line).font(latin(10, .medium)).tracking(1.5).opacity(0.75)
                .lineLimit(1).minimumScaleFactor(0.6).frame(width: centreW).position(x: cx, y: r4)
            avoidBox(w, width: cw, height: 36).position(x: rx, y: r4)
        }
    }

    private func vertical(_ text: String, size s: CGFloat) -> some View {
        VStack(spacing: s * 0.2) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in Text(String(ch)).font(cjk(s)) }
        }
    }

    /// The other script's form in a ruled box, read top to bottom.
    private func traditionalBox(_ w: Word) -> some View {
        let other = settings.script == .simplified ? w.traditional : w.simplified
        return vertical(other, size: 15).padding(.horizontal, 4).padding(.vertical, 3)
            .overlay(Rectangle().stroke(ink, lineWidth: 1.2))
    }

    // MARK: small: centre only

    private func small(_ w: Word, _ sz: CGSize) -> some View {
        let H = sz.height, W = sz.width
        let m = step(H, 5), row = step(H, 4), wordH = step(H, 2), gap = step(H, 6), band = step(H, 3)
        let r1 = m + row / 2, r2 = m + row + wordH / 2, ruleY = m + row + wordH + gap, r3 = ruleY + band / 2
        let inner = W - 2 * m
        return ZStack {
            readings(w, size: H * 0.059).frame(width: inner).position(x: W / 2, y: r1)
            bigWord(w, size: wordH, width: inner).position(x: W / 2, y: r2)
            Rectangle().frame(width: inner - 2 * gap, height: 1.5).position(x: W / 2, y: ruleY)
            english(w, size: H * 0.1).frame(width: inner).position(x: W / 2, y: r3)
        }
    }
}
