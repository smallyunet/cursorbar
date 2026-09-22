import Foundation
import XCTest
@testable import CursorBar

final class UsageResolutionTests: XCTestCase {
    func testFixtureResolvesIncludedAndOnDemandUsage() throws {
        let data = try Data(contentsOf: fixtureURL("usage-summary.json"))
        let summary = try JSONDecoder().decode(UsageSummary.self, from: data)

        XCTAssertEqual(summary.includedUsedCents, 30_000)
        XCTAssertNil(summary.includedLimitCents)
        XCTAssertNil(summary.includedRemainingCents)
        XCTAssertEqual(summary.includedPercentUsed, 50)
        XCTAssertEqual(summary.cursorModelsPercentUsed, 25)
        XCTAssertEqual(summary.otherModelsPercentUsed, 100)
        XCTAssertEqual(summary.resolvedOnDemand?.used, 125)
        XCTAssertEqual(summary.otherModelsLimitCents, 40_000)
        XCTAssertEqual(summary.otherModelsUsedCents, 40_000)
        XCTAssertEqual(summary.otherModelsRemainingCents, 0)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: summary.includedPercentUsed), 50)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: summary.cursorModelsPercentUsed), 75)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: summary.otherModelsPercentUsed), 0)
    }

    func testRemainingPercentClampsUsedValues() throws {
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 0), 100)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 31.6), 68.4)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 100), 0)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 120), 0)
        XCTAssertNil(UsageRemaining.percent(fromUsed: nil))
        XCTAssertEqual(
            try XCTUnwrap(UsageRemaining.progress(fromRemainingPercent: 81)),
            0.81,
            accuracy: 0.0001
        )
    }

    func testBillingResetProgressUsesExactCycleWindow() throws {
        let start = try XCTUnwrap(FlexibleISO8601.date(from: "2026-09-01T00:00:00Z"))
        let end = try XCTUnwrap(FlexibleISO8601.date(from: "2026-10-01T00:00:00.000Z"))
        let now = try XCTUnwrap(FlexibleISO8601.date(from: "2026-09-21T00:00:00Z"))

        XCTAssertEqual(
            try XCTUnwrap(UsageRemaining.cycleProgress(start: start, end: end, now: now)),
            10.0 / 30.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            UsageRemaining.durationText(try XCTUnwrap(UsageRemaining.remainingInterval(until: end, now: now))),
            "10d 0h"
        )
        XCTAssertEqual(
            try XCTUnwrap(UsageRemaining.cycleProgress(start: start, end: end, now: end.addingTimeInterval(60))),
            0,
            accuracy: 0.0001
        )
        XCTAssertNil(UsageRemaining.cycleProgress(start: nil, end: end, now: now))
        XCTAssertNil(UsageRemaining.cycleProgress(start: start, end: start, now: now))
    }

    @MainActor
    func testMenuBarLabelUsesRemainingPercent() {
        let summary = makeSummary(
            membership: "pro",
            plan: PlanUsage(
                enabled: true,
                used: 15_000,
                limit: 60_000,
                remaining: 45_000,
                breakdown: UsageBreakdown(included: 15_000, bonus: 0, total: 15_000),
                autoPercentUsed: nil,
                apiPercentUsed: nil,
                totalPercentUsed: 25
            )
        )

        XCTAssertEqual(
            UsageStore.menuBarLabel(summary: summary, isLoading: false, errorMessage: nil),
            "75%"
        )
    }

    func testMissingOverallValuesAreNeverInferred() {
        let plan = PlanUsage(
            enabled: true,
            used: nil,
            limit: nil,
            remaining: nil,
            breakdown: UsageBreakdown(included: nil, bonus: nil, total: 0),
            autoPercentUsed: nil,
            apiPercentUsed: nil,
            totalPercentUsed: 0
        )
        let summary = makeSummary(membership: "pro", plan: plan)

        XCTAssertNil(summary.includedLimitCents)
        XCTAssertNil(summary.includedRemainingCents)
        XCTAssertNil(summary.otherModelsUsedCents)
        XCTAssertNil(summary.otherModelsRemainingCents)
    }

    func testOverallMonetaryValuesAreUsedExactlyAsReported() {
        let summary = UsageSummary(
            billingCycleStart: nil,
            billingCycleEnd: nil,
            membershipType: "enterprise",
            limitType: "team",
            isUnlimited: false,
            autoModelSelectedDisplayMessage: nil,
            namedModelSelectedDisplayMessage: nil,
            individualUsage: IndividualUsage(
                plan: nil,
                onDemand: nil,
                overall: OverallUsage(enabled: true, used: 12_345, limit: 50_000, remaining: 37_655)
            ),
            teamUsage: nil
        )

        XCTAssertEqual(summary.includedUsedCents, 12_345)
        XCTAssertEqual(summary.includedLimitCents, 50_000)
        XCTAssertEqual(summary.includedRemainingCents, 37_655)
    }

    func testDisplayMessagePercentIsNotParsedAsStructuredUsage() {
        let summary = UsageSummary(
            billingCycleStart: nil,
            billingCycleEnd: nil,
            membershipType: "pro",
            limitType: nil,
            isUnlimited: false,
            autoModelSelectedDisplayMessage: "You've used 8.5% of Cursor Models",
            namedModelSelectedDisplayMessage: "Used 42% of Other Models",
            individualUsage: nil,
            teamUsage: nil
        )

        XCTAssertNil(summary.cursorModelsPercentUsed)
        XCTAssertNil(summary.otherModelsPercentUsed)
    }

    @MainActor
    func testMenuBarDoesNotSubstituteCategoryPercentForBlendedPercent() {
        let summary = makeSummary(
            membership: "pro",
            plan: PlanUsage(
                enabled: true,
                used: 10_000,
                limit: 40_000,
                remaining: 30_000,
                breakdown: nil,
                autoPercentUsed: 25,
                apiPercentUsed: 10,
                totalPercentUsed: nil
            )
        )

        XCTAssertEqual(
            UsageStore.menuBarLabel(summary: summary, isLoading: false, errorMessage: nil),
            "!"
        )
    }

    @MainActor
    func testUnlimitedPlanUsesInfinityInsteadOfErrorMarker() {
        let summary = UsageSummary(
            billingCycleStart: nil,
            billingCycleEnd: nil,
            membershipType: "ultra",
            limitType: nil,
            isUnlimited: true,
            autoModelSelectedDisplayMessage: nil,
            namedModelSelectedDisplayMessage: nil,
            individualUsage: nil,
            teamUsage: nil
        )

        XCTAssertEqual(
            UsageStore.menuBarLabel(
                summary: summary,
                isLoading: false,
                errorMessage: nil
            ),
            "∞"
        )
    }

    private func makeSummary(
        membership: String,
        plan: PlanUsage
    ) -> UsageSummary {
        UsageSummary(
            billingCycleStart: nil,
            billingCycleEnd: nil,
            membershipType: membership,
            limitType: nil,
            isUnlimited: false,
            autoModelSelectedDisplayMessage: nil,
            namedModelSelectedDisplayMessage: nil,
            individualUsage: IndividualUsage(plan: plan, onDemand: nil, overall: nil),
            teamUsage: nil
        )
    }

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }
}
