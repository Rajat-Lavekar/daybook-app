import SwiftUI
import DaybookCore

@main struct DaybookApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).tint(Theme.green).preferredColorScheme(.light)
                #if os(macOS)
                .frame(minWidth: 460, minHeight: 720)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 540, height: 900)
        #endif
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) var phase
    @State private var tab = 0
    @State private var settings = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "leaf").foregroundStyle(Theme.green)
                Text("daybook").font(.system(size: 24, weight: .medium, design: .serif))
                Spacer()
                if model.snapshot.isDemo {
                    Button("SAMPLE · LEAVE") { model.clearDemo() }.font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Theme.ochre).buttonStyle(.plain)
                }
                Button { settings = true } label: { Image(systemName: "slider.horizontal.3").padding(8) }.buttonStyle(.plain).accessibilityLabel("Settings and backup")
            }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.cream)
            TabView(selection: $tab) {
                NavigationStack { TodayView(tab: $tab) }.tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
                NavigationStack { MoneyView() }.tabItem { Label("Money", systemImage: "indianrupeesign.circle") }.tag(1)
                NavigationStack { HealthView() }.tabItem { Label("Health", systemImage: "heart") }.tag(2)
                NavigationStack { ReflectView() }.tabItem { Label("Reflect", systemImage: "square.and.pencil") }.tag(3)
                NavigationStack { LearnView() }.tabItem { Label("Learn", systemImage: "book.closed") }.tag(4)
            }
        }
        .sheet(isPresented: $settings) { NavigationStack { SettingsView() }.environmentObject(model) }
        .alert("Couldn't complete that", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .alert("Daybook", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })) { Button("OK") { model.notice = nil } } message: { Text(model.notice ?? "") }
        .onChange(of: phase) { _, value in if value == .active { model.reload() } }
    }
}

struct TodayView: View {
    @EnvironmentObject var model: AppModel
    @Binding var tab: Int
    var body: some View {
        Page {
            PageHeader(eyebrow: Date().formatted(.dateTime.weekday(.wide).month(.wide).day()), title: "A little more intentional.", detail: "Know where your money goes. Make room for what matters.")
            Panel {
                HStack { SectionLabel(text: "Your week, in rupees"); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(Theme.green) }
                Text(Money.format(model.weekSummary.netPaise)).font(.system(size: 44, weight: .regular, design: .serif)).foregroundStyle(Theme.ink)
                Text("Confirmed expenses, less refunds").font(.subheadline).foregroundStyle(Theme.muted)
                Divider()
                Text(model.snapshot.coverageNote).font(.caption).foregroundStyle(Theme.muted)
                if model.weekSummary.provisionalPaise > 0 { Text("\(Money.format(model.weekSummary.provisionalPaise)) awaiting review · excluded above").font(.caption).foregroundStyle(Theme.ochre) }
                Button("Open your money →") { tab = 1 }.buttonStyle(.plain).font(.subheadline.weight(.semibold))
            }
            HStack(alignment: .top, spacing: 12) {
                Panel {
                    Image(systemName: "moon.stars").foregroundStyle(Theme.green)
                    Text(model.snapshot.health.last(where: { $0.sleepHours != nil })?.sleepHours.map { String(format: "%.1f h", $0) } ?? "—").font(.system(size: 27, design: .serif))
                    Text("Latest recorded sleep").font(.caption).foregroundStyle(Theme.muted)
                    Button("View health") { tab = 2 }.buttonStyle(.plain).font(.caption.weight(.semibold))
                }
                Panel {
                    Image(systemName: "square.and.pencil").foregroundStyle(Theme.ochre)
                    Text("A moment\nfor you.").font(.system(size: 24, design: .serif))
                    Button("Check in →") { tab = 3 }.buttonStyle(.plain).font(.caption.weight(.semibold))
                }
            }
            SectionLabel(text: "Instead of the scroll")
            NavigationLink { LessonView(lesson: Library.lessons[0]) } label: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("SYSTEMS  /  4 MIN READ").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2)
                    Text("When a retry becomes\na second payment").font(.system(size: 27, design: .serif))
                    Text("A small idea you can use in the systems you build.").font(.subheadline).opacity(0.75)
                    HStack { Text("Start reading").fontWeight(.semibold); Spacer(); Image(systemName: "arrow.right") }.font(.subheadline)
                }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Theme.green, in: RoundedRectangle(cornerRadius: 22))
            }.buttonStyle(.plain)
            NavigationLink { ReviewsView() } label: { Label("Your reviews & next steps", systemImage: "sparkle").frame(maxWidth: .infinity, alignment: .leading).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain)
            if model.snapshot.transactions.isEmpty {
                Button("Explore with clearly labeled sample payments") { model.useDemo() }.font(.caption).frame(maxWidth: .infinity)
            }
            Text("A useful companion. No streaks to protect.").font(.caption).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).padding(.vertical, 8)
        }
    }
}
