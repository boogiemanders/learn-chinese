import CoreText
import SwiftUI
import UIKit

/// The poster card's geometry. Everything is laid out on a 390 × 844 design grid
/// (an iPhone 15/16/17 screen in points) and scaled to the real screen.
enum Brush {
    static let fontName = "ZhiMangXing-Regular"
    static let design = CGSize(width: 390, height: 844)
    static let phi: CGFloat = 0.618_033_988_7
    /// The brush starts at R8a2's 618 pt and may zoom one golden step further.
    static let minSize: CGFloat = 618
    static let maxSize: CGFloat = 618 * 1.618_033_988_7
    static let lineHeightRatio: CGFloat = 0.8
    static let strokeRatio: CGFloat = 0.055
    static let restingCenterY: CGFloat = 345
    /// Where the printed characters sit under the whole brush word (the question).
    static let questionTextY: CGFloat = 505

    // MARK: Font

    /// Covers traditional and Cantonese characters that Zhi Mang Xing (simplified GB2312 only) lacks.
    static let fallbackFontName = "LXGWWenKaiTC-Bold"

    private static let registered: Bool = {
        var found = false
        for name in ["ZhiMangXing-Regular", "LXGWWenKaiTC-Bold"] {
            for bundle in [Bundle.main, Bundle(for: BundleToken.self)] {
                if let url = bundle.url(forResource: name, withExtension: "ttf") {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                    found = true
                    break
                }
            }
        }
        return found
    }()

    static func ensureFont() { _ = registered }

    // MARK: Glyph outlines

    private static var glyphCache: [Character: CGPath] = [:]
    private static let lock = NSLock()

    /// One character's outline at size 1, centred on the origin (y grows down).
    /// Characters the brush font lacks (some traditional forms) fall back to a system font.
    static func unitGlyph(_ ch: Character) -> CGPath {
        lock.lock(); defer { lock.unlock() }
        if let p = glyphCache[ch] { return p }
        ensureFont()
        let str = String(ch)
        var font = CTFontCreateWithName(fontName as CFString, 1000, nil)
        var chars = Array(str.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        if !CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count) || glyphs[0] == 0 {
            // second brush: LXGW WenKai TC; last resort: whatever system font has it
            font = CTFontCreateWithName(fallbackFontName as CFString, 1000, nil)
            if !CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count) || glyphs[0] == 0 {
                font = CTFontCreateForString(font, str as CFString, CFRange(location: 0, length: chars.count))
                CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
            }
        }
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, [glyphs[0]], &advance, 1)
        let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
        var t = CGAffineTransform(a: 0.001, b: 0, c: 0, d: -0.001,
                                  tx: -advance.width / 2 * 0.001, ty: (ascent - descent) / 2 * 0.001)
        let path = CTFontCreatePathForGlyph(font, glyphs[0], &t) ?? CGMutablePath()
        glyphCache[ch] = path
        return path
    }

    /// The word stacked vertically at size `s`, its centre moved by (dx, dy).
    static func path(_ text: String, size s: CGFloat, dx: CGFloat = 0, dy: CGFloat = 0,
                     centerY: CGFloat = restingCenterY, centerX: CGFloat = 195) -> CGPath {
        let chars = Array(text)
        let n = CGFloat(chars.count), pitch = lineHeightRatio * s
        let out = CGMutablePath()
        for (i, ch) in chars.enumerated() {
            let y = centerY + dy + (CGFloat(i) - (n - 1) / 2) * pitch
            out.addPath(unitGlyph(ch), transform: CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: centerX + dx, ty: y))
        }
        return out
    }

    /// The size and centre that show the whole word on screen (used while swiping).
    static func wholeView(_ text: String) -> (size: CGFloat, centerY: CGFloat) {
        let n = CGFloat(max(1, text.count))
        return (min(0.7 * design.width, 0.45 * design.height / (lineHeightRatio * (n - 1) + 1)), 280)
    }

    // MARK: Text block

    struct Line: Hashable {
        var text: String
        var size: CGFloat
        var centerY: CGFloat
        var kern: CGFloat
        /// Which part of the answer it belongs to, for the staggered reveal:
        /// 0 the word, 1 the readings, 2 the meaning.
        var stage: Int = 0
    }

    static func serifFont(_ size: CGFloat) -> UIFont {
        if let songti = UIFont(name: "STSongti-SC-Regular", size: size) { return songti }
        let base = UIFont.systemFont(ofSize: size)
        return UIFont(descriptor: base.fontDescriptor.withDesign(.serif) ?? base.fontDescriptor, size: size)
    }

    /// The widest a poster line may be inside the 390-wide design.
    static let posterTextWidth: CGFloat = 340

    /// The poster's text: the characters, then the readings, then the meaning. Short words
    /// get one line of each, as before. Long ones (a line from the Dao De Jing) split the
    /// readings into a pinyin line and a jyutping line and wrap the meaning, shrinking only
    /// as far as needed, so nothing runs off the screen.
    static func posterLines(hanzi: String, readings: String, meaning: String) -> [Line] {
        let maxW = posterTextWidth
        var hanziSize: CGFloat = 39
        while hanziSize > 26, width(hanzi, size: hanziSize, kern: 8) > maxW { hanziSize -= 1 }

        // readings: one line if it fits, else one line per language, each wrapped if needed
        var readingRows: [String] = [readings], readingSize: CGFloat = 24
        if width(readings, size: 24) > maxW {
            readingSize = 18
            let parts = readings.components(separatedBy: " · ")
            readingRows = parts.flatMap { wrap($0, size: readingSize, width: maxW) }
        }
        // meaning: one line at 24 if it fits, else wrapped at 22, else smaller
        var meaningSize: CGFloat = 24
        var meaningRows = [meaning]
        if width(meaning, size: 24, kern: 1) > maxW {
            meaningSize = 22
            meaningRows = wrap(meaning, size: meaningSize, width: maxW, kern: 1)
            while meaningRows.count > 2, meaningSize > 16 {
                meaningSize -= 1
                meaningRows = wrap(meaning, size: meaningSize, width: maxW, kern: 1)
            }
        }

        var out = [Line(text: hanzi, size: hanziSize, centerY: 418, kern: 8, stage: 0)]
        var y: CGFloat = 472
        for (i, r) in readingRows.enumerated() {
            if i > 0 { y += readingSize * 1.45 }
            out.append(Line(text: r, size: readingSize, centerY: y, kern: 0, stage: 1))
        }
        y += 44
        for (i, r) in meaningRows.enumerated() {
            if i > 0 { y += meaningSize * 1.35 }
            out.append(Line(text: r, size: meaningSize, centerY: y, kern: 1, stage: 2))
        }
        return out
    }

    /// Greedy word wrap; a single word wider than `width` gets its own line.
    static func wrap(_ text: String, size: CGFloat, width w: CGFloat, kern: CGFloat = 0) -> [String] {
        var rows: [String] = [], current = ""
        for word in text.split(separator: " ").map(String.init) {
            let candidate = current.isEmpty ? word : current + " " + word
            if current.isEmpty || width(candidate, size: size, kern: kern) <= w { current = candidate }
            else { rows.append(current); current = word }
        }
        if !current.isEmpty { rows.append(current) }
        return rows.isEmpty ? [text] : rows
    }

    static func width(_ text: String, size: CGFloat, kern: CGFloat = 0) -> CGFloat {
        let line = ctLine(text, size: size, kern: kern)
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    private static func ctLine(_ text: String, size: CGFloat, kern: CGFloat) -> CTLine {
        let attr = NSAttributedString(string: text, attributes: [.font: serifFont(size), .kern: kern])
        return CTLineCreateWithAttributedString(attr)
    }

    /// The lines as one outline, centred on x = 195, so the fit measures exactly what is drawn.
    static func textPath(_ lines: [Line], centerX: CGFloat = 195) -> CGPath {
        let out = CGMutablePath()
        for l in lines {
            let line = ctLine(l.text, size: l.size, kern: l.kern)
            var ascent: CGFloat = 0, descent: CGFloat = 0
            let w = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil)) - l.kern
            let x0 = centerX - w / 2, baseline = l.centerY + (ascent - descent) / 2
            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let attrs = CTRunGetAttributes(run) as NSDictionary
                let font = attrs[kCTFontAttributeName] as! CTFont
                let count = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: count)
                var positions = [CGPoint](repeating: .zero, count: count)
                CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
                CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
                for i in 0..<count {
                    var t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: x0 + positions[i].x, ty: baseline)
                    if let g = CTFontCreatePathForGlyph(font, glyphs[i], &t) { out.addPath(g) }
                }
            }
        }
        return out
    }

    // MARK: Fit

    struct Fit: Hashable, Codable {
        var size: CGFloat
        var dx: CGFloat
        var dy: CGFloat
        var coverage: Double
        var blue: Double
        static let resting = Fit(size: minSize, dx: 0, dy: 0, coverage: 0, blue: 0)
    }

    /// Smallest brush (618 → 618φ) that puts 100% of the text on blue; among those
    /// placements, the one whose blue covers closest to 1/φ of the screen.
    /// If no size within the cap covers everything, the best coverage wins.
    static func fit(text: String, lines: [Line]) -> Fit {
        let g: CGFloat = 6, gw = 65, gh = 141
        guard let ctx = CGContext(data: nil, width: gw, height: gh, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return .resting }
        ctx.translateBy(x: 0, y: CGFloat(gh)); ctx.scaleBy(x: 1 / g, y: -1 / g)
        ctx.setFillColor(gray: 1, alpha: 1); ctx.setStrokeColor(gray: 1, alpha: 1); ctx.setLineJoin(.round)
        let rows = ctx.bytesPerRow
        let clear = CGRect(x: -10, y: -10, width: 410, height: 870)
        func pixels() -> UnsafeMutablePointer<UInt8> { ctx.data!.assumingMemoryBound(to: UInt8.self) }

        ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(clear); ctx.setFillColor(gray: 1, alpha: 1)
        ctx.addPath(textPath(lines)); ctx.fillPath()
        var need: [Int] = []
        let px = pixels()
        for y in 0..<gh { for x in 0..<gw where px[y * rows + x] > 10 { need.append(y * rows + x) } }
        guard !need.isEmpty else { return .resting }

        var offsets: [(CGFloat, CGFloat)] = []
        for dy in stride(from: -420, through: 420, by: 21) { for dx in stride(from: -156, through: 156, by: 26) { offsets.append((CGFloat(dx), CGFloat(dy))) } }
        offsets.sort { hypot($0.0, $0.1) < hypot($1.0, $1.1) }

        var fallback: Fit?
        var s = minSize
        // taller text blocks (wrapped readings and meaning) may need a bigger brush than usual;
        // the loop stops at the first size that covers everything, so short words are unaffected
        while s <= maxSize * 1.618 + 1 {
            var best: Fit?
            for (dx, dy) in offsets {
                ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(clear); ctx.setFillColor(gray: 1, alpha: 1)
                ctx.setLineWidth(s * strokeRatio)
                ctx.addPath(path(text, size: s, dx: dx, dy: dy)); ctx.drawPath(using: .fillStroke)
                let p = pixels()
                var ok = 0
                for i in need where p[i] > 200 { ok += 1 }
                var blue = 0
                for y in 0..<gh { for x in 0..<gw where p[y * rows + x] > 128 { blue += 1 } }
                let cand = Fit(size: s, dx: dx, dy: dy, coverage: Double(ok) / Double(need.count), blue: Double(blue) / Double(gw * gh))
                let err = abs(cand.blue - Double(phi))
                if let f = fallback {
                    if cand.coverage > f.coverage + 0.001 || (abs(cand.coverage - f.coverage) <= 0.001 && err < abs(f.blue - Double(phi))) { fallback = cand }
                } else { fallback = cand }
                if cand.coverage >= 0.999, best == nil || err < abs(best!.blue - Double(phi)) { best = cand }
            }
            if let best { return best }
            s *= 1.05
        }
        return fallback ?? .resting
    }
}

// MARK: Small widget tile

extension Brush {
    /// The small Home Screen widget is laid out in this square and scaled to the real size.
    static let tile = CGSize(width: 158, height: 158)
    static let tileCenter = CGPoint(x: 79, y: 79)

    /// Characters, reading and meaning stacked in the middle of the tile, each shrunk
    /// (down to a floor) until it fits inside the margins.
    static func tileLines(hanzi: String, reading: String, meaning: String) -> [Line] {
        func sized(_ text: String, _ size: CGFloat, kern: CGFloat, floor: CGFloat) -> CGFloat {
            var s = size
            while s > floor, width(text, size: s, kern: kern) > 128 { s -= 0.5 }
            return s
        }
        return [
            Line(text: hanzi, size: sized(hanzi, 24, kern: 4, floor: 15), centerY: 56, kern: 4),
            Line(text: reading, size: sized(reading, 15, kern: 0, floor: 10), centerY: 83, kern: 0),
            Line(text: meaning, size: sized(meaning, 15, kern: 0, floor: 10), centerY: 104, kern: 0),
        ]
    }

    /// The tile's version of `fit`: the smallest brush that puts all the text on blue,
    /// placed so the blue covers about 1/φ of the tile. `dx`/`dy` move the brush's
    /// centre away from the tile's centre. Falls back to the best coverage found.
    static func tileFit(text: String, lines: [Line]) -> Fit {
        let g: CGFloat = 3, gw = Int(tile.width / g), gh = Int(tile.height / g)
        guard let ctx = CGContext(data: nil, width: gw, height: gh, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return Fit(size: 240, dx: 0, dy: -27, coverage: 0, blue: 0) }
        ctx.translateBy(x: 0, y: CGFloat(gh)); ctx.scaleBy(x: 1 / g, y: -1 / g)
        ctx.setLineJoin(.round); ctx.setLineCap(.round)
        let rows = ctx.bytesPerRow
        let clear = CGRect(x: -10, y: -10, width: tile.width + 20, height: tile.height + 20)
        func pixels() -> UnsafeMutablePointer<UInt8> { ctx.data!.assumingMemoryBound(to: UInt8.self) }

        ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(clear)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.addPath(textPath(lines, centerX: tileCenter.x)); ctx.fillPath()
        var need: [Int] = []
        var px = pixels()
        for y in 0..<gh { for x in 0..<gw where px[y * rows + x] > 10 { need.append(y * rows + x) } }
        guard !need.isEmpty else { return Fit(size: 240, dx: 0, dy: -27, coverage: 1, blue: 0) }

        var offsets: [(CGFloat, CGFloat)] = []
        for dy in stride(from: -120, through: 120, by: 10) { for dx in stride(from: -40, through: 40, by: 10) { offsets.append((CGFloat(dx), CGFloat(dy))) } }
        offsets.sort { hypot($0.0, $0.1) < hypot($1.0, $1.1) }

        var fallback: Fit?
        var s: CGFloat = 150
        while s <= 480 {
            var best: Fit?
            for (dx, dy) in offsets {
                ctx.setFillColor(gray: 0, alpha: 1); ctx.fill(clear)
                ctx.setFillColor(gray: 1, alpha: 1); ctx.setStrokeColor(gray: 1, alpha: 1)
                ctx.setLineWidth(s * strokeRatio)
                ctx.addPath(path(text, size: s, dx: dx, dy: dy, centerY: tileCenter.y, centerX: tileCenter.x))
                ctx.drawPath(using: .fillStroke)
                px = pixels()
                var ok = 0
                for i in need where px[i] > 200 { ok += 1 }
                let coverage = Double(ok) / Double(need.count)
                // only placements that could win are worth counting the blue for
                if coverage < 0.999, let f = fallback, coverage < f.coverage - 0.001 { continue }
                var blue = 0
                for y in 0..<gh { for x in 0..<gw where px[y * rows + x] > 128 { blue += 1 } }
                let cand = Fit(size: s, dx: dx, dy: dy, coverage: coverage, blue: Double(blue) / Double(gw * gh))
                let err = abs(cand.blue - Double(phi))
                if let f = fallback {
                    if cand.coverage > f.coverage + 0.001 || (abs(cand.coverage - f.coverage) <= 0.001 && err < abs(f.blue - Double(phi))) { fallback = cand }
                } else { fallback = cand }
                if cand.coverage >= 0.999, best == nil || err < abs(best!.blue - Double(phi)) { best = cand }
            }
            if let best { return best }
            s *= 1.1
        }
        return fallback ?? Fit(size: 240, dx: 0, dy: -27, coverage: 0, blue: 0)
    }
}

extension Brush {
    /// The reading the small widget shows: pinyin, or jyutping when that's all the learner reads.
    static func tileReading(_ w: Word, _ settings: AppSettings) -> String {
        settings.readings == .cantonese || w.pinyin.isEmpty ? w.jyutping : w.pinyin
    }

    /// The small widget's text block and its brush fit, measured once and kept in the App Group.
    static func tile(_ w: Word, _ settings: AppSettings) -> ([Line], Fit) {
        let hanzi = w.hanzi(settings.script), reading = tileReading(w, settings)
        let lines = tileLines(hanzi: hanzi, reading: reading, meaning: w.shortMeaning)
        let key = "\(hanzi)|\(reading)|\(w.shortMeaning)"
        if let f = FitCache.tiles.get(key) { return (lines, f) }
        let f = tileFit(text: hanzi, lines: lines)
        FitCache.tiles.set(key, f)
        return (lines, f)
    }
}

/// Text outlines from `Brush.textPath` as a SwiftUI shape, scaled exactly like `BrushShape`,
/// so what is drawn is what the fit measured.
struct BrushTextShape: Shape {
    var lines: [Brush.Line]
    var centerX: CGFloat
    var designSize: CGSize

    func path(in rect: CGRect) -> Path {
        let k = max(rect.width / designSize.width, rect.height / designSize.height)
        let ox = rect.minX + (rect.width - designSize.width * k) / 2, oy = rect.minY + (rect.height - designSize.height * k) / 2
        return Path(Brush.textPath(lines, centerX: centerX)).applying(CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: ox, ty: oy))
    }
}

private final class BundleToken {}

/// Fits are measured once per word and kept on disk, so a card never zooms to a
/// placeholder and snaps when its real fit arrives.
final class FitCache {
    static let shared = FitCache()
    /// Small-widget fits, in the App Group so the app can measure them ahead of the widget.
    static let tiles = FitCache(url: (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Store.appGroupID)
        ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]).appendingPathComponent("tile-fits-v2.json"))
    private var memory: [String: Brush.Fit] = [:]
    private let lock = NSLock()
    private let url: URL

    init(url: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("brush-fits-v4.json")) {
        self.url = url
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([String: Brush.Fit].self, from: data) {
            memory.merge(saved) { mine, _ in mine }
        }
    }

    /// On a miss, look on disk once more: another process (app or widget) may have measured it.
    func get(_ key: String) -> Brush.Fit? {
        lock.lock(); defer { lock.unlock() }
        if let f = memory[key] { return f }
        load()
        return memory[key]
    }

    func set(_ key: String, _ fit: Brush.Fit) {
        lock.lock(); memory[key] = fit; let snapshot = memory; lock.unlock()
        if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
    }

    /// The fit for this word, measuring it (off the main thread) only if it has never been measured.
    func fit(key: String, text: String, lines: [Brush.Line]) async -> Brush.Fit {
        if let f = get(key) { return f }
        let f = await Task.detached(priority: .userInitiated) { Brush.fit(text: text, lines: lines) }.value
        set(key, f)
        return f
    }
}

/// The brush word as a SwiftUI shape, thickened by the brush stroke, laid out in
/// the 390 × 844 design grid and scaled into whatever rect it is given.
struct BrushShape: Shape {
    var text: String
    var size: CGFloat
    var center: CGPoint
    var designSize: CGSize

    func path(in rect: CGRect) -> Path {
        let p = Brush.path(text, size: size, centerY: center.y, centerX: center.x)
        let thick = p.union(p.copy(strokingWithWidth: size * Brush.strokeRatio, lineCap: .round, lineJoin: .round, miterLimit: 10))
        let k = max(rect.width / designSize.width, rect.height / designSize.height)
        let ox = rect.minX + (rect.width - designSize.width * k) / 2, oy = rect.minY + (rect.height - designSize.height * k) / 2
        return Path(thick).applying(CGAffineTransform(a: k, b: 0, c: 0, d: k, tx: ox, ty: oy))
    }
}
