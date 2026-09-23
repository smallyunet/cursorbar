import AppKit
import Foundation
import XCTest
@testable import CursorBar

final class CoreBehaviorTests: XCTestCase {
    func testISO8601AcceptsFractionalAndWholeSeconds() {
        XCTAssertNotNil(FlexibleISO8601.date(from: "2026-09-01T00:00:00.123Z"))
        XCTAssertNotNil(FlexibleISO8601.date(from: "2026-09-01T00:00:00Z"))
        XCTAssertNil(FlexibleISO8601.date(from: "not-a-date"))
    }

    func testJWTSubjectUsesIdentitySuffix() throws {
        let payload = Data(#"{"sub":"auth0|user_123"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        let jwt = "header.\(payload).signature"

        XCTAssertEqual(try TokenProvider.extractUserID(from: jwt), "user_123")
    }

    func testJWTWithoutSubjectIsRejected() {
        XCTAssertThrowsError(try TokenProvider.extractUserID(from: "invalid"))
    }

    func testMenuBarUsesOriginalQuotaIcon() {
        XCTAssertEqual(MenuBarQuotaIcon.size, 16)
        XCTAssertTrue(MenuBarQuotaIcon.usesWhiteTrack(isDark: true))
        XCTAssertFalse(MenuBarQuotaIcon.usesWhiteTrack(isDark: false))
        XCTAssertTrue(MenuBarQuotaIcon.usesWhiteFill())
        XCTAssertTrue(MenuBarChrome.prefersLightGaugeText(chromeIsDark: true, appIsDark: false))
        XCTAssertFalse(MenuBarChrome.prefersLightGaugeText(chromeIsDark: false, appIsDark: true))
        XCTAssertTrue(MenuBarChrome.looksLikeStatusBarWindow(className: "NSStatusBarWindow"))
        XCTAssertFalse(MenuBarChrome.looksLikeStatusBarWindow(className: "NSMenuBarWindow"))
        XCTAssertTrue(MenuBarChrome.isDark(appearanceName: "NSAppearanceNameDarkAqua"))
        XCTAssertFalse(MenuBarChrome.isDark(appearanceName: "NSAppearanceNameAqua"))
        XCTAssertEqual(MenuBarText.fontSize, 12)
        XCTAssertEqual(MenuChrome.rowFontSize, 13)
        XCTAssertEqual(MenuChrome.detailFontSize, 11)
        XCTAssertEqual(MenuChrome.progressHeight, 6)
        XCTAssertEqual(MenuChrome.progressFill, .secondaryLabelColor)
        XCTAssertEqual(MenuChrome.progressTrack, .separatorColor)
    }

    func testCloudAgentParserCountsOnlyLiveAgents() {
        let data = Data(
            """
            [
              {"status": 1, "isKilled": false, "isArchived": false},
              {"status": 4},
              {"status": 1, "isKilled": true},
              {"status": 2},
              {"status": 1, "isArchived": true}
            ]
            """.utf8
        )
        XCTAssertEqual(AgentMonitor.countRunningCloudAgents(data: data), 2)
    }

    @MainActor
    func testStrictSemanticVersionComparison() {
        XCTAssertTrue(UpdateChecker.isVersion("1.8.0", newerThan: "1.7.9"))
        XCTAssertFalse(UpdateChecker.isVersion("1.7.0", newerThan: "1.7.0"))
        XCTAssertFalse(UpdateChecker.isVersion("1.7", newerThan: "1.6.0"))
        XCTAssertFalse(UpdateChecker.isVersion("1.7.0v", newerThan: "1.6.0"))
        XCTAssertFalse(UpdateChecker.isVersion("-1.7.0", newerThan: "1.6.0"))
        XCTAssertFalse(UpdateChecker.isVersion("release", newerThan: "1.6.0"))
    }
}
