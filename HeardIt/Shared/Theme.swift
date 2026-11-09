import SwiftUI

/// Hear to Read's palette and type. Two faces only: the Zhi Mang Xing brush, and a serif
/// (Songti where installed, otherwise the system serif). Sizes follow the golden scale.
enum Theme {
    static let page = Color(hex: 0xFAFAF8)   // paper
    static let blue = Color(hex: 0x2D5F7C)   // brush and panel
    static let ink = Color(hex: 0x23485C)    // text on paper
    static let muted = Color(hex: 0x4F6F82)  // secondary text
    static let line = Color(hex: 0xBFCBD3)   // hairlines and quiet circles
    static let red = Color(hex: 0xC1352B)    // the one solid red: Got it

    static func serif(_ size: CGFloat) -> Font { Font(Brush.serifFont(size)) }
    static func brush(_ size: CGFloat) -> Font { Brush.ensureFont(); return .custom(Brush.fontName, fixedSize: size) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
