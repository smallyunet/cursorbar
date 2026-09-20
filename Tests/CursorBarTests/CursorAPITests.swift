import Foundation
import XCTest
@testable import CursorBar

final class CursorAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testUsageSummaryUsesInjectedSecureRequest() async throws {
        let data = try Data(contentsOf: fixtureURL("usage-summary.json"))
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.host, "cursor.com")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Cookie"),
                "WorkosCursorSessionToken=test-cookie"
            )
            return (Self.response(status: 200, url: request.url!), data)
        }

        let summary = try await CursorAPI.fetchUsageSummary(
            credentials: SessionCredentials(cookieValue: "test-cookie"),
            session: makeSession()
        )

        XCTAssertEqual(summary.includedPercentUsed, 50)
    }

    func testDailySpendContinuesBeyondTenPages() async throws {
        let lock = NSLock()
        var requestedPages: [Int] = []
        MockURLProtocol.requestHandler = { request in
            let body = try XCTUnwrap(Self.requestBody(request))
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            let page = try XCTUnwrap((json["page"] as? NSNumber)?.intValue)
            lock.lock()
            requestedPages.append(page)
            lock.unlock()

            let payload = Data(
                """
                {
                  "totalUsageEventsCount": 1050,
                  "usageEventsDisplay": [{"chargedCents": 1}]
                }
                """.utf8
            )
            return (Self.response(status: 200, url: request.url!), payload)
        }

        let cents = try await CursorAPI.fetchTodaySpendCents(
            credentials: SessionCredentials(cookieValue: "test-cookie"),
            session: makeSession()
        )

        XCTAssertEqual(cents, 11)
        XCTAssertEqual(requestedPages, Array(1...11))
    }

    func testUnauthorizedInjectedCredentialsFailWithoutReadingLocalDatabase() async {
        MockURLProtocol.requestHandler = { request in
            (Self.response(status: 401, url: request.url!), Data())
        }

        do {
            _ = try await CursorAPI.fetchUsageSummary(
                credentials: SessionCredentials(cookieValue: "expired"),
                session: makeSession()
            )
            XCTFail("Expected authentication failure")
        } catch let error as CursorAPIError {
            guard case .notAuthenticated = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }

    private static func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: 1024)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data.isEmpty ? nil : data
    }

    private static func response(status: Int, url: URL) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler:
        ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.requestHandler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
