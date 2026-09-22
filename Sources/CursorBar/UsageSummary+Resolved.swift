import Foundation

extension UsageSummary {
    var isUnlimitedPlan: Bool { isUnlimited ?? false }

    var hasDisplayableUsage: Bool {
        isUnlimitedPlan
            || includedPercentUsed != nil
            || cursorModelsPercentUsed != nil
            || otherModelsPercentUsed != nil
            || includedUsedCents != nil
    }

    var resolvedMembershipType: String {
        let raw = membershipType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "unknown" : raw
    }

    var plan: PlanUsage? { individualUsage?.plan }
    var overall: OverallUsage? { individualUsage?.overall }

    var resolvedOnDemand: OnDemandUsage? {
        individualUsage?.onDemand ?? teamUsage?.onDemand
    }

    /// Cursor Models pool (Auto, Composer, Cursor Grok). `autoPercentUsed` on the wire.
    var cursorModelsPercentUsed: Double? {
        if isUnlimitedPlan { return nil }
        return plan?.autoPercentUsed
    }

    /// Other Models pool (named / third-party). `apiPercentUsed` on the wire.
    var otherModelsPercentUsed: Double? {
        if isUnlimitedPlan { return nil }
        return plan?.apiPercentUsed
    }

    /// Blended included-usage percentage. Only from `totalPercentUsed` — the
    /// display-message strings feed the Cursor Models / Other Models bars instead.
    var includedPercentUsed: Double? {
        if isUnlimitedPlan { return nil }
        return plan?.totalPercentUsed
    }

    /// Amount used against the included pool. Prefer `breakdown.total` over `plan.used`:
    /// on some Enterprise payloads `plan.used` is the Other Models cap, not included spend.
    var includedUsedCents: Int? {
        if let total = plan?.breakdown?.total { return total }
        if let overallUsed = overall?.used { return overallUsed }
        return nil
    }

    var includedLimitCents: Int? {
        guard let limit = overall?.limit, limit > 0 else { return nil }
        return limit
    }

    /// Included credits remaining exactly as reported by `overall.remaining`.
    var includedRemainingCents: Int? {
        overall?.remaining
    }

    /// Other Models dollar cap from `plan.limit`. Nil when the plan is disabled or has no limit.
    /// Cursor Models has no corresponding limit field — never invent one from included − Other Models.
    var otherModelsLimitCents: Int? {
        guard plan?.enabled != false else { return nil }
        guard let limit = plan?.limit, limit > 0 else { return nil }
        return limit
    }

    var otherModelsUsedCents: Int? {
        guard plan?.enabled != false else { return nil }
        return plan?.used
    }

    var otherModelsRemainingCents: Int? {
        guard plan?.enabled != false else { return nil }
        return plan?.remaining
    }
}
