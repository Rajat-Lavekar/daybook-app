import Foundation

enum CaptureText {
    static func match(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<result.numberOfRanges).map { index in
            Range(result.range(at: index), in: text).map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        }
    }
    static func flat(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func account(bank: String, suffix: String) -> String { "\(bank) · \(suffix)" }
    static func canonicalAccount(_ label: String) -> String {
        guard let suffix = match(#"(?:[Xx*•· ]|^)(\d{4})\s*$"#, in: label)?.first else { return label }
        let lower = label.lowercased()
        if lower.contains("kotak") { return account(bank: "Kotak", suffix: suffix) }
        if lower.contains("hdfc") { return account(bank: "HDFC", suffix: suffix) }
        return label
    }
    static var indiaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }
    static func bankDate(_ input: String) -> Date? {
        let pieces = input.split(whereSeparator: { $0 == "/" || $0 == "-" }).compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        let year = pieces[2] < 100 ? 2000 + pieces[2] : pieces[2]
        let parts = DateComponents(year: year, month: pieces[1], day: pieces[0])
        guard let date = indiaCalendar.date(from: parts), indiaCalendar.dateComponents([.year, .month, .day], from: date) == parts else { return nil }
        return date
    }
}

public enum BankAlertParser {
    /// A supplied message timestamp is preferred; live capture time is an explicitly labeled fallback.
    /// Body text is user-supplied evidence, not an authenticated bank feed; records stay provisional.
    public static func parse(_ text: String, receivedAt: Date = Date(), messageTimestamp: Date? = nil, useCaptureTime: Bool = false) throws -> Transaction {
        guard text.utf8.count <= 16_384 else { throw DaybookError.invalid("Paste one bank message at a time.") }
        let flat = CaptureText.flat(text), lower = flat.lowercased()
        let requests = ["otp", "one time password", "collect request", "payment request", "requested", "will be debited", "will be deducted", "mandate"]
        guard !requests.contains(where: lower.contains) else {
            throw DaybookError.invalid("This is an authorization, request or future debit notice. It is not a completed payment.")
        }
        let bank: String
        if lower.contains("kotak") { bank = "Kotak" }
        else if lower.contains("hdfc") { bank = "HDFC" }
        else { throw DaybookError.invalid("This message does not identify a supported Kotak or HDFC account.") }
        let incoming = lower.hasPrefix("received ") || lower.contains(" is credited to ")
        guard incoming || lower.hasPrefix("sent ") || lower.contains(" debited ") || lower.hasPrefix("paid ") else {
            throw DaybookError.invalid("No supported debit or credit event was found. Balance alerts are not payments.")
        }
        guard let amountText = CaptureText.match(#"(?:INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)(?![\d.])"#, in: flat)?.first,
              let amount = Money.parse(amountText), amount > 0 else { throw DaybookError.invalid("The message has no unambiguous payment amount.") }
        let suffix = CaptureText.match(#"\b(?:a/c|ac|account)\s*(?:no\.?\s*)?[Xx*•]*(\d{4})\b"#, in: flat)?.first
        let reference = CaptureText.match(#"\b(?:UPI\s*(?:Ref(?:erence)?|Txn)|Ref(?:erence)?(?:\s*(?:No|Num))?|RRN)\s*[:.#-]?\s*([A-Za-z0-9]{6,40})\b"#, in: flat)?.first ?? ""
        let dateText = CaptureText.match(#"\bon\s+(\d{2}[-/]\d{2}[-/]\d{2,4})\b"#, in: flat)?.first
        let bankDate: Date?
        if let dateText {
            guard let parsed = CaptureText.bankDate(dateText) else { throw DaybookError.invalid("The bank date is invalid. Review this message manually.") }
            bankDate = parsed
        } else { bankDate = nil }
        let date: Date
        let timeSource: PaymentTimeSource
        let timingNote: String
        if let messageTimestamp {
            date = messageTimestamp; timeSource = .messageTimestamp
            timingNote = "Time is the supplied message timestamp, not a verified bank posting time."
        } else if useCaptureTime && (bankDate == nil || CaptureText.indiaCalendar.isDate(bankDate!, inSameDayAs: receivedAt)) {
            date = receivedAt; timeSource = .automationRun
            timingNote = "Time is when the automation ran, used as an estimate; the message timestamp was not supplied."
        } else if let bankDate {
            date = bankDate; timeSource = .bankDateOnly
            timingNote = "Bank-reported date only; payment time is unavailable."
        } else {
            date = receivedAt; timeSource = .automationRun
            timingNote = "Date and time are capture time; no bank date or message timestamp was supplied."
        }
        let direction = incoming ? "from" : "(?:to|towards|at)"
        let merchant = CaptureText.match("\\b" + direction + #"\s+(.+?)(?=\s+on\s+\d{2}[-/]|\s+(?:via|ref|upi|avl|bal|from)\b|$)"#, in: flat)?.first
        let dividend = incoming && lower.contains("towards nach-")
        let counterparty = dividend ? (CaptureText.match(#"\btowards\s+(.+?)(?:\s+Kotak Bank)?$"#, in: flat)?.first ?? "Bank credit") : (merchant ?? "Review counterparty")
        let sampleMatched = suffix != nil && dateText != nil && ((!reference.isEmpty && (lower.hasPrefix("sent ") || lower.hasPrefix("received "))) || dividend)
        var memo = timingNote
        if dividend { memo += " Bank credit, not a UPI payment. No stable UPI reference was provided." }
        if !sampleMatched { memo += " Unrecognized template: check every field." }
        var entry = Transaction(amountPaise: amount, date: date, merchant: counterparty,
            account: suffix.map { CaptureText.account(bank: bank, suffix: $0) } ?? "\(bank) · unknown account", reference: reference,
            memo: memo, kind: incoming ? .income : .expense,
            status: lower.contains("failed") || lower.contains("declined") ? .failed : .provisional,
            source: "\(bank) SMS · \(sampleMatched ? "sample-matched format" : "unrecognized format")",
            fingerprint: reference.isEmpty ? "" : Finance.fingerprint(flat))
        entry.timeSource = timeSource
        entry.bankReportedDate = bankDate
        return entry
    }
}
