import Foundation
import DaybookCore


// Dependency-free assertions let the same regression cases run with CLT or XCTest.
private var failures: [String] = []
private func record(_ message: String, _ line: UInt) { failures.append("Line \(line): \(message)") }
private func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, line: UInt = #line) { if a != b { record("Expected \(b), got \(a)", line) } }
private func XCTAssertNil<T>(_ value: T?, line: UInt = #line) { if value != nil { record("Expected nil", line) } }
private func XCTAssertTrue(_ value: Bool, line: UInt = #line) { if !value { record("Expected true", line) } }
private func XCTAssertFalse(_ value: Bool, line: UInt = #line) { if value { record("Expected false", line) } }
private func XCTAssertThrowsError<T>(_ value: @autoclosure () throws -> T, line: UInt = #line) {
    do { _ = try value(); record("Expected an error", line) } catch { }
}

public final class CoreChecks {
    public init() {}
    func testMoneyUsesExactPaiseAndRejectsAmbiguity() {
        XCTAssertEqual(Money.parse("1,23,456.78"), 12_345_678)
        XCTAssertEqual(Money.parse("0.1"), 10)
        XCTAssertNil(Money.parse("12.345")); XCTAssertNil(Money.parse("-1")); XCTAssertNil(Money.parse("1e5"))
    }
    func testSpendingExcludesTransfersIncomeAndUnconfirmed() {
        let items = [
            Transaction(amountPaise: 10000, merchant: "Lunch", category: .dining),
            Transaction(amountPaise: 2000, merchant: "Refund", kind: .refund),
            Transaction(amountPaise: 90000, merchant: "Salary", kind: .income),
            Transaction(amountPaise: 40000, merchant: "Other account", kind: .transfer),
            Transaction(amountPaise: 50000, merchant: "Fund", kind: .investment),
            Transaction(amountPaise: 8000, merchant: "Pending", status: .pending),
            Transaction(amountPaise: 7000, merchant: "Alert", status: .provisional),
            Transaction(amountPaise: 6000, merchant: "Failed", status: .failed)
        ]
        let summary = Finance.summary(items)
        XCTAssertEqual(summary.grossPaise, 10000); XCTAssertEqual(summary.netPaise, 8000)
        XCTAssertEqual(summary.provisionalPaise, 7000); XCTAssertEqual(summary.incomePaise, 90000)
    }
    func testSameAmountSameTimeDoesNotSilentlyMerge() {
        var snapshot = Snapshot(); let date = Date()
        Finance.ingest([Transaction(amountPaise: 100, date: date, merchant: "Coffee"), Transaction(amountPaise: 100, date: date, merchant: "Coffee")], into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 2)
    }
    func testOverlappingImportPreservesUserEditsAndOriginalNote() {
        var snapshot = Snapshot()
        var entry = Transaction(amountPaise: 20000, merchant: "Vendor", account: "Kotak · 1234", reference: "123456789012", category: .health, status: .provisional)
        entry.memo = "My correction"
        Finance.ingest([entry], into: &snapshot)
        let confirmed = Transaction(amountPaise: 20000, merchant: "Vendor", account: "Kotak · 1234", reference: "123456789012", originalNote: "preserve exactly", category: .dining)
        Finance.ingest([confirmed, confirmed], into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 1)
        XCTAssertEqual(snapshot.transactions[0].memo, "My correction")
        XCTAssertEqual(snapshot.transactions[0].category, .health)
        XCTAssertEqual(snapshot.transactions[0].status, .confirmed)
        XCTAssertEqual(snapshot.transactions[0].originalNote, "preserve exactly")
    }
    func testCSVQuotedMultilineNoteAndRejectedRowsAreVisible() throws {
        let csv = "date,amount,merchant,account,note\n2026-09-12,250.01,\"Cafe, One\",Kotak,\"Lunch\nwith a friend\"\n2026-02-30,25,Invalid,Kotak,\n"
        let parsed = try CSVImporter.parse(csv)
        XCTAssertEqual(parsed.entries.count, 1); XCTAssertEqual(parsed.issues.count, 1)
        XCTAssertEqual(parsed.entries[0].originalNote, "Lunch\nwith a friend")
        XCTAssertEqual(parsed.entries[0].amountPaise, 25001)
        XCTAssertEqual(parsed.entries[0].status, .provisional)
        XCTAssertThrowsError(try CSVImporter.parse("date,date,amount,merchant,account\n"))
    }
    func testBankAlertsAreProvisionalAndCannotBeOTPs() throws {
        let sms = "Rs.250.00 debited from Kotak Bank A/c XX1234 to CAFE on 12-09-2026 UPI Ref 123456789012"
        let result = try BankAlertParser.parse(sms)
        XCTAssertEqual(result.amountPaise, 25000); XCTAssertEqual(result.status, .provisional)
        XCTAssertEqual(result.merchant, "CAFE")
        XCTAssertEqual(result.account, "Kotak · 1234"); XCTAssertEqual(result.reference, "123456789012")
        XCTAssertThrowsError(try BankAlertParser.parse("HDFC OTP 123456 for Rs.100 sent to your phone"))
        XCTAssertThrowsError(try BankAlertParser.parse("Kotak: Your balance is Rs.250.00"))
        XCTAssertThrowsError(try BankAlertParser.parse("HDFC Rs.250.00 will be debited for mandate"))
    }
    func testRecreationSurvivesImportArchiveAndRepeatEvidence() throws {
        let csv = "date,amount,merchant,account,category,status,reference\n2026-09-12,450.50,Weekend activity,Kotak,Recreation,confirmed,123456789099\n"
        let imported = try CSVImporter.parse(csv)
        XCTAssertEqual(imported.entries.count, 1)
        XCTAssertEqual(imported.entries.first?.category, .recreation)
        var state = Demo.snapshot()
        Finance.ingest(imported.entries, into: &state)
        state.merchantRules["weekend activity"] = .recreation
        let sealed = try Vault.seal(state)
        var restored = try Vault.open(sealed.data, recoveryKey: sealed.recoveryKey).snapshot
        let count = restored.transactions.count
        Finance.ingest(imported.entries, into: &restored)
        XCTAssertEqual(restored.transactions.count, count)
        XCTAssertEqual(restored.merchantRules["weekend activity"], .recreation)
        XCTAssertEqual(Finance.summary(restored.transactions).categories["Recreation"], 45050)
        XCTAssertEqual(restored.transactions.first?.category, state.transactions.first?.category)
    }
    func testArchiveRoundTripRejectsTamperAndWrongKey() throws {
        let snapshot = Demo.snapshot(); let sealed = try Vault.seal(snapshot)
        let opened = try Vault.open(sealed.data, recoveryKey: sealed.recoveryKey)
        XCTAssertEqual(opened.snapshot.transactions, snapshot.transactions.map { transaction in
            var value = transaction
            // JSON ISO8601 serialization intentionally has second precision.
            value.date = Date(timeIntervalSince1970: floor(value.date.timeIntervalSince1970))
            value.updatedAt = Date(timeIntervalSince1970: floor(value.updatedAt.timeIntervalSince1970))
            return value
        })
        var tampered = sealed.data; tampered[tampered.count - 1] ^= 0xFF
        XCTAssertThrowsError(try Vault.open(tampered, recoveryKey: sealed.recoveryKey))
        XCTAssertThrowsError(try Vault.open(sealed.data, recoveryKey: Data(repeating: 0, count: 32).base64EncodedString()))
    }
    func testReviewScopeDoesNotLeakRawFinancialOrJournalText() throws {
        var snapshot = Snapshot()
        snapshot.transactions = [Transaction(amountPaise: 100, merchant: "PRIVATE MERCHANT", account: "PRIVATE ACCOUNT", originalNote: "PRIVATE NOTE")]
        snapshot.checkIns = [CheckIn(helped: "PRIVATE JOURNAL", allowExcerpt: true)]
        let packet = ReviewPacket(snapshot: snapshot, scope: .finance, from: .distantPast, to: .distantFuture)
        let text = String(decoding: try DaybookJSON.encode(packet), as: UTF8.self)
        XCTAssertFalse(text.contains("PRIVATE")); XCTAssertNil(packet.health); XCTAssertNil(packet.selectedExcerpts)
        let wellbeing = ReviewPacket(snapshot: snapshot, scope: .wellbeing, from: .distantPast, to: .distantFuture)
        XCTAssertNil(wellbeing.spending); XCTAssertNil(wellbeing.selectedExcerpts)
    }
    func testOverlappingSleepAndMidnight() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = ISO8601DateFormatter().date(from: "2026-09-11T22:00:00Z")!
        let spans = [TimeSpan(start: start, end: start.addingTimeInterval(5 * 3600)), TimeSpan(start: start.addingTimeInterval(4 * 3600), end: start.addingTimeInterval(8 * 3600))]
        XCTAssertEqual(HealthMath.duration(spans), 8 * 3600)
        let daily = HealthMath.sleepByWakeDate(spans, calendar: calendar)
        XCTAssertEqual(daily.count, 1); XCTAssertEqual(daily[calendar.startOfDay(for: start.addingTimeInterval(8 * 3600))], 8)
    }
    func testCorruptStoreIsNeverReplaced() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json"); let data = Data("bad data".utf8)
        try data.write(to: url)
        XCTAssertThrowsError(try SnapshotStore(url: url).update { $0 = Snapshot() })
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    func testIdenticalUnreferencedPaymentsAreRetained() throws {
        let csv = "date,amount,merchant,account\n2026-09-12,50,Coffee,Kotak\n2026-09-12,50,Coffee,Kotak\n"
        let result = try CSVImporter.parse(csv)
        var snapshot = Snapshot()
        Finance.ingest(result.entries, into: &snapshot)
        Finance.ingest(try CSVImporter.parse(csv).entries, into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 2)
        let alert = "HDFC Rs.50 debited to CAFE"
        Finance.ingest([try BankAlertParser.parse(alert), try BankAlertParser.parse(alert)], into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 4)
    }
    func testSuppliedSMSFormatsWithFictionalIdentifiers() throws {
        let sent = try BankAlertParser.parse("Sent Rs.315.00 from Kotak Bank A/c X1234 to Example Shop on 18-09-26. UPI Ref 111111111111. Not done by you? Tap https://example.invalid/report")
        XCTAssertEqual(sent.amountPaise, 31500); XCTAssertEqual(sent.merchant, "Example Shop")
        XCTAssertEqual(sent.account, "Kotak · 1234"); XCTAssertEqual(sent.reference, "111111111111")
        XCTAssertEqual(sent.date, ISO8601DateFormatter().date(from: "2026-09-17T18:30:00Z"))
        XCTAssertEqual(sent.status, .provisional)
        let hdfc = try BankAlertParser.parse("Sent Rs.75.00\nFrom HDFC Bank A/C *5678\nTo SAMPLE PERSON\nOn 12/09/26\nRef 222222222222\nNot You?\nCall 18000000000/SMS BLOCK UPI to 7000000000")
        XCTAssertEqual(hdfc.merchant, "SAMPLE PERSON"); XCTAssertEqual(hdfc.account, "HDFC · 5678")
        XCTAssertEqual(hdfc.date, ISO8601DateFormatter().date(from: "2026-09-11T18:30:00Z"))
        let received = try BankAlertParser.parse("Received Rs.1700.00 in your Kotak Bank AC 1234 from SAMPLE PERSON on 07-09-26.UPI Ref:333333333333")
        XCTAssertEqual(received.kind, .income); XCTAssertEqual(received.merchant, "SAMPLE PERSON")
        XCTAssertEqual(received.reference, "333333333333")
        XCTAssertThrowsError(try BankAlertParser.parse("Sent Rs.1.00 from Kotak Bank A/c X1234 to Example on 31-02-26. UPI Ref 111111111111"))
    }
    func testAlertTimestampProvenanceAndReplay() throws {
        let text = "Sent Rs.75.00 From HDFC Bank A/C *5678 To SAMPLE PERSON On 12/09/26 Ref 222222222222"
        let messageDate = ISO8601DateFormatter().date(from: "2026-09-12T17:25:00Z")!
        let later = messageDate.addingTimeInterval(86400)
        let message = try BankAlertParser.parse(text, receivedAt: later, messageTimestamp: messageDate, useCaptureTime: true)
        XCTAssertEqual(message.date, messageDate)
        XCTAssertEqual(message.timeSource, .messageTimestamp)
        XCTAssertEqual(message.bankReportedDate, ISO8601DateFormatter().date(from: "2026-09-11T18:30:00Z"))
        let live = try BankAlertParser.parse(text, receivedAt: messageDate, useCaptureTime: true)
        XCTAssertEqual(live.date, messageDate); XCTAssertEqual(live.timeSource, .automationRun)
        let historical = try BankAlertParser.parse(text, receivedAt: later, useCaptureTime: true)
        XCTAssertEqual(historical.timeSource, .bankDateOnly)
        XCTAssertEqual(historical.date, message.bankReportedDate)
        let manual = try BankAlertParser.parse(text, receivedAt: messageDate)
        XCTAssertEqual(manual.timeSource, .bankDateOnly)
        var snapshot = Snapshot()
        Finance.ingest([message], into: &snapshot)
        Finance.ingest([try BankAlertParser.parse(text, receivedAt: later, useCaptureTime: true)], into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 1)
        XCTAssertEqual(snapshot.transactions[0].date, messageDate)
        let data = try DaybookJSON.encode(snapshot)
        XCTAssertEqual(try DaybookJSON.decode(Snapshot.self, from: data).transactions[0].timeSource, .messageTimestamp)
        var legacy = try JSONSerialization.jsonObject(with: DaybookJSON.encode(message)) as! [String: Any]
        legacy.removeValue(forKey: "timeSource"); legacy.removeValue(forKey: "bankReportedDate")
        XCTAssertNil(try DaybookJSON.decode(Transaction.self, from: JSONSerialization.data(withJSONObject: legacy)).timeSource)
    }

    func testFutureMandateAndNonUPICredit() throws {
        XCTAssertThrowsError(try BankAlertParser.parse("E-Mandate! Rs.123.00 will be deducted on 31/08/26, 00:00:00 For CRED CCBP mandate UMN fictional@provider Maintain Balance -HDFC Bank"))
        let dividend = try BankAlertParser.parse("INR 15.40 is credited to your Account XXXXXX1234 on 09/09/2026 towards NACH-ECS-EXAMPLE DIV 2025-2 Kotak Bank")
        XCTAssertEqual(dividend.kind, .income); XCTAssertEqual(dividend.amountPaise, 1540)
        XCTAssertEqual(dividend.merchant, "NACH-ECS-EXAMPLE DIV 2025-2")
        XCTAssertEqual(dividend.reference, ""); XCTAssertTrue(dividend.memo.contains("not a UPI"))
    }
    func testTwoSidesOfTransferRemainNormalSeparateRecords() throws {
        let debit = try BankAlertParser.parse("Sent Rs.250.00 From HDFC Bank A/C *5678 To SAMPLE OWNER On 11/09/26 Ref 444444444444 Not You?")
        let credit = try BankAlertParser.parse("Received Rs.250.00 in your Kotak Bank AC 1234 from SAMPLE OWNER on 11-09-26.UPI Ref:444444444444")
        var snapshot = Snapshot()
        Finance.ingest([debit, credit, debit, credit], into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 2)
        XCTAssertEqual(Set(snapshot.transactions.map(\.kind)), Set([.expense, .income]))
    }

    private var gpayFixture: String {
        """
        Transaction statement
        Transaction statement period
        01 August 2026 - 31 August 2026
        Sent
        ₹100.25
        Received
        ₹20
        Date & time Transaction details Amount
        01 Aug, 2026
        01:49 PM
        Paid to Example merchant
        with a wrapped name
        UPI Transaction ID: 555555555555
        Paid by HDFC Bank 5678
        ₹100.25
        02 Aug, 2026
        10:10 AM
        Received from Sample Person
        UPI Transaction ID: 666666666666
        Paid to Kotak Mahindra Bank 1234
        ₹20
        03 Aug, 2026
        11:11 AM
        Self transfer to Kotak Mahindra Bank 1234
        UPI Transaction ID: 777777777777
        Paid by HDFC Bank 5678
        ₹1,000
        Note: This statement reflects payments made by you on the Google Pay app. Self transfer payments are not included in the total money paid and
        received. Deleted activity is not included.
        Page 1 of 1
        """
    }
    func testGPayRowsTotalsAndManualTransferClassification() throws {
        let parsed = try GPayStatementImporter.parse(pages: [gpayFixture])
        XCTAssertEqual(parsed.entries.count, 3); XCTAssertEqual(parsed.issues, []); XCTAssertTrue(parsed.canImport)
        XCTAssertEqual(parsed.entries[0].merchant, "Example merchant with a wrapped name")
        XCTAssertEqual(parsed.entries[0].account, "HDFC · 5678")
        XCTAssertEqual(parsed.entries[0].date, ISO8601DateFormatter().date(from: "2026-08-01T08:19:00Z"))
        XCTAssertTrue(parsed.entries.allSatisfy { $0.originalNote.isEmpty })
        XCTAssertEqual(parsed.entries[2].kind, .expense)
        XCTAssertEqual(parsed.statement?.selfTransferCount, 1)
        XCTAssertEqual(Finance.summary(parsed.entries).grossPaise, 110025)
    }
    func testGPayBlocksPartialAndMismatchedImports() throws {
        let mismatch = try GPayStatementImporter.parse(pages: [gpayFixture.replacingOccurrences(of: "₹100.25\nReceived", with: "₹101.25\nReceived")])
        XCTAssertFalse(mismatch.canImport); XCTAssertFalse(mismatch.issues.isEmpty)
        let invalid = try GPayStatementImporter.parse(pages: [gpayFixture.replacingOccurrences(of: "UPI Transaction ID: 555555555555", with: "UPI Transaction ID: invalid")])
        XCTAssertFalse(invalid.canImport); XCTAssertEqual(invalid.entries.count, 2)
        let truncated = try GPayStatementImporter.parse(pages: [gpayFixture.replacingOccurrences(of: "Page 1 of 1", with: "Page 1 of 2")])
        XCTAssertFalse(truncated.canImport)
        let extraField = try GPayStatementImporter.parse(pages: [gpayFixture.replacingOccurrences(of: "₹100.25\n02 Aug", with: "₹100.25\nUnknown payment metadata\n02 Aug")])
        XCTAssertFalse(extraField.canImport)
        XCTAssertThrowsError(try GPayStatementImporter.parse(pages: ["Not a statement"]))
    }
    func testGPayAndSMSOverlapPreservesCorrections() throws {
        let sms = try BankAlertParser.parse("Sent Rs.100.25 From HDFC Bank A/C *5678 To Example merchant On 01/08/26 Ref 555555555555 Not You?")
        var snapshot = Snapshot(); Finance.ingest([sms], into: &snapshot)
        snapshot.transactions[0].memo = "My private memo"; snapshot.transactions[0].category = .health
        let parsed = try GPayStatementImporter.parse(pages: [gpayFixture])
        Finance.ingest(parsed.entries, into: &snapshot); Finance.ingest(parsed.entries, into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 3)
        let entry = snapshot.transactions.first { $0.reference == "555555555555" }
        XCTAssertEqual(entry?.memo, "My private memo"); XCTAssertEqual(entry?.category, .health)
        XCTAssertEqual(entry?.status, .confirmed)
        let changedIndex = snapshot.transactions.firstIndex { $0.reference == "555555555555" }!
        snapshot.transactions[changedIndex].kind = .transfer
        Finance.ingest(parsed.entries, into: &snapshot)
        XCTAssertEqual(snapshot.transactions.count, 3)
        XCTAssertEqual(snapshot.transactions.first { $0.reference == "555555555555" }?.kind, .transfer)
    }
    func testIndependentStoreWritersPreserveAllRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        XCTAssertEqual(try SnapshotStore(url: url).read().transactions.count, 0)
        let lock = NSLock(); var writeErrors: [String] = []
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            do { try SnapshotStore(url: url).update { $0.transactions.append(Transaction(amountPaise: 100, merchant: "Synthetic \(index)")) } }
            catch { lock.lock(); writeErrors.append(error.localizedDescription); lock.unlock() }
        }
        XCTAssertEqual(writeErrors, [])
        XCTAssertEqual(try SnapshotStore(url: url).read().transactions.count, 20)
    }
    func testMacArchiveAndReviewWorkflow() throws {
        #if os(macOS)
        let cli = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/debug/daybook")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: cli.path))
        guard FileManager.default.isExecutableFile(atPath: cli.path) else { return }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let sealed = try Vault.seal(Demo.snapshot())
        let archive = directory.appendingPathComponent("input.daybook")
        let key = directory.appendingPathComponent("recovery.key")
        try sealed.data.write(to: archive)
        try Data(sealed.recoveryKey.utf8).write(to: key)
        func run(_ arguments: [String]) throws -> Int32 {
            let process = Process(); process.executableURL = cli; process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try process.run(); process.waitUntilExit(); return process.terminationStatus
        }
        let input = ["--file", archive.path, "--key-file", key.path]
        XCTAssertEqual(try run(["verify"] + input), 0)
        XCTAssertEqual(try run(["archive"] + input + ["--to", directory.appendingPathComponent("saved").path]), 0)
        XCTAssertEqual(try run(["archive"] + input + ["--to", directory.appendingPathComponent("saved").path]), 1)
        let packetURL = directory.appendingPathComponent("packet.json")
        XCTAssertEqual(try run(["prepare-review"] + input + ["--scope", "finance", "--out", packetURL.path]), 0)
        let packet = try DaybookJSON.decode(ReviewPacket.self, from: Data(contentsOf: packetURL))
        XCTAssertEqual(packet.scope, .finance); XCTAssertTrue(packet.demoData)
        let reportURL = directory.appendingPathComponent("result.review.json")
        XCTAssertEqual(try run(["report-template", "--packet", packetURL.path, "--out", reportURL.path]), 0)
        let report = try DaybookJSON.decode(Review.self, from: Data(contentsOf: reportURL))
        XCTAssertEqual(report.packetID, packet.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))
        let permissions = try FileManager.default.attributesOfItem(atPath: packetURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        #endif
    }

    public func run() -> [(name: String, failures: [String])] {
        let cases: [(String, () throws -> Void)] = [
            ("testMoneyUsesExactPaiseAndRejectsAmbiguity", testMoneyUsesExactPaiseAndRejectsAmbiguity),
            ("testSpendingExcludesTransfersIncomeAndUnconfirmed", testSpendingExcludesTransfersIncomeAndUnconfirmed),
            ("testSameAmountSameTimeDoesNotSilentlyMerge", testSameAmountSameTimeDoesNotSilentlyMerge),
            ("testOverlappingImportPreservesUserEditsAndOriginalNote", testOverlappingImportPreservesUserEditsAndOriginalNote),
            ("testCSVQuotedMultilineNoteAndRejectedRowsAreVisible", testCSVQuotedMultilineNoteAndRejectedRowsAreVisible),
            ("testBankAlertsAreProvisionalAndCannotBeOTPs", testBankAlertsAreProvisionalAndCannotBeOTPs),
            ("testRecreationSurvivesImportArchiveAndRepeatEvidence", testRecreationSurvivesImportArchiveAndRepeatEvidence),
            ("testArchiveRoundTripRejectsTamperAndWrongKey", testArchiveRoundTripRejectsTamperAndWrongKey),
            ("testReviewScopeDoesNotLeakRawFinancialOrJournalText", testReviewScopeDoesNotLeakRawFinancialOrJournalText),
            ("testOverlappingSleepAndMidnight", testOverlappingSleepAndMidnight),
            ("testCorruptStoreIsNeverReplaced", testCorruptStoreIsNeverReplaced),
            ("testIdenticalUnreferencedPaymentsAreRetained", testIdenticalUnreferencedPaymentsAreRetained),
            ("testIndependentStoreWritersPreserveAllRecords", testIndependentStoreWritersPreserveAllRecords),
            ("testMacArchiveAndReviewWorkflow", testMacArchiveAndReviewWorkflow),
            ("testSuppliedSMSFormatsWithFictionalIdentifiers", testSuppliedSMSFormatsWithFictionalIdentifiers),
            ("testAlertTimestampProvenanceAndReplay", testAlertTimestampProvenanceAndReplay),
            ("testFutureMandateAndNonUPICredit", testFutureMandateAndNonUPICredit),
            ("testTwoSidesOfTransferRemainNormalSeparateRecords", testTwoSidesOfTransferRemainNormalSeparateRecords),
            ("testGPayRowsTotalsAndManualTransferClassification", testGPayRowsTotalsAndManualTransferClassification),
            ("testGPayBlocksPartialAndMismatchedImports", testGPayBlocksPartialAndMismatchedImports),
            ("testGPayAndSMSOverlapPreservesCorrections", testGPayAndSMSOverlapPreservesCorrections),
        ]
        return cases.map { name, execute in
            failures = []
            do { try execute() } catch { failures.append("Unexpected error: \(error)") }
            return (name, failures)
        }
    }
}
