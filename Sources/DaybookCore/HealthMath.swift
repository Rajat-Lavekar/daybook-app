import Foundation

public struct TimeSpan: Sendable {
    public var start: Date; public var end: Date
    public init(start: Date, end: Date) { self.start = start; self.end = end }
}
public enum HealthMath {
    public static func merged(_ spans: [TimeSpan]) -> [TimeSpan] {
        let valid = spans.filter { $0.end > $0.start }.sorted { $0.start < $1.start }
        var result: [TimeSpan] = []
        for span in valid {
            if let last = result.last, span.start <= last.end {
                result[result.count - 1].end = max(span.end, last.end)
            } else { result.append(span) }
        }
        return result
    }
    public static func duration(_ spans: [TimeSpan]) -> TimeInterval {
        merged(spans).reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }
    /// Groups adjacent sleep stages into sessions, then assigns a session to its wake date.
    public static func sleepByWakeDate(_ spans: [TimeSpan], calendar: Calendar = .current) -> [Date: Double] {
        var result: [Date: Double] = [:]; var session: [TimeSpan] = []
        func flush() {
            guard let last = session.last else { return }
            result[calendar.startOfDay(for: last.end), default: 0] += duration(session) / 3600
        }
        for span in merged(spans) {
            if let last = session.last, span.start.timeIntervalSince(last.end) > 3 * 3600 { flush(); session = [] }
            session.append(span)
        }
        flush(); return result
    }
}
