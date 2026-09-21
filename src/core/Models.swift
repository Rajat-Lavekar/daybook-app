import Foundation

public enum Category: String, Codable, CaseIterable, Identifiable, Sendable {
    case groceries = "Groceries", dining = "Eating out", transport = "Transport"
    case shopping = "Shopping", bills = "Bills", rent = "Rent", subscriptions = "Subscriptions"
    case health = "Health", learning = "Learning", travel = "Travel", gifts = "Gifts", recreation = "Recreation", uncategorized = "Uncategorized"
    public var id: String { rawValue }
    public var symbol: String {
        switch self {
        case .groceries: "basket"; case .dining: "fork.knife"; case .transport: "tram"
        case .shopping: "bag"; case .bills: "bolt"; case .rent: "house"
        case .subscriptions: "repeat"; case .health: "heart"; case .learning: "book"
        case .travel: "airplane"; case .gifts: "gift"; case .recreation: "theatermasks"; case .uncategorized: "questionmark"
        }
    }
}
public enum EntryKind: String, Codable, CaseIterable, Sendable { case expense, income, refund, transfer, investment }
public enum EntryStatus: String, Codable, CaseIterable, Sendable { case provisional, confirmed, pending, failed }
public enum EntryDirection: String, Codable, Sendable { case debit, credit }

public enum PaymentTimeSource: String, Codable, Sendable {
    case bankDateOnly, messageTimestamp, automationRun
}

public struct Transaction: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var amountPaise: Int64
    public var date: Date
    public var merchant: String
    public var account: String
    public var reference: String
    public var originalNote: String
    public var memo: String
    public var category: Category
    public var kind: EntryKind
    public var status: EntryStatus
    public var source: String
    public var fingerprint: String
    public var updatedAt: Date
    /// Optional so older snapshots and archives decode without migration.
    public var timeSource: PaymentTimeSource?
    public var bankReportedDate: Date?
    /// Source direction survives a later user change to economic kind (e.g. transfer).
    /// Optional for compatibility with existing schema-1 snapshots.
    public var direction: EntryDirection?
    public var effectiveDirection: EntryDirection? {
        if let direction { return direction }
        switch kind {
        case .income, .refund: return .credit
        case .expense, .investment: return .debit
        case .transfer: return nil
        }
    }
    public init(id: UUID = UUID(), amountPaise: Int64, date: Date = Date(), merchant: String,
                account: String = "Manual", reference: String = "", originalNote: String = "", memo: String = "",
                category: Category = .uncategorized, kind: EntryKind = .expense,
                status: EntryStatus = .confirmed, source: String = "Manual", fingerprint: String = "", updatedAt: Date = Date()) {
        self.id = id; self.amountPaise = amountPaise; self.date = date; self.merchant = merchant
        self.account = account; self.reference = reference; self.originalNote = originalNote; self.memo = memo
        self.category = category; self.kind = kind; self.status = status; self.source = source
        self.fingerprint = fingerprint; self.updatedAt = updatedAt
        switch kind {
        case .income, .refund: self.direction = .credit
        case .expense, .investment: self.direction = .debit
        case .transfer: self.direction = nil
        }
    }
}

public struct CheckIn: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date: Date
    public var mood: Int
    public var energy: Int
    public var stress: Int
    public var helped: String
    public var difficult: String
    public var tomorrow: String
    public var allowExcerpt: Bool
    public init(date: Date = Date(), mood: Int = 3, energy: Int = 3, stress: Int = 3,
                helped: String = "", difficult: String = "", tomorrow: String = "", allowExcerpt: Bool = false) {
        self.date = date; self.mood = mood; self.energy = energy; self.stress = stress
        self.helped = helped; self.difficult = difficult; self.tomorrow = tomorrow; self.allowExcerpt = allowExcerpt
    }
}

public struct HealthDay: Codable, Identifiable, Sendable {
    public var id: String { ISO8601DateFormatter().string(from: date) }
    public var date: Date
    public var steps: Double?
    public var sleepHours: Double?
    public var activeKcal: Double?
    public var workoutMinutes: Double?
    public init(date: Date, steps: Double? = nil, sleepHours: Double? = nil, activeKcal: Double? = nil, workoutMinutes: Double? = nil) {
        self.date = date; self.steps = steps; self.sleepHours = sleepHours; self.activeKcal = activeKcal; self.workoutMinutes = workoutMinutes
    }
}

public struct Review: Codable, Identifiable, Sendable {
    public var id = UUID()
    public var date = Date()
    public var title: String
    public var body: String
    public var packetID: UUID?
    public init(title: String, body: String, packetID: UUID? = nil) { self.title = title; self.body = body; self.packetID = packetID }
}

public struct Snapshot: Codable, Sendable {
    public var schemaVersion = 1
    public var isDemo = false
    public var transactions: [Transaction] = []
    public var checkIns: [CheckIn] = []
    public var health: [HealthDay] = []
    public var healthUpdatedAt: Date?
    public var completedLessons: Set<String> = []
    public var bookmarkedLessons: Set<String> = []
    public var reviews: [Review] = []
    public var merchantRules: [String: Category] = [:]
    public var lastImportAt: Date?
    public var coverageNote = "Manual entries only. No bank history has been reconciled."
    public init() {}
}

public enum DaybookError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

public enum Money {
    public static func parse(_ input: String) -> Int64? {
        let clean = input.replacingOccurrences(of: "₹", with: "").replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: #"^\d{1,11}(\.\d{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        let parts = clean.split(separator: ".", omittingEmptySubsequences: false)
        guard let rupees = Int64(parts[0]) else { return nil }
        let cents = parts.count > 1 ? String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0) : "00"
        guard let paise = Int64(cents) else { return nil }
        return rupees * 100 + paise
    }
    public static func format(_ paise: Int64) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .currency
        formatter.currencyCode = "INR"; formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = paise % 100 == 0 ? 0 : 2
        return formatter.string(from: NSNumber(value: Double(paise) / 100)) ?? "₹0"
    }
}

public enum DaybookJSON {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
