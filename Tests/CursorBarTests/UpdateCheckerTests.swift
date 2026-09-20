import Foundation
import XCTest
@testable import CursorBar

final class UpdateCheckerTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    @MainActor
    func testAcceptsReleasePageFromCanonicalRepository() async {
        MockURLProtocol.requestHandler = { request in
            let data = Data(
                """
                {
                  "tag_name": "v2.0.0",
                  "html_url": "https://github.com/smallyunet/cursorbar/releases/tag/v2.0.0"
                }
                """.utf8
            )
            return (Self.response(url: request.url!), data)
        }
        let checker = UpdateChecker(
            session: makeSession(),
            installedVersion: "1.0.0"
        )

        await checker.checkForUpdates(announceResult: true)

        XCTAssertEqual(checker.availableUpdate?.version, "2.0.0")
        XCTAssertNil(checker.statusMessage)
    }

    @MainActor
    func testRejectsReleasePageFromAnotherRepository() async {
        MockURLProtocol.requestHandler = { request in
            let data = Data(
                """
                {
                  "tag_name": "v2.0.0",
                  "html_url": "https://github.com/attacker/cursorbar/releases/tag/v2.0.0"
                }
                """.utf8
            )
            return (Self.response(url: request.url!), data)
        }
        let checker = UpdateChecker(
            session: makeSession(),
            installedVersion: "1.0.0"
        )

        await checker.checkForUpdates(announceResult: true)

        XCTAssertNil(checker.availableUpdate)
        XCTAssertNotNil(checker.statusMessage)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func response(url: URL) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
