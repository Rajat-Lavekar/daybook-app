import Foundation
import CryptoKit

public struct SpendingSummary: Codable, Sendable {
    public var grossPaise: Int64 = 0
    public var refundPaise: Int64 = 0
    public var incomePaise: Int64 = 0
    public var provisionalPaise: Int64 = 0
    public var confirmedCount = 0
    public var categories: [String: Int64] = [:]
    public var netPaise: Int64 { grossPaise - refundPaise }
}

public enum Finance {
    public static func summary(_ entries: [Transaction], from: Date = .distantPast, to: Date = .distantFuture) -> SpendingSummary {
        var result = SpendingSummary()
        for entry in entries where entry.date >= from && entry.date < to {
            if entry.status == .provisional && entry.kind == .expense { result.provisionalPaise += entry.amountPaise }
            guard entry.status == .confirmed else { continue }
            result.confirmedCount += 1
            switch entry.kind {
            case .expense:
                result.grossPaise += entry.amountPaise
                result.categories[entry.category.rawValue, default: 0] += entry.amountPaise
            case .refund: result.refundPaise += entry.amountPaise
            case .income: result.incomePaise += entry.amountPaise
            case .transfer, .investment: break
            }
        }
        return result
    }
    public static func category(for merchant: String, rules: [String: Category] = [:]) -> Category {
        let text = merchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = rules[text] { return exact }
        let mappings: [(Category, [String])] = [
            (.dining, ["swiggy", "zomato", "cafe", "coffee"]), (.groceries, ["bigbasket", "groceries"]),
            (.transport, ["uber", "rapido", "metro"]), (.subscriptions, ["netflix", "spotify"]),
            (.learning, ["coursera", "oreilly", "o'reilly"])
        ]
        return mappings.first(where: { $0.1.contains(where: text.contains) })?.0 ?? .uncategorized
    }
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func fingerprint(_ text: String) -> String { digest(Data(text.trimmingCharacters(in: .whitespacesAndNewlines).utf8)) }

    /// Only merge exact observations or a complete stable reference match. Never merge by amount/time alone.
    @discardableResult public static func ingest(_ entries: [Transaction], into snapshot: inout Snapshot) -> Int {
        var added = 0
        for var entry in entries {
            entry.account = CaptureText.canonicalAccount(entry.account)
            let duplicate = snapshot.transactions.firstIndex { existing in
                if !entry.fingerprint.isEmpty && existing.fingerprint == entry.fingerprint { return true }
                return !entry.reference.isEmpty && !entry.account.isEmpty && existing.reference == entry.reference
                    && CaptureText.canonicalAccount(existing.account) == entry.account && existing.amountPaise == entry.amountPaise
                    && existing.effectiveDirection == entry.effectiveDirection
            }
            if let index = duplicate {
                // User's category/memo stay authoritative; retain a newly provided original note.
                if snapshot.transactions[index].originalNote.isEmpty { snapshot.transactions[index].originalNote = entry.originalNote }
                if snapshot.transactions[index].status == .provisional && entry.status == .confirmed {
                    snapshot.transactions[index].status = .confirmed
                    snapshot.transactions[index].source += " + " + entry.source
                    snapshot.transactions[index].updatedAt = Date()
                }
                continue
            }
            if entry.category == .uncategorized { entry.category = category(for: entry.merchant, rules: snapshot.merchantRules) }
            snapshot.transactions.append(entry); added += 1
        }
        snapshot.transactions.sort { $0.date > $1.date }
        snapshot.lastImportAt = Date()
        return added
    }
}

public struct ImportResult: Sendable {
    public var entries: [Transaction] = []
    public var issues: [String] = []
    public var statement: StatementSummary?
    public var canImport: Bool { !entries.isEmpty && (statement == nil || (issues.isEmpty && statement?.totalsMatch == true)) }
    public init() {}
}


public enum CSVImporter {
    public static let template = "date,amount,merchant,account,reference,note,kind,status,category\n2026-09-12,250.00,Example Cafe,Kotak · 1234,EXAMPLE001,Lunch,expense,confirmed,Eating out\n"
    public static func rows(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []; var row: [String] = []; var field = ""; var quoted = false
        let characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n")); var index = 0
        while index < characters.count {
            let c = characters[index]
            if c == "\"" {
                if quoted && index + 1 < characters.count && characters[index + 1] == "\"" { field.append("\""); index += 1 }
                else { quoted.toggle() }
            } else if c == "," && !quoted { row.append(field); field = "" }
            else if c == "\n" && !quoted { row.append(field); rows.append(row); row = []; field = "" }
            else { field.append(c) }
            index += 1
        }
        guard !quoted else { throw DaybookError.invalid("The CSV contains an unclosed quoted field.") }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows.filter { !$0.allSatisfy { $0.isEmpty } }
    }
    public static func parse(_ text: String) throws -> ImportResult {
        let rows = try rows(text); var output = ImportResult()
        guard let header = rows.first else { throw DaybookError.invalid("The file is empty.") }
        let names = header.map { $0.replacingOccurrences(of: "\u{FEFF}", with: "").lowercased().trimmingCharacters(in: .whitespaces) }
        guard Set(names).count == names.count else { throw DaybookError.invalid("Duplicate CSV column names are not supported.") }
        guard ["date", "amount", "merchant", "account"].allSatisfy(names.contains) else {
            throw DaybookError.invalid("Use the Daybook CSV template: date, amount, merchant, account, reference, note, kind, status, category. Bank-specific PDF adapters need your samples first.")
        }
        let dateFormat = DateFormatter(); dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.timeZone = TimeZone(identifier: "Asia/Kolkata"); dateFormat.dateFormat = "yyyy-MM-dd"; dateFormat.isLenient = false
        let fileIdentity = Finance.fingerprint(text)
        for (offset, row) in rows.dropFirst().enumerated() {
            guard row.count == names.count else { output.issues.append("Row \(offset + 2): column count mismatch."); continue }
            let fields = Dictionary(uniqueKeysWithValues: zip(names, row))
            guard let amount = Money.parse(fields["amount"] ?? ""), amount > 0,
                  let date = dateFormat.date(from: fields["date"] ?? ""), dateFormat.string(from: date) == fields["date"],
                  let merchant = fields["merchant"], !merchant.trimmingCharacters(in: .whitespaces).isEmpty,
                  let account = fields["account"], !account.trimmingCharacters(in: .whitespaces).isEmpty,
                  let kind = EntryKind(rawValue: fields["kind"].flatMap { $0.isEmpty ? nil : $0 } ?? "expense"),
                  let status = EntryStatus(rawValue: fields["status"].flatMap { $0.isEmpty ? nil : $0 } ?? "provisional") else {
                output.issues.append("Row \(offset + 2): invalid amount, date, account, kind, status or merchant."); continue
            }
            let identity = "\(fileIdentity):\(offset)"
            output.entries.append(Transaction(amountPaise: amount, date: date, merchant: merchant, account: account,
                reference: fields["reference"] ?? "", originalNote: fields["note"] ?? "",
                category: Category(rawValue: fields["category"] ?? "") ?? .uncategorized,
                kind: kind, status: status, source: "CSV import", fingerprint: Finance.fingerprint(identity)))
        }
        return output
    }
}
