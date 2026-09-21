import Foundation

enum UsageRemaining {
    static func percent(fromUsed used: Double?) -> Double? {
        guard let used, used.isFinite else { return nil }
        return min(100, max(0, 100 - used))
    }

    static func progress(fromRemainingPercent remaining: Double?) -> Double? {
        guard let remaining, remaining.isFinite else { return nil }
        return clamp(remaining / 100)
    }

    static func cycleProgress(start: Date?, end: Date?, now: Date) -> Double? {
        guard let start, let end else { return nil }
        let duration = end.timeIntervalSince(start)
        guard duration.isFinite, duration > 0 else { return nil }
        let remaining = max(0, end.timeIntervalSince(now))
        return clamp(remaining / duration)
    }

    static func remainingInterval(until end: Date?, now: Date) -> TimeInterval? {
        guard let end else { return nil }
        return max(0, end.timeIntervalSince(now))
    }

    static func durationText(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }
}
