import Foundation
import PDFKit

public struct StatementSummary: Codable, Sendable {
    public var from: Date
    public var through: Date
    public var expectedSentPaise: Int64
    public var expectedReceivedPaise: Int64
    public var parsedSentPaise: Int64
    public var parsedReceivedPaise: Int64
    public var selfTransferPaise: Int64
    public var selfTransferCount: Int
    public var pageCount: Int
    public var totalsMatch: Bool { expectedSentPaise == parsedSentPaise && expectedReceivedPaise == parsedReceivedPaise }
    public var coverage: String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_IN")
        formatter.timeZone = CaptureText.indiaCalendar.timeZone; formatter.dateFormat = "d MMM yyyy"
        return "GPay statement \(formatter.string(from: from))–\(formatter.string(from: through)); PDF totals checked. Covers only records present in this GPay export, not all bank activity."
    }
}

public enum GPayStatementImporter {
    public static func parse(data: Data) throws -> ImportResult {
        guard data.count <= 30_000_000 else { throw DaybookError.invalid("Choose a GPay PDF smaller than 30 MB.") }
        guard let pdf = PDFDocument(data: data), !pdf.isLocked, (1...300).contains(pdf.pageCount) else {
            throw DaybookError.invalid("Choose an unlocked, text-based GPay statement PDF (up to 300 pages).")
        }
        let pages = (0..<pdf.pageCount).map { pdf.page(at: $0)?.string ?? "" }
        return try parse(pages: pages)
    }

    /// Strict parser for the supplied GPay text-PDF layout. Any unparsed row or
    /// total mismatch blocks import; no OCR guesses and no fabricated payment notes.
    public static func parse(pages: [String]) throws -> ImportResult {
        guard let first = pages.first, !first.isEmpty, pages.count <= 300,
              first.contains("Transaction statement period"), first.contains("Google Pay app") else {
            throw DaybookError.invalid("This is not the supported GPay statement layout. Scanned PDFs need a text export.")
        }
        let dateFormatter = DateFormatter(); dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = CaptureText.indiaCalendar; dateFormatter.timeZone = CaptureText.indiaCalendar.timeZone
        dateFormatter.dateFormat = "dd MMMM yyyy"; dateFormatter.isLenient = false
        guard let period = CaptureText.match(#"Transaction statement period\s+(\d{2} [A-Za-z]+ \d{4})\s*-\s*(\d{2} [A-Za-z]+ \d{4})"#, in: first),
              let start = dateFormatter.date(from: period[0]), let end = dateFormatter.date(from: period[1]), start <= end,
              let sent = CaptureText.match(#"\bSent\s*₹([\d,]+(?:\.\d{1,2})?)"#, in: first)?.first.flatMap(Money.parse),
              let received = CaptureText.match(#"\bReceived\s*₹([\d,]+(?:\.\d{1,2})?)"#, in: first)?.first.flatMap(Money.parse) else {
            throw DaybookError.invalid("The statement period or summary totals are missing. Import has not been attempted.")
        }
        let endExclusive = CaptureText.indiaCalendar.date(byAdding: .day, value: 1, to: end)!
        var result = ImportResult()
        var summary = StatementSummary(from: start, through: end, expectedSentPaise: sent, expectedReceivedPaise: received,
            parsedSentPaise: 0, parsedReceivedPaise: 0, selfTransferPaise: 0, selfTransferCount: 0, pageCount: pages.count)
        var identities: Set<String> = []
        for (pageIndex, page) in pages.enumerated() {
            let lines = page.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            guard let numbering = CaptureText.match(#"Page\s+(\d+)\s+of\s+(\d+)"#, in: page),
                  Int(numbering[0]) == pageIndex + 1, Int(numbering[1]) == pages.count else {
                result.issues.append("Page \(pageIndex + 1): page numbering is missing or inconsistent."); continue
            }
            let starts = lines.indices.filter { lines[$0].range(of: #"^\d{2} [A-Za-z]{3}, \d{4}$"#, options: .regularExpression) != nil }
            let references = lines.filter { $0.hasPrefix("UPI Transaction ID:") }.count
            if starts.count != references || starts.isEmpty {
                result.issues.append("Page \(pageIndex + 1): transaction dates and references do not align.")
            }
            for (rowIndex, offset) in starts.enumerated() {
                let limit = rowIndex + 1 < starts.count ? starts[rowIndex + 1] : lines.count
                var block = Array(lines[offset..<limit])
                if let footer = block.firstIndex(where: { $0.hasPrefix("Note:") || $0.hasPrefix("Page ") || $0.hasPrefix("Powered by") }) { block = Array(block[..<footer]) }
                do {
                    let (entry, selfTransfer) = try parseRow(block, from: start, to: endExclusive)
                    let identity = "\(entry.account)|\(entry.reference)|\(entry.kind.rawValue)"
                    guard identities.insert(identity).inserted else { throw DaybookError.invalid("Repeated transaction reference within this PDF.") }
                    result.entries.append(entry)
                    if selfTransfer { summary.selfTransferCount += 1; summary.selfTransferPaise += entry.amountPaise }
                    else if entry.kind == .income { summary.parsedReceivedPaise += entry.amountPaise }
                    else { summary.parsedSentPaise += entry.amountPaise }
                } catch { result.issues.append("Page \(pageIndex + 1), row \(rowIndex + 1): \(error.localizedDescription)") }
            }
        }
        if result.entries.isEmpty { result.issues.append("No supported transactions were found.") }
        if !summary.totalsMatch { result.issues.append("Parsed sent/received amounts do not match the PDF summary. Import is blocked.") }
        result.statement = summary
        return result
    }

    private static func parseRow(_ lines: [String], from: Date, to: Date) throws -> (Transaction, Bool) {
        guard lines.count >= 6,
              let refIndex = lines.firstIndex(where: { $0.hasPrefix("UPI Transaction ID:") }), refIndex >= 3,
              lines.count == refIndex + 3,
              let reference = CaptureText.match(#"^UPI Transaction ID:\s*(\d{12})$"#, in: lines[refIndex])?.first,
              let amountString = CaptureText.match(#"^₹([\d,]+(?:\.\d{1,2})?)$"#, in: lines[refIndex + 2])?.first,
              let amount = Money.parse(amountString), amount > 0 else {
            throw DaybookError.invalid("Unsupported row layout, reference or amount; no guessed values were used.")
        }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = CaptureText.indiaCalendar; formatter.timeZone = CaptureText.indiaCalendar.timeZone
        formatter.dateFormat = "dd MMM, yyyy hh:mm a"; formatter.isLenient = false
        let timestamp = "\(lines[0]) \(lines[1])"
        guard let date = formatter.date(from: timestamp), formatter.string(from: date) == timestamp, date >= from, date < to else {
            throw DaybookError.invalid("Invalid timestamp or payment outside the statement period.")
        }
        let description = lines[2..<refIndex].joined(separator: " ")
        let incoming = description.hasPrefix("Received from "), selfTransfer = description.hasPrefix("Self transfer to ")
        let prefix = incoming ? "Received from " : selfTransfer ? "Self transfer to " : "Paid to "
        guard description.hasPrefix(prefix), description.count > prefix.count else { throw DaybookError.invalid("Unsupported payment direction.") }
        let accountPrefix = incoming ? "Paid to " : "Paid by "
        let bankLine = lines[refIndex + 1]
        guard bankLine.hasPrefix(accountPrefix) else { throw DaybookError.invalid("Account direction disagrees with the payment.") }
        let bank = String(bankLine.dropFirst(accountPrefix.count))
        guard CaptureText.match(#"^(.+\bBank)\s+(\d{4})$"#, in: bank) != nil else { throw DaybookError.invalid("The bank/account label is unsupported.") }
        let account = CaptureText.canonicalAccount(bank)
        let kind: EntryKind = incoming ? .income : .expense
        var memo = "GPay PDF record. This format does not include the original payment note."
        if selfTransfer { memo += " GPay labels this as a self-transfer and excludes it from its Sent total. Kept as a normal debit; change Kind if desired." }
        return (Transaction(amountPaise: amount, date: date, merchant: String(description.dropFirst(prefix.count)),
            account: account, reference: reference, memo: memo, kind: kind, status: .confirmed, source: "GPay PDF",
            fingerprint: Finance.fingerprint("gpay|\(account)|\(reference)|\(kind.rawValue)|\(amount)")), selfTransfer)
    }
}
