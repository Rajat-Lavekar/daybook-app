import SwiftUI
import DaybookCore

struct ReflectView: View {
    @EnvironmentObject var model: AppModel
    @State private var mood = 3
    @State private var energy = 3
    @State private var stress = 3
    @State private var helped = ""
    @State private var difficult = ""
    @State private var tomorrow = ""
    @State private var allowExcerpt = false
    @State private var saved = false
    var body: some View {
        Page {
            PageHeader(eyebrow: "REFLECT / A SMALL PAUSE", title: "How are you, really?", detail: "You don't need a perfect day to take a moment for yourself.")
            Panel {
                rating("Mood", value: $mood, low: "Low", high: "Good")
                rating("Energy", value: $energy, low: "Depleted", high: "Energized")
                rating("Stress", value: $stress, low: "Low", high: "High")
            }
            Panel {
                SectionLabel(text: "A few words, if you want")
                TextField("What helped today?", text: $helped, axis: .vertical).lineLimit(2...5).inputStyle()
                TextField("What felt difficult?", text: $difficult, axis: .vertical).lineLimit(2...5).inputStyle()
                TextField("One small action for tomorrow", text: $tomorrow, axis: .vertical).lineLimit(2...5).inputStyle()
                Toggle("Allow these words in a review I explicitly export", isOn: $allowExcerpt).font(.caption)
                Text("Stored on this device. Exported reviews exclude journal text unless both this entry and the export allow it.").font(.caption).foregroundStyle(Theme.muted)
                Button(saved ? "Saved ✓" : "Save this moment") {
                    guard model.requireLiveData() else { return }
                    model.update { $0.checkIns.insert(CheckIn(mood: mood, energy: energy, stress: stress, helped: helped, difficult: difficult, tomorrow: tomorrow, allowExcerpt: allowExcerpt), at: 0) }
                    if model.error == nil { helped = ""; difficult = ""; tomorrow = ""; allowExcerpt = false; saved = true }
                }.buttonStyle(.borderedProminent).disabled(saved)
                if saved { Button("Start another check-in") { saved = false }.font(.caption) }
            }
            NavigationLink { LessonView(lesson: Library.lessons.last!) } label: {
                Panel { SectionLabel(text: "A two-minute read"); Text("Describe the day before judging it").font(.system(size: 24, design: .serif)); Label("Read the exercise", systemImage: "arrow.right").font(.subheadline) }
            }.buttonStyle(.plain)
            if !model.snapshot.checkIns.isEmpty { SectionLabel(text: "Recent moments") }
            ForEach(model.snapshot.checkIns.prefix(14)) { entry in
                Panel {
                    HStack { Text(entry.date.formatted(date: .abbreviated, time: .shortened)).font(.caption); Spacer(); Text("Mood \(entry.mood)/5").font(.caption).foregroundStyle(Theme.green) }
                    if !entry.helped.isEmpty { Text(entry.helped).font(.subheadline) }
                    if !entry.difficult.isEmpty { Text(entry.difficult).font(.subheadline).foregroundStyle(Theme.muted) }
                    if !entry.tomorrow.isEmpty { Label(entry.tomorrow, systemImage: "arrow.turn.down.right").font(.caption) }
                }
            }
        }
    }
    private func rating(_ title: String, value: Binding<Int>, low: String, high: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(title).font(.subheadline.weight(.semibold)); Spacer(); Text("\(value.wrappedValue) / 5").font(.caption).foregroundStyle(Theme.muted) }
            Picker(title, selection: value) { ForEach(1...5, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.segmented).labelsHidden()
            HStack { Text(low); Spacer(); Text(high) }.font(.caption2).foregroundStyle(Theme.muted)
        }
    }
}

struct LearnView: View {
    @EnvironmentObject var model: AppModel
    @State private var bookmarksOnly = false
    var body: some View {
        Page {
            PageHeader(eyebrow: "LEARN / TRADE SCROLLING FOR CURIOSITY", title: "Something worth your time.", detail: "One idea. A concrete example. A question to take with you.")
            Toggle("Bookmarked readings", isOn: $bookmarksOnly).font(.subheadline)
            ForEach(Library.lessons.filter { !bookmarksOnly || model.snapshot.bookmarkedLessons.contains($0.id) }) { lesson in
                NavigationLink { LessonView(lesson: lesson) } label: {
                    Panel {
                        HStack { SectionLabel(text: "\(lesson.track) / \(lesson.minutes) MIN"); Spacer(); if model.snapshot.completedLessons.contains(lesson.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green) } }
                        Text(lesson.title).font(.system(size: 25, design: .serif)).foregroundStyle(Theme.ink)
                        Text(lesson.subtitle).font(.subheadline).foregroundStyle(Theme.muted)
                        HStack { Text("Read & reflect"); Spacer(); Image(systemName: "arrow.up.right") }.font(.caption.weight(.medium)).foregroundStyle(Theme.green)
                    }
                }.buttonStyle(.plain)
            }
            Text("Six original starter readings, available offline. More depth comes from the linked sources. No infinite feed.").font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

struct LessonView: View {
    @EnvironmentObject var model: AppModel
    let lesson: Lesson
    @State private var reveal = false
    var body: some View {
        Page {
            PageHeader(eyebrow: "\(lesson.track) / \(lesson.minutes) MIN READ", title: lesson.title, detail: lesson.subtitle)
            ForEach(Array(lesson.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph).font(.system(size: 18, design: .serif)).lineSpacing(8).foregroundStyle(Theme.ink).textSelection(.enabled)
            }
            Panel {
                SectionLabel(text: "Make it stick")
                Text(lesson.question).font(.headline)
                Button(reveal ? "Hide explanation" : "Show explanation") { reveal.toggle() }.buttonStyle(.bordered)
                if reveal { Text(lesson.answer).font(.subheadline).foregroundStyle(Theme.muted) }
            }
            HStack {
                Button(model.snapshot.completedLessons.contains(lesson.id) ? "Completed ✓" : "Mark complete") { model.update { $0.completedLessons.insert(lesson.id) } }.buttonStyle(.borderedProminent)
                Button { model.update { if $0.bookmarkedLessons.contains(lesson.id) { $0.bookmarkedLessons.remove(lesson.id) } else { $0.bookmarkedLessons.insert(lesson.id) } } } label: {
                    Image(systemName: model.snapshot.bookmarkedLessons.contains(lesson.id) ? "bookmark.fill" : "bookmark")
                }.buttonStyle(.bordered).accessibilityLabel("Toggle bookmark")
            }
            Link(destination: lesson.source) { Label("Go deeper at the source", systemImage: "arrow.up.right.square") }.font(.subheadline)
            Text("Original Daybook reading. Source linked for further study; no external article is copied into this app.").font(.caption).foregroundStyle(Theme.muted)
        }.navigationTitle("Reading")
    }
}
