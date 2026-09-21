import SwiftUI
import Charts
import UniformTypeIdentifiers
import DaybookCore

private enum MoneyPeriod: String, CaseIterable { case week = "7 days", month = "Month", all = "All" }

struct MoneyView: View {
    @EnvironmentObject var model: AppModel
    @State private var search = ""
    @State private var add = false
    @State private var importing = false
    @State private var editing: DaybookCore.Transaction?
    @State private var reviewOnly = false
    @State private var period = MoneyPeriod.week
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())!.start
    private var months: [Date] {
        Set((model.snapshot.transactions.map(\.date) + [Date(), month]).map { Calendar.current.dateInterval(of: .month, for: $0)!.start }).sorted(by: >)
    }
    private var interval: DateInterval {
        switch period {
        case .week: DateInterval(start: model.weekStart, end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!)
        case .month: Calendar.current.dateInterval(of: .month, for: month)!
        case .all: DateInterval(start: .distantPast, end: .distantFuture)
        }
    }
    private var periodLabel: String {
        switch period {
        case .week: "Last 7 days"
        case .month: month.formatted(.dateTime.month(.wide).year())
        case .all: "All recorded dates"
        }
    }
    private var summary: SpendingSummary { Finance.summary(model.snapshot.transactions, from: interval.start, to: interval.end) }
    var filtered: [DaybookCore.Transaction] {
        model.snapshot.transactions.filter { entry in
            entry.date >= interval.start && entry.date < interval.end &&
            (!reviewOnly || entry.status == .provisional || entry.category == .uncategorized) &&
            (search.isEmpty || "\(entry.merchant) \(entry.memo) \(entry.originalNote) \(entry.category.rawValue)".localizedCaseInsensitiveContains(search))
        }.sorted { $0.date > $1.date }
    }
    var body: some View {
        Page {
            PageHeader(eyebrow: "MONEY / YOUR LEDGER", title: "Know your spending.", detail: "Every number has a source. Every category is yours to change.")
            Picker("Period", selection: $period) { ForEach(MoneyPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            if period == .month {
                Picker("Month", selection: $month) { ForEach(months, id: \.self) { Text($0.formatted(.dateTime.month(.wide).year())).tag($0) } }
            }
            HStack { Button { add = true } label: { Label("Add payment", systemImage: "plus") }.buttonStyle(.borderedProminent)
                Button { importing = true } label: { Label("Import", systemImage: "square.and.arrow.down") }.buttonStyle(.bordered) }
            SpendingOverview(summary: summary, coverage: model.snapshot.coverageNote, periodLabel: periodLabel)
            HStack {
                SectionLabel(text: "Transactions")
                Spacer()
                Text("\(filtered.count) records").font(.caption).foregroundStyle(Theme.muted)
            }
            Text("Filters below affect this list; charts show the selected period.")
                .font(.caption).foregroundStyle(Theme.muted)
            TextField("Search merchant, category or note", text: $search).inputStyle()
            Toggle("Show payments needing review", isOn: $reviewOnly).font(.subheadline)
            if filtered.isEmpty {
                ContentUnavailableView("No matching payments", systemImage: "tray", description: Text("Try another period or clear the filters. Add a payment or import a GPay PDF to start your ledger."))
            }
            ForEach(filtered) { entry in
                Button { editing = entry } label: { TransactionRow(entry: entry) }.buttonStyle(.plain)
            }
            Panel {
                Label("Investments, later", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
                Text("You can mark investment contributions now so they don't inflate expenses. Holdings and live valuations are planned for a later version.").font(.caption).foregroundStyle(Theme.muted)
            }
        }        .onChange(of: model.importedPeriodStart) { _, start in
            if let start { month = Calendar.current.dateInterval(of: .month, for: start)!.start; period = .month }
        }.sheet(isPresented: $add) { NavigationStack { TransactionEditor(entry: nil) }.environmentObject(model) }
            .sheet(item: $editing) { entry in NavigationStack { TransactionEditor(entry: entry) }.environmentObject(model) }
            .sheet(isPresented: $importing) { NavigationStack { ImportView() }.environmentObject(model) }
    }
}

struct TransactionRow: View {
    let entry: DaybookCore.Transaction
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: entry.category.symbol).foregroundStyle(Theme.green).frame(width: 40, height: 40).background(Theme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.merchant).font(.subheadline.weight(.medium)).lineLimit(1)
                Text("\(entry.category.rawValue) · \(entry.date.formatted(.dateTime.day().month(.abbreviated)))").font(.caption).foregroundStyle(Theme.muted)
                if let source = entry.timeSource {
                    Text(source == .bankDateOnly ? "Time unavailable" : "\(entry.date.formatted(date: .omitted, time: .shortened)) · \(source == .messageTimestamp ? "message time" : "estimated time")")
                        .font(.caption2).foregroundStyle(Theme.muted)
                }
                Text(entry.account).font(.caption2).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(Money.format(entry.amountPaise)).font(.subheadline.weight(.medium)).monospacedDigit()
                Text(entry.status == .confirmed ? entry.kind.rawValue.capitalized : entry.status.rawValue.capitalized)
                    .font(.caption2).foregroundStyle(entry.status == .provisional ? Theme.ochre : Theme.muted)
            }
        }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TransactionEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    let entry: DaybookCore.Transaction?
    @State private var merchant = ""
    @State private var amount = ""
    @State private var account = "Kotak"
    @State private var memo = ""
    @State private var date = Date()
    @State private var category = Category.uncategorized
    @State private var kind = EntryKind.expense
    @State private var status = EntryStatus.confirmed
    @State private var remember = false
    var body: some View {
        Form {
            Section("Payment") {
                TextField("Merchant or person", text: $merchant)
                TextField("Amount in rupees", text: $amount)
                TextField("Account label", text: $account)
                DatePicker("Date", selection: $date)
            }
            Section("Classification") {
                Picker("Category", selection: $category) { ForEach(Category.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Kind", selection: $kind) { ForEach(EntryKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                Picker("Status", selection: $status) { ForEach(EntryStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                Toggle("Remember category for this merchant", isOn: $remember)
            }
            Section("Private memo") { TextField("Only in Daybook", text: $memo, axis: .vertical).lineLimit(3...6) }
            if let entry {
                Section("Source evidence") {
                    Text(entry.source).font(.caption)
                    if !entry.reference.isEmpty { LabeledContent("Reference", value: entry.reference).font(.caption) }
                    Text(entry.originalNote.isEmpty ? "No original payment note was present in this source." : entry.originalNote).font(.caption).textSelection(.enabled)
                }
            }
            Section { Text("Confirm a payment only after checking its amount, direction and status. Transfers, investments and income are excluded from expense totals.").font(.caption).foregroundStyle(.secondary) }
        }.formStyle(.grouped).navigationTitle(entry == nil ? "Add payment" : "Review payment")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(Money.parse(amount) == nil || Money.parse(amount) == 0 || merchant.trimmingCharacters(in: .whitespaces).isEmpty) } }
            .onAppear { if let entry { merchant = entry.merchant; amount = String(format: "%.2f", Double(entry.amountPaise) / 100); account = entry.account; memo = entry.memo; date = entry.date; category = entry.category; kind = entry.kind; status = entry.status } }
            .frame(minWidth: 340, minHeight: 520)
    }
    private func save() {
        guard let paise = Money.parse(amount), paise > 0 else { return }
        var value = entry ?? DaybookCore.Transaction(amountPaise: paise, merchant: merchant)
        value.amountPaise = paise; value.merchant = merchant; value.account = account; value.memo = memo
        if value.date != date { value.timeSource = nil }; value.date = date; value.category = category; value.kind = kind; value.status = status
        guard model.save(value) else { return }
        if remember { model.update { $0.merchantRules[merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)] = category } }
        if model.error == nil { dismiss() }
    }
}

struct ImportView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var text = ""
    @State private var result = ImportResult()
    @State private var filePicker = false
    @State private var exportTemplate = false
    @State private var issue: String?
    var body: some View {
        Page {
            PageHeader(eyebrow: "CAPTURE / REVIEW / SAVE", title: "Bring your payments in.", detail: "Import a GPay PDF or Daybook CSV, or paste one Kotak/HDFC transaction alert.")
            HStack { Button("Choose PDF / CSV") { filePicker = true }.buttonStyle(.borderedProminent)
                Button("CSV template") { exportTemplate = true }.buttonStyle(.bordered) }
            SectionLabel(text: "Or paste one bank alert")
            TextEditor(text: $text).font(.system(.body, design: .monospaced)).frame(minHeight: 120).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 12))
            Button("Preview pasted alert") {
                do { result = ImportResult(); result.entries = [try BankAlertParser.parse(text)]; issue = nil }
                catch { result = ImportResult(); issue = error.localizedDescription }
            }.buttonStyle(.bordered).disabled(text.isEmpty)
            if let issue { Text(issue).font(.caption).foregroundStyle(.red) }
            if let statement = result.statement {
                Panel {
                    SectionLabel(text: "GPay statement check")
                    Label(statement.totalsMatch && result.issues.isEmpty ? "All rows parsed · totals match" : "Import blocked · check issues", systemImage: statement.totalsMatch && result.issues.isEmpty ? "checkmark.circle" : "exclamationmark.triangle")
                    Text(statement.coverage).font(.caption).foregroundStyle(Theme.muted)
                    Text("GPay sent \(Money.format(statement.expectedSentPaise)) · received \(Money.format(statement.expectedReceivedPaise))").font(.caption)
                    if statement.selfTransferCount > 0 {
                        Text("GPay excludes \(statement.selfTransferCount) self-transfers (\(Money.format(statement.selfTransferPaise))) from its Sent total. Daybook keeps them as normal debits; you can change their Kind later.").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Text("This PDF format has no payment-note field. Existing personal memos are preserved on repeat imports.").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            ForEach(result.issues, id: \.self) { Text($0).font(.caption).foregroundStyle(Theme.ochre) }
            if result.entries.count <= 3 { ForEach(result.entries) { TransactionRow(entry: $0) } }
            if !result.entries.isEmpty {
                Text("\(result.entries.count) parsed · \(result.issues.count) rejected. Importing does not prove complete account coverage.").font(.caption).foregroundStyle(Theme.muted)
                Button("Import \(result.entries.count) parsed payments") {
                    guard model.requireLiveData() else { return }
                    model.update { state in
                        Finance.ingest(result.entries, into: &state)
                        state.coverageNote = result.statement?.coverage ?? "Imported records only. Missing alerts and statement periods have not been reconciled."
                    }
                    if model.error == nil { model.importedPeriodStart = result.statement?.from; dismiss() }
                }.buttonStyle(.borderedProminent).disabled(!result.canImport)
                if result.entries.count > 3 {
                    DisclosureGroup("Preview all \(result.entries.count) payments") {
                        LazyVStack(spacing: 12) { ForEach(result.entries) { TransactionRow(entry: $0) } }
                    }
                }
            }
            Text("SMS imports use the bank's date when present; its time is unknown. Alerts remain provisional until you review them. Missing payment notes stay missing. No bank or inbox connection is created by importing.").font(.caption).foregroundStyle(Theme.muted)
        }.navigationTitle("Import")
            .onChange(of: text) { _, _ in result = ImportResult(); issue = nil }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $filePicker, allowedContentTypes: [.pdf, .commaSeparatedText, .plainText]) { selection in
                do { let url = try selection.get(); let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    if url.pathExtension.lowercased() == "pdf" { result = try GPayStatementImporter.parse(data: Data(contentsOf: url)) }
                    else { result = try CSVImporter.parse(String(contentsOf: url, encoding: .utf8)) }
                    issue = nil
                } catch { result = ImportResult(); issue = error.localizedDescription }
            }
            .fileExporter(isPresented: $exportTemplate, document: ExportDocument(data: Data(CSVImporter.template.utf8)), contentType: .commaSeparatedText, defaultFilename: "daybook-template.csv") { outcome in if case .failure(let error) = outcome { issue = error.localizedDescription } }
            .frame(minWidth: 360, minHeight: 600)
    }
}

private struct SpendingSlice: Identifiable {
    let name: String
    let paise: Int64
    let color: Color
    var id: String { name }
}

private struct SpendingOverview: View {
    let summary: SpendingSummary
    let coverage: String
    let periodLabel: String
    @State private var selectedAngle: Double?
    private let palette: [Color] = [Theme.green, Color(red: 0.25, green: 0.43, blue: 0.62),
                                   Theme.ochre, Color(red: 0.66, green: 0.36, blue: 0.48)]
    private var ranked: [SpendingSlice] {
        summary.categories.filter { $0.value > 0 }.sorted {
            $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
        }.enumerated().map { index, item in
            SpendingSlice(name: item.key, paise: item.value, color: index < 4 ? palette[index] : .gray)
        }
    }
    private var slices: [SpendingSlice] {
        let rest = ranked.dropFirst(4).reduce(Int64(0)) { $0 + $1.paise }
        return Array(ranked.prefix(4)) + (rest > 0 ? [SpendingSlice(name: "Other categories", paise: rest, color: .gray)] : [])
    }
    private var selectedSlice: SpendingSlice? {
        guard let selectedAngle else { return nil }
        var end = 0.0
        return slices.first { item in
            end += Double(item.paise) / 100
            return selectedAngle < end
        }
    }
    private func select(_ item: SpendingSlice) {
        if selectedSlice?.id == item.id { selectedAngle = nil; return }
        let preceding = slices.prefix { $0.id != item.id }.reduce(Int64(0)) { $0 + $1.paise }
        selectedAngle = (Double(preceding) + Double(item.paise) / 2) / 100
    }
    private func share(_ amount: Int64) -> Double {
        summary.grossPaise > 0 ? Double(amount) / Double(summary.grossPaise) : 0
    }
    private func percent(_ amount: Int64) -> String { share(amount).formatted(.percent.precision(.fractionLength(1))) }
    var body: some View {
        VStack(spacing: 20) {
            Panel {
                HStack {
                    SectionLabel(text: "Net expenses")
                    Spacer()
                    Image(systemName: "indianrupeesign.circle").foregroundStyle(Theme.green)
                }
                Text(Money.format(summary.netPaise)).font(.system(size: 42, weight: .regular, design: .serif))
                    .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
                Text("\(periodLabel) · confirmed expenses less refunds")
                    .font(.caption).foregroundStyle(Theme.muted)
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 24) { metrics }
                    VStack(alignment: .leading, spacing: 16) { metrics }
                }
                if summary.provisionalPaise > 0 {
                    Label("\(Money.format(summary.provisionalPaise)) awaiting review · excluded from charts", systemImage: "clock")
                        .font(.caption).foregroundStyle(Theme.ochre)
                }
            }
            if !ranked.isEmpty {
                Panel {
                    SectionLabel(text: "Spending by category")
                    Text("\(periodLabel) · confirmed expenses before refunds")
                        .font(.caption).foregroundStyle(Theme.muted)
                    Chart(slices) { item in
                        SectorMark(angle: .value("Expense amount", Double(item.paise) / 100),
                                   innerRadius: .ratio(0.68), angularInset: 3)
                            .cornerRadius(7)
                            .foregroundStyle(LinearGradient(
                                colors: [item.color.opacity(0.62), item.color, item.color],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .opacity(selectedSlice == nil || selectedSlice?.id == item.id ? 1 : 0.32)
                    }
                    .chartLegend(.hidden)
                    .chartAngleSelection(value: $selectedAngle)
                    .frame(height: 250)
                    .shadow(color: Theme.ink.opacity(0.13), radius: 7, x: 0, y: 7)
                    .overlay {
                        VStack(spacing: 6) {
                            Text(selectedSlice?.name.uppercased() ?? "TOTAL SPENT")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1)
                                .foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                            Text(Money.format(selectedSlice?.paise ?? summary.grossPaise))
                                .font(.system(size: 26, design: .serif))
                                .minimumScaleFactor(0.6).lineLimit(1)
                            if let selectedSlice {
                                Text(percent(selectedSlice.paise)).font(.caption).foregroundStyle(Theme.muted)
                            }
                        }.frame(maxWidth: 145).allowsHitTesting(false)
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Confirmed expenses before refunds, \(Money.format(summary.grossPaise)). " + slices.map { "\($0.name), \(percent($0.paise))" }.joined(separator: ". "))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 8) {
                        ForEach(slices) { item in
                            Button { select(item) } label: {
                                HStack(spacing: 7) {
                                    Circle().fill(item.color).frame(width: 7, height: 7)
                                    Text(item.name).font(.caption)
                                }
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 10).padding(.vertical, 8)
                                .background(item.color.opacity(selectedSlice?.id == item.id ? 0.17 : 0.06), in: Capsule())
                            }.buttonStyle(.plain)
                            .accessibilityLabel("\(item.name), \(Money.format(item.paise)), \(percent(item.paise)) of expenses")
                            .accessibilityHint("Show or hide this category in the center of the donut")
                            .accessibilityAddTraits(selectedSlice?.id == item.id ? .isSelected : [])
                        }
                    }
                    Text(selectedSlice == nil ? "Tap a segment to explore" : "Tap its label again to show the total")
                        .font(.caption2).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)

                }
            } else {
                Panel {
                    Label("No confirmed expenses in this period", systemImage: "chart.pie").font(.subheadline.weight(.medium))
                    Text("Imported or reviewed expenses will appear here. Try Month or All to view older payments.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Text(coverage).font(.caption).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: periodLabel) { _, _ in selectedAngle = nil }
        .onChange(of: summary.categories) { _, _ in selectedAngle = nil }
    }
    private var metrics: some View {
        Group {
            metric("Spent", amount: summary.grossPaise)
            metric("Refunded", amount: summary.refundPaise)
            metric("Received", amount: summary.incomePaise)
        }
    }
    private func metric(_ label: String, amount: Int64) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(Theme.muted)
            Text(Money.format(amount)).font(.subheadline.weight(.semibold)).monospacedDigit().fixedSize()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
