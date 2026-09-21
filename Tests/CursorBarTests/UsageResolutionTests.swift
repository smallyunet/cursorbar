import Foundation
import XCTest
@testable import CursorBar

final class UsageResolutionTests: XCTestCase {
    func testFixtureResolvesIncludedAndOnDemandUsage() throws {
        let data = try Data(contentsOf: fixtureURL("usage-summary.json"))
        let summary = try JSONDecoder().decode(UsageSummary.self, from: data)

        XCTAssertEqual(summary.includedUsedCents, 30_000)
        XCTAssertEqual(summary.includedLimitCents, 60_000)
        XCTAssertEqual(summary.includedPercentUsed, 50)
        XCTAssertEqual(summary.cursorModelsPercentUsed, 25)
        XCTAssertEqual(summary.otherModelsPercentUsed, 100)
        XCTAssertEqual(summary.resolvedOnDemand?.usedCents, 125)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: summary.includedPercentUsed), 50)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: summary.cursorModelsPercentUsed), 75)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: summary.otherModelsPercentUsed), 0)
    }

    func testRemainingPercentClampsUsedValues() {
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 0), 100)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 31.6), 68.4)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 100), 0)
        XCTAssertEqual(UsageRemaining.percent(fromUsed: 120), 0)
        XCTAssertNil(UsageRemaining.percent(fromUsed: nil))
        XCTAssertEqual(UsageRemaining.progress(fromRemainingPercent: 81), 0.81, accuracy: 0.0001)
    }

    func testBillingResetProgressUsesExactCycleWindow() throws {
        let start = try XCTUnwrap(FlexibleISO8601.date(from: "2026-09-01T00:00:00Z"))
        let end = try XCTUnwrap(FlexibleISO8601.date(from: "2026-10-01T00:00:00.000Z"))
        let now = try XCTUnwrap(FlexibleISO8601.date(from: "2026-09-21T00:00:00Z"))

        XCTAssertEqual(
            UsageRemaining.cycleProgress(start: start, end: end, now: now),
            10.0 / 30.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            UsageRemaining.durationText(try XCTUnwrap(UsageRemaining.remainingInterval(until: end, now: now))),
            "10d 0h"
        )
        XCTAssertEqual(
            UsageRemaining.cycleProgress(start: start, end: end, now: end.addingTimeInterval(60)),
            0
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

    func testIndividualCreditFloorIsNotAppliedToEnterprise() {
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
        let individual = makeSummary(membership: "pro", plan: plan)
        let enterprise = makeSummary(membership: "enterprise", plan: plan)

        XCTAssertEqual(individual.includedLimitCents, 60_000)
        XCTAssertNil(enterprise.includedLimitCents)
        XCTAssertFalse(enterprise.appliesIndividualCreditFloors)
    }

    func testDisplayMessagePercentFallback() {
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

        XCTAssertEqual(summary.cursorModelsPercentUsed, 8.5)
        XCTAssertEqual(summary.otherModelsPercentUsed, 42)
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
