import Foundation
import Darwin

/// One atomic snapshot with a separate advisory lock for app and App Intent access.
/// No iCloud synchronization. A corrupt store fails closed instead of being silently overwritten.
public final class SnapshotStore: @unchecked Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        var directory = url.deletingLastPathComponent()
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
    }
    public func read() throws -> Snapshot {
        try withLock { try self.readUncoordinated(self.url) }
    }
    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try prepareDirectory()
        let descriptor = Darwin.open(url.appendingPathExtension("lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }
    private func readUncoordinated(_ target: URL) throws -> Snapshot {
        guard FileManager.default.fileExists(atPath: target.path) else { return Snapshot() }
        let value = try DaybookJSON.decode(Snapshot.self, from: Data(contentsOf: target))
        try Vault.validate(value); return value
    }
    @discardableResult public func update(_ operation: (inout Snapshot) throws -> Void) throws -> Snapshot {
        try withLock {
                var snapshot = try self.readUncoordinated(self.url)
                try operation(&snapshot); try Vault.validate(snapshot)
                let data = try DaybookJSON.encode(snapshot)
                #if os(iOS)
                try data.write(to: self.url, options: [.atomic, .completeFileProtection])
                #else
                try data.write(to: self.url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.url.path)
                #endif
                return snapshot
        }
    }
}

public enum Demo {
    public static func snapshot(now: Date = Date()) -> Snapshot {
        var value = Snapshot(); value.isDemo = true
        value.coverageNote = "SAMPLE DATA · fictional payments for exploring the app. Not connected to any bank."
        let rows: [(String, Int64, Category, Int)] = [
            ("The neighbourhood café", 28000, .dining, 0), ("Weekly groceries", 164500, .groceries, 1),
            ("Metro commute", 6000, .transport, 1), ("Lunch with friends", 74000, .dining, 2),
            ("A book for the weekend", 59900, .learning, 3), ("Electricity", 183200, .bills, 4),
            ("Coffee & a quiet hour", 22000, .dining, 5), ("Market vegetables", 43000, .groceries, 6)
        ]
        value.transactions = rows.map { row in
            Transaction(amountPaise: row.1, date: Calendar.current.date(byAdding: .day, value: -row.3, to: now)!,
                        merchant: row.0, account: "Sample account", originalNote: "Fictional sample", category: row.2, source: "Demo")
        }
        return value
    }
}
