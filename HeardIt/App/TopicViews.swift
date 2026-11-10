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
