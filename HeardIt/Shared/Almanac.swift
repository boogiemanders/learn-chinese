import Foundation

/// The two almanac lines on the tear-off page: 宜 (where you'll meet the word)
/// and 忌 (the look-alike character not to confuse it with).
enum Almanac {
    /// Short tag for the 宜 box, and the longer line under the English on the large page.
    static func goodFor(_ deck: Deck) -> (tag: String, line: String) {
        switch deck {
        case .menu: return ("ORDERING", "ORDERING · MENUS · RESTAURANTS")
        case .trip: return ("TRAVEL", "TRAVEL · SIGNS · GETTING AROUND")
        case .survival: return ("EVERYDAY", "EVERYDAY · OUT AND ABOUT")
        case .cantoPair: return ("FAMILY", "TALKING WITH FAMILY")
        case .core: return ("READING", "READING · SIGNS · TEXTS")
        }
    }

    struct LookAlike: Hashable { let char: String; let pinyin: String }

    /// Common look-alike pairs heritage readers mix up. Keyed both ways.
    private static let pairs: [(String, String, String, String)] = [
        ("叉", "chā", "又", "yòu"), ("己", "jǐ", "已", "yǐ"), ("未", "wèi", "末", "mò"),
        ("土", "tǔ", "士", "shì"), ("人", "rén", "入", "rù"), ("日", "rì", "曰", "yuē"),
        ("大", "dà", "太", "tài"), ("天", "tiān", "夫", "fū"), ("千", "qiān", "干", "gān"),
        ("午", "wǔ", "牛", "niú"), ("刀", "dāo", "力", "lì"), ("今", "jīn", "令", "lìng"),
        ("买", "mǎi", "卖", "mài"), ("買", "mǎi", "賣", "mài"), ("鸟", "niǎo", "乌", "wū"),
        ("免", "miǎn", "兔", "tù"), ("王", "wáng", "玉", "yù"), ("白", "bái", "百", "bǎi"),
        ("木", "mù", "本", "běn"), ("目", "mù", "自", "zì"), ("田", "tián", "由", "yóu"),
        ("甲", "jiǎ", "申", "shēn"), ("办", "bàn", "为", "wèi"), ("戊", "wù", "戍", "shù"),
        ("问", "wèn", "间", "jiān"), ("問", "wèn", "間", "jiān"), ("住", "zhù", "往", "wǎng"),
        ("体", "tǐ", "休", "xiū"), ("贝", "bèi", "见", "jiàn"), ("貝", "bèi", "見", "jiàn"),
        ("拔", "bá", "拨", "bō"), ("准", "zhǔn", "淮", "huái"), ("鸡", "jī", "鸭", "yā"),
        ("雞", "jī", "鴨", "yā"), ("汤", "tāng", "汁", "zhī"), ("米", "mǐ", "来", "lái"),
        ("饭", "fàn", "饮", "yǐn"), ("飯", "fàn", "飲", "yǐn"), ("酒", "jiǔ", "洒", "sǎ"),
        ("茶", "chá", "荼", "tú"), ("面", "miàn", "而", "ér"), ("肉", "ròu", "内", "nèi"),
        ("鱼", "yú", "角", "jiǎo"), ("牛", "niú", "生", "shēng"), ("出", "chū", "山", "shān"),
        ("口", "kǒu", "日", "rì"), ("门", "mén", "问", "wèn"), ("右", "yòu", "石", "shí"),
        ("左", "zuǒ", "在", "zài"), ("小", "xiǎo", "少", "shǎo"), ("上", "shàng", "止", "zhǐ"),
    ]
    private static let table: [String: LookAlike] = {
        var t: [String: LookAlike] = [:]
        for (a, ap, b, bp) in pairs {
            if t[a] == nil { t[a] = LookAlike(char: b, pinyin: bp) }
            if t[b] == nil { t[b] = LookAlike(char: a, pinyin: ap) }
        }
        return t
    }()

    /// The first character in the word that has a well-known look-alike.
    static func avoid(_ hanzi: String) -> LookAlike? {
        for ch in hanzi { if let l = table[String(ch)] { return l } }
        return nil
    }
}
