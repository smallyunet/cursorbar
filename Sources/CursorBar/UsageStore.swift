import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var summary: UsageSummary?
    @Published private(set) var periodTokenCount: Int?
    @Published private(set) var lifetimeTokenCount: Int?
    @Published private(set) var profileHandle: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var refreshTimer: Timer?

    init() {
        startAutoRefresh()
        Task { await refresh() }
    }

    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            summary = try await CursorAPI.fetchUsageSummary()
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        if let profileTokens = try? await CursorAPI.fetchPublicProfileTokens(
            periodStart: billingCycleStartDate
        ) {
            profileHandle = profileTokens.handle
            periodTokenCount = profileTokens.periodTokens
            lifetimeTokenCount = profileTokens.totalTokens
        } else {
            profileHandle = nil
            periodTokenCount = nil
            lifetimeTokenCount = nil
        }
    }

    var hasTokenTotals: Bool {
        periodTokenCount != nil || lifetimeTokenCount != nil
    }

    /// Plain-text fallback for the menu bar while data is unavailable.
    var menuBarLabel: String {
        Self.menuBarLabel(summary: summary, isLoading: isLoading, errorMessage: errorMessage)
    }

    static func menuBarLabel(
        summary: UsageSummary?,
        isLoading: Bool,
        errorMessage: String?
    ) -> String {
        if errorMessage != nil, summary == nil {
            return "!"
        }
        if summary?.isUnlimitedPlan == true {
            return "∞"
        }
        let used = summary?.includedPercentUsed
        guard let remaining = UsageRemaining.percent(fromUsed: used) else {
            return isLoading ? "…" : "!"
        }
        return "\(Int(remaining.rounded()))%"
    }

    var planDisplayName: String {
        summary?.resolvedMembershipType.capitalized ?? "Unknown"
    }

    var isUnlimitedPlan: Bool {
        summary?.isUnlimitedPlan ?? false
    }

    /// Total included credits consumed so far. `breakdown.total` is used amount, not pool size.
    var includedUsedCreditsCents: Int? {
        summary?.includedUsedCents
    }

    /// Included pool size exactly as reported by `overall.limit`.
    var includedLimitCreditsCents: Int? {
        summary?.includedLimitCents
    }

    var includedPercentUsed: Double? {
        summary?.includedPercentUsed
    }

    /// Menu-bar quota uses only the API's blended included percentage.
    var quotaPercentUsed: Double? {
        includedPercentUsed
    }

    var quotaPercentRemaining: Double? {
        UsageRemaining.percent(fromUsed: quotaPercentUsed)
    }

    var includedPercentRemaining: Double? {
        UsageRemaining.percent(fromUsed: includedPercentUsed)
    }

    var includedRemainingProgress: Double? {
        UsageRemaining.progress(fromRemainingPercent: includedPercentRemaining)
    }

    /// Cursor Models pool (Auto, Composer, Cursor Grok). Percent only — the API has no dollar cap for this pool.
    var cursorModelsPercentUsed: Double? {
        summary?.cursorModelsPercentUsed
    }

    var cursorModelsPercentRemaining: Double? {
        UsageRemaining.percent(fromUsed: cursorModelsPercentUsed)
    }

    /// Other Models pool (named / third-party).
    var otherModelsPercentUsed: Double? {
        summary?.otherModelsPercentUsed
    }

    var otherModelsPercentRemaining: Double? {
        UsageRemaining.percent(fromUsed: otherModelsPercentUsed)
    }

    var otherModelsLimitCreditsCents: Int? {
        summary?.otherModelsLimitCents
    }

    var otherModelsUsedCreditsCents: Int? {
        summary?.otherModelsUsedCents
    }

    var otherModelsRemainingCreditsCents: Int? {
        summary?.otherModelsRemainingCents
    }

    var includedRemainingCreditsCents: Int? {
        summary?.includedRemainingCents
    }

    var onDemandEnabled: Bool {
        summary?.resolvedOnDemand?.isEnabled ?? false
    }

    var onDemandUsedCents: Int? {
        summary?.resolvedOnDemand?.used
    }

    var onDemandLimitCents: Int? {
        summary?.resolvedOnDemand?.limit
    }

    var onDemandRemainingCents: Int? {
        summary?.resolvedOnDemand?.remaining
    }

    /// Usage beyond the included credit pool.
    var includedOverageCents: Int? {
        guard let used = includedUsedCreditsCents, let limit = includedLimitCreditsCents else { return nil }
        return max(used - limit, 0)
    }

    /// Exact total only when both included and on-demand components are known.
    var overspendCents: Int? {
        guard let includedOverageCents, let onDemandUsedCents else { return nil }
        return includedOverageCents + onDemandUsedCents
    }

    var hasOverspend: Bool {
        (includedOverageCents ?? 0) > 0 || (onDemandUsedCents ?? 0) > 0
    }

    var billingCycleEndDate: Date? {
        guard let end = summary?.billingCycleEnd else { return nil }
        return FlexibleISO8601.date(from: end)
    }

    var billingCycleStartDate: Date? {
        guard let start = summary?.billingCycleStart else { return nil }
        return FlexibleISO8601.date(from: start)
    }

    func billingResetValue(now: Date = Date()) -> String {
        guard let remaining = UsageRemaining.remainingInterval(until: billingCycleEndDate, now: now) else {
            return "Unavailable"
        }
        return UsageRemaining.durationText(remaining)
    }

    func billingResetProgress(now: Date = Date()) -> Double? {
        UsageRemaining.cycleProgress(
            start: billingCycleStartDate,
            end: billingCycleEndDate,
            now: now
        )
    }

    var billingResetDetail: String? {
        guard let end = billingCycleEndDate else { return nil }
        return "Resets: \(Self.shortDateFormatter.string(from: end))"
    }

    var lastUpdatedText: String {
        guard let lastUpdated else { return "Never" }
        return Self.timeFormatter.string(from: lastUpdated)
    }

    static func formatDollars(cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return currencyFormatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
    }

    static func formatTokens(_ count: Int) -> String {
        let sign = count < 0 ? "-" : ""
        let value = abs(count)
        if value >= 1_000_000_000 {
            let billions = Double(value) / 1_000_000_000.0
            return sign + String(format: billions >= 10 ? "%.1fB" : "%.2fB", billions)
        }
        if value >= 1_000_000 {
            return sign + String(format: "%.1fM", Double(value) / 1_000_000.0)
        }
        if value >= 1_000 {
            return sign + String(format: "%.1fK", Double(value) / 1_000.0)
        }
        return sign + "\(value)"
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
}
