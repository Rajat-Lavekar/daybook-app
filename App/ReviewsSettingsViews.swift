import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import DaybookCore

struct ReviewsView: View {
    @EnvironmentObject var model: AppModel
    @State private var scope = ReviewScope.finance
    @State private var excerpts = false
    @State private var health = false
    @State private var export = false
    @State private var importReport = false
    @State private var document = ExportDocument(data: Data())
    @State private var packetPreview = ""
    var body: some View {
        Page {
            PageHeader(eyebrow: "REVIEWS / WHEN YOU CHOOSE", title: "Notice. Adjust. Repeat.", detail: "Small observations and a next step. You decide when anything leaves this device.")
            Panel {
                Picker("Review scope", selection: $scope) { ForEach(ReviewScope.allCases) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
                if scope == .wellbeing {
                    Toggle("Include journal excerpts I've approved", isOn: $excerpts).font(.caption)
                    Toggle("Include available Health summaries", isOn: $health).font(.caption)
                    Text("Health summaries are for this wellbeing review only. They are excluded from finance and learning packets.").font(.caption).foregroundStyle(Theme.muted)
                }
                Button("Create a local summary") {
                    let report = model.packet(scope: scope).localReport()
                    model.update { $0.reviews.insert(report, at: 0) }
                }.buttonStyle(.borderedProminent)
                Button("Preview a packet for deeper analysis") {
                    do {
                        let data = try DaybookJSON.encode(model.packet(scope: scope, excerpts: excerpts, health: health))
                        document = ExportDocument(data: data); packetPreview = String(decoding: data, as: UTF8.self)
                    } catch { model.error = error.localizedDescription }
                }.buttonStyle(.bordered)
                Text("Local summaries use calculations and fixed prompts. Deeper AI analysis happens only when you explicitly share a packet in this chat.").font(.caption).foregroundStyle(Theme.muted)
                if !packetPreview.isEmpty {
                    DisclosureGroup("Exactly what will be exported") { Text(packetPreview).font(.system(size: 11, design: .monospaced)).textSelection(.enabled) }
                    Button("Export this selected packet") { export = true }.buttonStyle(.borderedProminent)
                    Text("This JSON file is plaintext. Choose a private location; no upload occurs automatically.").font(.caption).foregroundStyle(Theme.ochre)
                }
                Button("Import a returned review") { importReport = true }.font(.subheadline)
            }
            ForEach(model.snapshot.reviews) { review in
                Panel {
                    SectionLabel(text: review.date.formatted(date: .abbreviated, time: .omitted))
                    Text(review.title).font(.system(size: 24, design: .serif))
                    Text(review.body).font(.subheadline).lineSpacing(6).textSelection(.enabled)
                }
            }
        }.navigationTitle("Reviews")
            .onChange(of: scope) { _, _ in packetPreview = "" }
            .onChange(of: excerpts) { _, _ in packetPreview = "" }
            .onChange(of: health) { _, _ in packetPreview = "" }
            .fileExporter(isPresented: $export, document: document, contentType: .json, defaultFilename: "daybook-\(scope.rawValue)-packet.json") { result in if case .failure(let error) = result { model.error = error.localizedDescription } }
            .fileImporter(isPresented: $importReport, allowedContentTypes: [.json]) { result in
                do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try model.importReview(Data(contentsOf: url))
                } catch { model.error = error.localizedDescription }
            }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var exporting = false
    @State private var restoring = false
    @State private var archiveDocument = ExportDocument(data: Data())
    @State private var recoveryKey = ""
    @State private var restoreKey = ""
    @State private var keySaved = false
    @State private var importData: Data?
    @State private var incoming: ArchivePayload?
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    @State private var reminderStatus = ""
    @State private var clearDemo = false
    var body: some View {
        Page {
            PageHeader(eyebrow: "SETTINGS / PRIVATE BY DEFAULT", title: "Yours to keep.", detail: "No bank login, no automatic AI uploads, no cloud account.")
            Panel {
                SectionLabel(text: "Evening reflection")
                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                Button("Enable a daily local reminder") { scheduleReminder() }.buttonStyle(.bordered)
                Button("Turn off Daybook reminders") { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daybook.evening"]); reminderStatus = "Daily reminder removed." }.font(.caption)
                if !reminderStatus.isEmpty { Text(reminderStatus).font(.caption).foregroundStyle(Theme.muted) }
            }
            Panel {
                SectionLabel(text: "Encrypted archive")
                Text("Move a verified copy to your Mac.").font(.system(size: 24, design: .serif))
                Text("The archive includes app payments, journal entries, cached Health summaries, readings progress and reviews. It is encrypted with a unique recovery key. Keep the key separately; it cannot be recovered for you.").font(.caption).foregroundStyle(Theme.muted)
                if recoveryKey.isEmpty {
                    Button("Prepare encrypted archive") {
                        do { let archive = try Vault.seal(model.snapshot); archiveDocument = ExportDocument(data: archive.data); recoveryKey = archive.recoveryKey; keySaved = false }
                        catch { model.error = error.localizedDescription }
                    }.buttonStyle(.borderedProminent)
                } else {
                    Text("RECOVERY KEY · KEEP PRIVATE").font(.caption.weight(.bold)).foregroundStyle(Theme.ochre)
                    Text(recoveryKey).font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                    Toggle("I've saved this key separately", isOn: $keySaved).font(.caption)
                    Button("Save encrypted archive") { exporting = true }.buttonStyle(.borderedProminent).disabled(!keySaved)
                    Button("Discard this export") { recoveryKey = ""; archiveDocument = ExportDocument(data: Data()); keySaved = false }.font(.caption)
                }
                Text("This version exports and verifies archives. Automatic LAN sync and phone cleanup are not enabled, so an incomplete transfer cannot delete phone data.").font(.caption).foregroundStyle(Theme.muted)
            }
            Panel {
                SectionLabel(text: "Restore")
                SecureField("Archive recovery key", text: $restoreKey).inputStyle()
                Button("Choose encrypted archive") { restoring = true }.buttonStyle(.bordered).disabled(restoreKey.isEmpty)
                if let incoming {
                    Text("Verified: \(incoming.snapshot.transactions.count) payments and \(incoming.snapshot.checkIns.count) check-ins.").font(.caption)
                    if model.snapshot.transactions.isEmpty && model.snapshot.checkIns.isEmpty && model.snapshot.reviews.isEmpty && model.snapshot.health.isEmpty && model.snapshot.completedLessons.isEmpty && model.snapshot.bookmarkedLessons.isEmpty {
                        Button("Restore into this empty app") { model.update { $0 = incoming.snapshot }; self.incoming = nil; restoreKey = ""; model.notice = "Archive restored." }.buttonStyle(.borderedProminent)
                    } else {
                        Text("Restore is restricted to an empty app to avoid overwriting your current records. Keep both archives; merging is not implemented yet.").font(.caption).foregroundStyle(Theme.ochre)
                    }
                }
            }
            Panel {
                SectionLabel(text: "UPI automation setup")
                Text("On iPhone, create a Shortcuts Message automation for your bank sender. Pass the received message text to Daybook's Capture Bank Alert action and select Run Immediately. Configure Kotak and HDFC separately.").font(.subheadline)
                Text("The action saves provisional records. It cannot read your historical SMS inbox. Locked-phone execution, bank templates and free-signing expiration need device testing. Keep statement reconciliation as a fallback.").font(.caption).foregroundStyle(Theme.muted)
            }
            if model.snapshot.isDemo {
                Button("Clear sample data and start fresh") { clearDemo = true }.buttonStyle(.bordered)
            }
            Panel {
                SectionLabel(text: "About this first build")
                Text("Daybook 0.3.0 · local prototype").font(.subheadline)
                Text("GPay PDFs are checked against their statement totals. Kotak/HDFC alert formats have sample-based tests; automatic capture still needs device testing. Apple Health refresh is manual. Readings work offline.").font(.caption).foregroundStyle(Theme.muted)
            }
        }.navigationTitle("Settings").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .fileExporter(isPresented: $exporting, document: archiveDocument, contentType: .data, defaultFilename: "daybook-backup.daybook") { result in
                switch result { case .failure(let error): model.error = error.localizedDescription
                case .success: model.notice = "Encrypted archive saved. Verify it on your Mac before relying on it. Phone data has not been removed." }
            }
            .fileImporter(isPresented: $restoring, allowedContentTypes: [.data]) { result in
                do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    incoming = try Vault.open(Data(contentsOf: url), recoveryKey: restoreKey)
                } catch { model.error = error.localizedDescription }
            }
            .confirmationDialog("Remove the fictional sample data?", isPresented: $clearDemo) { Button("Clear sample data", role: .destructive) { model.clearDemo() } }
            .frame(minWidth: 360, minHeight: 650)
    }
    private func scheduleReminder() {
        Task {
            do {
                let center = UNUserNotificationCenter.current()
                guard try await center.requestAuthorization(options: [.alert, .sound]) else { reminderStatus = "Notifications are not enabled. You can still check in from the app."; return }
                let content = UNMutableNotificationContent(); content.title = "A moment for you"; content.body = "Pause and reflect on your day."; content.sound = .default
                let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                try await center.add(UNNotificationRequest(identifier: "daybook.evening", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
                reminderStatus = "Reminder set for \(reminderTime.formatted(date: .omitted, time: .shortened)). Focus settings may silence it."
            } catch { reminderStatus = error.localizedDescription }
        }
    }
}
