import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(0)
            WordsView()
                .tabItem { Label("Words", systemImage: "character.book.closed") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
    }
}

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let word = model.currentCard {
                        CardView(word: word, revealed: $revealed)
                            .id("\(word.id)-\(model.version)")
                    } else {
                        ContentUnavailableView("No words loaded", systemImage: "tray")
                    }
                    if !model.upNext.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Up next").font(.headline)
                            ForEach(model.upNext) { w in
                                HStack {
                                    Text(w.hanzi(model.settings.script)).font(.title3)
                                    Text(w.meaning).foregroundStyle(.secondary).lineLimit(1)
                                    Spacer()
                                    Text(w.deck.title).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Add the Heard It widget to your Lock Screen to review without opening the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }
}

struct CardView: View {
    @EnvironmentObject private var model: AppModel
    let word: Word
    @Binding var revealed: Bool

    var body: some View {
        VStack(spacing: 14) {
            Text(word.deck.title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(word.hanzi(model.settings.script))
                .font(.system(size: 64, weight: .bold))
                .minimumScaleFactor(0.4)
                .lineLimit(1)

            if revealed {
                Text(word.readings(model.settings.readings)).font(.title3)
                Text(word.meaning).font(.headline)
                if let note = word.note {
                    Text(note).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                HStack(spacing: 12) {
                    if word.speechText(.mandarin) != nil {
                        Button { model.speak(word, [.mandarin]) } label: { Label("Mandarin", systemImage: "speaker.wave.2") }
                    }
                    Button { model.speak(word, [.cantonese]) } label: { Label("Cantonese", systemImage: "speaker.wave.2") }
                }
                .buttonStyle(.bordered)

                HStack(spacing: 10) {
                    gradeButton("Missed", .missed, .red)
                    gradeButton("Unsure", .unsure, .orange)
                    gradeButton("Knew it", .knew, .green)
                }
            } else {
                Button {
                    revealed = true
                    if model.settings.speakOnReveal { model.speak(word, model.defaultDialects) }
                } label: {
                    Text("Reveal").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
        .onAppear { revealed = model.store.isRevealed(word.id) }
    }

    private func gradeButton(_ title: String, _ grade: Grade, _ tint: Color) -> some View {
        Button {
            revealed = false
            model.grade(word, grade)
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

// MARK: - Words

struct WordsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Tap the ear on words you already know by ear. They jump the queue, because you only need to learn how they look.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(Deck.allCases) { deck in
                    let words = filtered(deck)
                    if !words.isEmpty {
                        Section(deck.title) {
                            ForEach(words) { WordRow(word: $0) }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Characters, pinyin, Jyutping or English")
            .navigationTitle("Words")
            .id(model.version)
        }
    }

    private func filtered(_ deck: Deck) -> [Word] {
        model.store.words.filter { w in
            w.deck == deck && (search.isEmpty || [w.simplified, w.traditional, w.pinyin, w.jyutping, w.meaning]
                .contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }
}

struct WordRow: View {
    @EnvironmentObject private var model: AppModel
    let word: Word

    var body: some View {
        let state = model.store.state(for: word.id)
        let known = state?.knownByEar ?? false
        HStack(spacing: 12) {
            Text(word.hanzi(model.settings.script)).font(.title2).frame(minWidth: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.readings(.both)).font(.subheadline)
                Text(word.meaning).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let state, !state.isNew {
                Text("\(Int(Scheduler.mastery(state, now: .now) * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button {
                model.speak(word, model.defaultDialects)
            } label: {
                Image(systemName: "speaker.wave.2").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pronounce \(word.meaning)")
            Button {
                model.setKnownByEar(word, !known)
            } label: {
                Image(systemName: known ? "ear.fill" : "ear")
                    .foregroundStyle(known ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(known ? "Known by ear" : "Mark as known by ear")
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Characters", selection: binding(\.script)) {
                    ForEach(Script.allCases) { Text($0.title).tag($0) }
                }
                Picker("Readings", selection: binding(\.readings)) {
                    ForEach(ReadingMode.allCases) { Text($0.title).tag($0) }
                }
                Stepper("New words per day: \(model.settings.newPerDay)", value: binding(\.newPerDay), in: 3...30)
                Section {
                    Toggle("Say the word when I reveal a card", isOn: binding(\.speakOnReveal))
                } footer: {
                    Text("For more natural voices, download an Enhanced or Premium Chinese (Mainland) and Cantonese (Hong Kong) voice in Settings > Accessibility > Spoken Content > Voices. The lock screen widget only speaks when you tap its speaker button.")
                }
                Section {
                    Button("Reset progress", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Reset all progress? This can't be undone.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetProgress() }
            }
            .id(model.version)
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}
