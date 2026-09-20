import SwiftUI
import DaybookCore
import UniformTypeIdentifiers

@MainActor final class AppModel: ObservableObject {
    @Published var snapshot = Snapshot()
    @Published var error: String?
    @Published var notice: String?
    @Published var busy = false
    @Published var importedPeriodStart: Date?
    let store: SnapshotStore
    init() {
        store = SnapshotStore(url: Self.storeURL())
        reload()
    }
    nonisolated static func storeURL() -> URL {
        #if os(macOS)
        if let path = Bundle.main.object(forInfoDictionaryKey: "DaybookPreviewDataDirectory") as? String {
            return URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent("state-v1.json")
        }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Daybook", isDirectory: true).appendingPathComponent("state-v1.json")
    }
    func reload() { do { snapshot = try store.read() } catch { self.error = "Local data could not be read: \(error.localizedDescription). It has not been overwritten." } }
    @discardableResult func update(_ change: (inout Snapshot) throws -> Void) -> Bool {
        do { snapshot = try store.update(change); error = nil; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func requireLiveData() -> Bool {
        guard !snapshot.isDemo else { error = "Leave sample mode using the button at the top before adding personal records."; return false }
        return true
    }
    @discardableResult func save(_ entry: DaybookCore.Transaction) -> Bool {
        if !snapshot.transactions.contains(where: { $0.id == entry.id }) && !requireLiveData() { return false }
        return update { state in
            if let index = state.transactions.firstIndex(where: { $0.id == entry.id }) {
                var revised = entry; revised.updatedAt = Date(); state.transactions[index] = revised
            } else { Finance.ingest([entry], into: &state) }
        }
    }
    func useDemo() {
        guard snapshot.transactions.isEmpty else { error = "Sample payments are available only in an empty ledger."; return }
        update { state in
            let demo = Demo.snapshot(); state.transactions = demo.transactions
            state.isDemo = true; state.coverageNote = demo.coverageNote
        }
    }
    func clearDemo() {
        guard snapshot.isDemo else { return }
        update { state in
            state.transactions.removeAll { $0.source == "Demo" }
            state.isDemo = false; state.coverageNote = Snapshot().coverageNote
        }
    }
    var weekStart: Date { Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: Date()))! }
    var weekSummary: SpendingSummary { Finance.summary(snapshot.transactions, from: weekStart) }
    func packet(scope: ReviewScope, excerpts: Bool = false, health: Bool = false) -> ReviewPacket {
        ReviewPacket(snapshot: snapshot, scope: scope, from: weekStart, to: Date(), includeExcerpts: excerpts, includeHealth: health)
    }
    func importReview(_ data: Data) throws {
        let review = try DaybookJSON.decode(Review.self, from: data)
        guard !review.title.isEmpty, review.title.count <= 200, !review.body.isEmpty, review.body.count <= 20_000 else {
            throw DaybookError.invalid("The report has an invalid title or body.")
        }
        guard review.packetID != nil else { throw DaybookError.invalid("A report must identify its source packet. Use the Mac report-template command.") }
        if update({ state in if !state.reviews.contains(where: { $0.id == review.id }) { state.reviews.insert(review, at: 0) } }) {
            notice = "Report imported. External reports are unverified commentary; source records were not changed."
        }
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum Theme {
    static let ink = Color(red: 0.15, green: 0.21, blue: 0.19)
    static let green = Color(red: 0.19, green: 0.37, blue: 0.29)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let muted = Color(red: 0.43, green: 0.46, blue: 0.42)
    static let ochre = Color(red: 0.66, green: 0.43, blue: 0.18)
}

struct SectionLabel: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(Theme.muted) }
}
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 14) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 22)) }
}
struct PageHeader: View {
    let eyebrow: String; let title: String; let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: eyebrow)
            Text(title).font(.system(size: 36, weight: .regular, design: .serif)).foregroundStyle(Theme.ink)
            Text(detail).font(.subheadline).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
    }
}
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 20) { content }.padding(22).frame(maxWidth: 760).frame(maxWidth: .infinity) }.background(Theme.cream) }
}

extension View {
    func inputStyle() -> some View { textFieldStyle(.roundedBorder) }
}
