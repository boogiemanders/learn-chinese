import Foundation

enum Grade: String, Codable, CaseIterable {
    case knew, unsure, missed
}

/// What the app remembers about one word.
struct ReviewState: Codable, Hashable {
    /// Days until recall probability falls to 90%.
    var stability: Double = 0
    var lastReview: Date?
    var reps: Int = 0
    var lapses: Int = 0
    var lastGrade: Grade?
    /// Missed right after a "knew it": the vocab version of "sure but wrong".
    var confidentMiss: Bool = false
    /// The learner already knows this word by ear (Cantonese or Mandarin).
    var knownByEar: Bool = false

    var isNew: Bool { lastReview == nil }
}

/// Ranking and memory model.
///
/// priority = deck weight × need × boosts, where need = 1 − mastery.
/// Mastery fades with time (FSRS-style forgetting curve). Unseen words start
/// at a 50/50 prior, the same starting point the Prioritize knowledge map uses.
enum Scheduler {
    static let desiredRetention = 0.9
    static let unseenPrior = 0.5

    /// FSRS forgetting curve: R = (1 + 19/81 · t/S)^−0.5, so R = 0.9 when t = S.
    static func retrievability(stability: Double, elapsedDays: Double) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1 + (19.0 / 81.0) * max(0, elapsedDays) / stability, -0.5)
    }

    static func mastery(_ state: ReviewState?, now: Date) -> Double {
        guard let state, let last = state.lastReview else { return unseenPrior }
        let days = now.timeIntervalSince(last) / 86_400
        return retrievability(stability: state.stability, elapsedDays: days)
    }

    static func priority(_ word: Word, _ state: ReviewState?, now: Date) -> Double {
        let need = 1 - mastery(state, now: now)
        var boost = 1.0
        if let state {
            if state.confidentMiss { boost *= 1.5 }
            if state.isNew && state.knownByEar { boost *= 1.3 } // cheapest win: attach characters to a word you already say
            if !state.isNew && mastery(state, now: now) < 0.7 { boost *= 1.2 } // overdue
        }
        return word.deck.weight * need * boost
    }

    /// Words to show now: reviews below the desired retention, plus up to
    /// `newAllowed` unseen words, highest priority first. Never empty if any
    /// words exist, so the widget always has a card.
    static func queue(words: [Word], states: [String: ReviewState], now: Date, newAllowed: Int) -> [Word] {
        var due: [(Word, Double)] = []
        var fresh: [(Word, Double)] = []
        for word in words {
            let state = states[word.id]
            let p = priority(word, state, now: now)
            if state?.isNew ?? true {
                fresh.append((word, p))
            } else if mastery(state, now: now) < desiredRetention {
                due.append((word, p))
            }
        }
        fresh.sort { $0.1 > $1.1 }
        let picked = due + fresh.prefix(max(0, newAllowed))
        let ranked = picked.sorted { $0.1 > $1.1 }.map(\.0)
        if !ranked.isEmpty { return ranked }

        // Everything is fresh in memory and no new words allowed today:
        // show the seen word you're most likely to forget next.
        let seen = words.filter { !(states[$0.id]?.isNew ?? true) }
        if let weakest = seen.min(by: { mastery(states[$0.id], now: now) < mastery(states[$1.id], now: now) }) {
            return [weakest]
        }
        return Array(words.prefix(1))
    }

    /// Update memory after a grade. Harder recalls (lower R) grow stability more.
    static func apply(_ grade: Grade, to previous: ReviewState?, now: Date) -> ReviewState {
        var s = previous ?? ReviewState()
        if s.isNew {
            switch grade {
            case .knew: s.stability = 4
            case .unsure: s.stability = 1
            case .missed: s.stability = 0.25
            }
        } else {
            let r = mastery(s, now: now)
            switch grade {
            case .knew: s.stability *= 1.3 + 2.0 * (1 - r)
            case .unsure: s.stability *= 1.1 + 0.5 * (1 - r)
            case .missed:
                s.stability = max(0.15, s.stability * 0.25)
                s.lapses += 1
            }
        }
        if grade == .missed && s.lastGrade == .knew {
            s.confidentMiss = true
        } else if grade == .knew && s.lastGrade == .knew {
            s.confidentMiss = false
        }
        s.lastGrade = grade
        s.lastReview = now
        s.reps += 1
        return s
    }
}
