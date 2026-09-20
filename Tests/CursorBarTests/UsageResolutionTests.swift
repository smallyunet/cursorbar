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
