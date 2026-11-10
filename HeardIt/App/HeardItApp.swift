import AVFoundation
import SwiftUI
import WidgetKit

@main
struct HeardItApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onOpenURL { model.open($0) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refresh() }
                }
        }
    }
}

/// Wraps the shared Store for SwiftUI and keeps the widget in sync.
@MainActor
final class AppModel: ObservableObject {
    let store = Store.shared
    @Published private(set) var version = 0
    /// A word opened from the widget; shown on Today until graded.
    @Published var focusedID: String?
    @Published var selectedTab: Int = {
        // screenshot hook: -demoTab 1 opens Words, 2 opens Settings
        let a = ProcessInfo.processInfo.arguments
        if let i = a.firstIndex(of: "-demoTab"), i + 1 < a.count { return Int(a[i + 1]) ?? 0 }
        return 0
    }()

    var settings: AppSettings { store.settings }

    var currentCard: Word? {
        if let id = focusedID, let w = store.word(id: id) { return w }
        return store.currentCard()
    }

    var upNext: [Word] {
        store.queue().filter { $0.id != currentCard?.id }.prefix(5).map { $0 }
    }

    func refresh() {
        store.reload()
        version += 1
    }

    func open(_ url: URL) {
        guard url.scheme == "heardit" else { return }
        if url.host == "word" { focusedID = url.lastPathComponent }
        selectedTab = 0
        refresh()
    }

    func grade(_ word: Word, _ grade: Grade) {
        store.grade(word.id, grade)
        if focusedID == word.id { focusedID = nil }
        changed()
    }

    func setKnownByEar(_ word: Word, _ known: Bool) {
        store.setKnownByEar(word.id, known)
        changed()
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        store.updateSettings(change)
        changed()
    }

    // MARK: Topics

    var showOnboarding: Bool {
        !settings.onboarded && !ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-demo") }
    }

    /// The first screen's answers: switch on each picked goal's topic decks.
    func finishOnboarding(goals: Set<String>) {
        let picked = Goal.all.filter { goals.contains($0.id) }
        updateSettings { s in
            s.goals = picked.map(\.id)
            for id in picked.flatMap(\.topics) where !s.topics.contains(id) { s.topics.append(id) }
            s.onboarded = true
        }
        selectedTab = 0
    }

    func setTopic(_ topic: Topic, _ on: Bool) {
        store.setTopic(topic.id, on: on)
        changed()
    }

    func resetProgress() {
        store.resetProgress()
        focusedID = nil
        changed()
    }

    /// Speak with the best installed Mandarin (zh-CN) and/or Cantonese (zh-HK) voice.
    /// Check words with more than one reading (的, 了, 行) by ear.
    func speak(_ word: Word, _ dialects: [Dialect]) {
        Pronouncer.shared.speak(word, dialects)
    }

    /// Mandarin then Cantonese, or just the readings the user chose to show.
    var defaultDialects: [Dialect] {
        switch settings.readings {
        case .both: return [.mandarin, .cantonese]
        case .mandarin: return [.mandarin]
        case .cantonese: return [.cantonese]
        }
    }

    private func changed() {
        version += 1
        WidgetCenter.shared.reloadAllTimelines()
    }
}
