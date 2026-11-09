import Foundation

// Plain checks for the shared logic. Run with:
//   swiftc Shared/Word.swift Shared/Scheduler.swift Shared/Store.swift Tests/SchedulerCheck/main.swift -o /tmp/schedcheck && /tmp/schedcheck Shared/words.json
var failures = 0
func check(_ ok: Bool, _ label: String) { print(ok ? "PASS" : "FAIL", label); if !ok { failures += 1 } }

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Shared/words.json"
let words = try WordLoader.load(from: URL(fileURLWithPath: path))
check(words.count >= 60, "loaded \(words.count) words")
check(Set(words.map(\.id)).count == words.count, "word ids are unique")
check(words.allSatisfy { !$0.jyutping.isEmpty }, "every word has Jyutping")
check(words.filter { $0.deck != .cantoPair }.allSatisfy { !$0.pinyin.isEmpty }, "non-pair words have pinyin")
check(words.filter { $0.deck == .cantoPair }.allSatisfy { $0.mandarinWord != nil }, "Canto pairs name the Mandarin word")

let r = Scheduler.retrievability(stability: 5, elapsedDays: 5)
check(abs(r - 0.9) < 0.001, "R = 0.9 when elapsed = stability (got \(r))")

let t0 = Date(timeIntervalSince1970: 1_800_000_000)
var s = Scheduler.apply(.knew, to: nil, now: t0)
check(s.stability == 4 && s.reps == 1, "first 'knew' sets stability 4")
let s2 = Scheduler.apply(.knew, to: s, now: t0.addingTimeInterval(4 * 86_400))
check(s2.stability > s.stability * 1.4, "second 'knew' grows stability (\(s2.stability))")
let s3 = Scheduler.apply(.missed, to: s2, now: t0.addingTimeInterval(10 * 86_400))
check(s3.confidentMiss && s3.lapses == 1 && s3.stability < s2.stability, "miss after 'knew' flags confident miss")
s = Scheduler.apply(.knew, to: s3, now: t0.addingTimeInterval(11 * 86_400))
s = Scheduler.apply(.knew, to: s, now: t0.addingTimeInterval(12 * 86_400))
check(!s.confidentMiss, "two 'knew' in a row clear the flag")

// Known-by-ear words jump ahead of equal-weight unseen words.
let menu = words.filter { $0.deck == .menu }
var states: [String: ReviewState] = [:]
var ear = ReviewState(); ear.knownByEar = true
states[menu[5].id] = ear
let q = Scheduler.queue(words: menu, states: states, now: t0, newAllowed: 3)
check(q.first?.id == menu[5].id, "known-by-ear word comes first")
check(q.count == 3, "new words capped at newAllowed")

// Survival outranks menu for unseen words.
let mixed = Scheduler.queue(words: words, states: [:], now: t0, newAllowed: 1)
check(mixed.first?.deck == .survival, "survival words lead an empty start")

// Store round-trip in a temp folder, with the daily new-word cap.
let dir = FileManager.default.temporaryDirectory.appendingPathComponent("heardit-test-\(UUID().uuidString)")
let store = Store(words: words, directory: dir)
store.updateSettings { $0.newPerDay = 2 }
let first = store.currentCard()!
store.reveal(first.id)
check(store.isRevealed(first.id) && store.currentCard()?.id == first.id, "revealed card stays current")
store.grade(first.id, .knew)
check(!store.isRevealed(first.id), "grading clears the reveal")
check(store.newAllowedToday() == 1, "new-word count decrements")
let reopened = Store(words: words, directory: dir)
check(reopened.state(for: first.id)?.reps == 1, "progress persists to disk")
try? FileManager.default.removeItem(at: dir)

print(failures == 0 ? "\nALL PASSED" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
