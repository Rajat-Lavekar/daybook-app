#if os(iOS)
import AppIntents
import DaybookCore

struct CaptureBankAlertIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Bank Alert"
    static var description = IntentDescription("Parse one Kotak/HDFC transaction message as a provisional Daybook record. No inbox access.")
    static var openAppWhenRun = false
    @Parameter(title: "Bank message") var message: String
    @Parameter(title: "Message timestamp", description: "Optional original message date and time. If absent, same-day alerts use the automation run time as an estimate.") var messageTimestamp: Date?
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let entry = try BankAlertParser.parse(message, messageTimestamp: messageTimestamp, useCaptureTime: true)
        let store = SnapshotStore(url: AppModel.storeURL())
        var inserted = 0
        try store.update { state in
            guard !state.isDemo else { throw DaybookError.invalid("Clear Daybook's sample data before capturing real payments.") }
            inserted = Finance.ingest([entry], into: &state)
            state.coverageNote = "Bank alerts only. Missed messages and statement periods have not been reconciled."
        }
        return .result(dialog: inserted == 0 ? "This alert was already captured." : "Payment captured for review.")
    }
}
#endif
