import Foundation

enum CursorAPIError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Not authenticated. Please log in to Cursor."
        case .invalidResponse:
            "Could not parse usage data from Cursor."
        case .httpError(let statusCode):
            "Cursor API returned HTTP \(statusCode)."
        }
    }
}

struct UsageBreakdown: Decodable, Sendable {
    let included: Int?
    let bonus: Int?
    let total: Int?
}

struct PlanUsage: Decodable, Sendable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
    let breakdown: UsageBreakdown?
    let autoPercentUsed: Double?
    let apiPercentUsed: Double?
    let totalPercentUsed: Double?
}

struct OnDemandUsage: Decodable, Sendable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?

    var isEnabled: Bool { enabled ?? false }
}

/// Spend on token-based Enterprise contracts that omit `plan`.
struct OverallUsage: Decodable, Sendable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
}

struct IndividualUsage: Decodable, Sendable {
    let plan: PlanUsage?
    let onDemand: OnDemandUsage?
    let overall: OverallUsage?
}

struct TeamUsage: Decodable, Sendable {
    let onDemand: OnDemandUsage?
}

struct UsageSummary: Decodable, Sendable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let membershipType: String?
    let limitType: String?
    let isUnlimited: Bool?
    let autoModelSelectedDisplayMessage: String?
    let namedModelSelectedDisplayMessage: String?
    let individualUsage: IndividualUsage?
    let teamUsage: TeamUsage?
}

struct PublicProfileTokens: Equatable, Sendable {
    let handle: String
    let periodTokens: Int
    let totalTokens: Int
}

enum CursorAPI {
    private static let usageSummaryURL = URL(string: "https://cursor.com/api/usage-summary")!
    private static let userProfileURL = URL(string: "https://cursor.com/api/dashboard/get-user-profile")!
    static let networkSession = SecureNetworkSession.make()

    static func fetchUsageSummary(
        credentials suppliedCredentials: SessionCredentials? = nil,
        session: URLSession = networkSession
    ) async throws -> UsageSummary {
        var credentials = try suppliedCredentials ?? TokenProvider.loadSessionCredentials()

        do {
            return try await requestUsageSummary(credentials: credentials, session: session)
        } catch CursorAPIError.notAuthenticated {
            guard suppliedCredentials == nil else { throw CursorAPIError.notAuthenticated }
            credentials = try TokenProvider.loadSessionCredentials()
            return try await requestUsageSummary(credentials: credentials, session: session)
        }
    }

    /// Token totals from the public profile heatmap (`cursor.com/@handle`).
    static func fetchPublicProfileTokens(
        periodStart: Date?,
        credentials suppliedCredentials: SessionCredentials? = nil,
        session: URLSession = networkSession
    ) async throws -> PublicProfileTokens {
        var credentials = try suppliedCredentials ?? TokenProvider.loadSessionCredentials()
        do {
            return try await requestPublicProfileTokens(
                credentials: credentials,
                periodStart: periodStart,
                session: session
            )
        } catch CursorAPIError.notAuthenticated {
            guard suppliedCredentials == nil else { throw CursorAPIError.notAuthenticated }
            credentials = try TokenProvider.loadSessionCredentials()
            return try await requestPublicProfileTokens(
                credentials: credentials,
                periodStart: periodStart,
                session: session
            )
        }
    }

    private static func requestUsageSummary(
        credentials: SessionCredentials,
        session: URLSession
    ) async throws -> UsageSummary {
        var request = URLRequest(url: usageSummaryURL)
        request.httpMethod = "GET"
        request.setValue("WorkosCursorSessionToken=\(credentials.cookieValue)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw CursorAPIError.notAuthenticated
        default:
            throw CursorAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let summary = try JSONDecoder().decode(UsageSummary.self, from: data)
            guard summary.hasDisplayableUsage else {
                throw CursorAPIError.invalidResponse
            }
            return summary
        } catch {
            throw CursorAPIError.invalidResponse
        }
    }

    private static func requestPublicProfileTokens(
        credentials: SessionCredentials,
        periodStart: Date?,
        session: URLSession
    ) async throws -> PublicProfileTokens {
        let handle = try await requestProfileHandle(credentials: credentials, session: session)
        let daily = try await requestProfileActivityCounts(handle: handle, session: session)
        let totalTokens = daily.reduce(0) { $0 + $1.count }
        let periodStartDay = periodStart.map(utcDateString)
        let periodTokens = daily.reduce(0) { sum, day in
            guard let periodStartDay, day.date >= periodStartDay else { return sum }
            return sum + day.count
        }
        return PublicProfileTokens(handle: handle, periodTokens: periodTokens, totalTokens: totalTokens)
    }

    private static func requestProfileHandle(
        credentials: SessionCredentials,
        session: URLSession
    ) async throws -> String {
        var request = URLRequest(url: userProfileURL)
        request.httpMethod = "POST"
        request.setValue("WorkosCursorSessionToken=\(credentials.cookieValue)", forHTTPHeaderField: "Cookie")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw CursorAPIError.notAuthenticated
        default:
            throw CursorAPIError.httpError(statusCode: httpResponse.statusCode)
        }

        struct UserProfileResponse: Decodable {
            struct Profile: Decodable {
                let handle: String?
            }

            let profile: Profile?
        }

        guard let handle = try? JSONDecoder().decode(UserProfileResponse.self, from: data).profile?.handle,
              !handle.isEmpty
        else {
            throw CursorAPIError.invalidResponse
        }
        return handle
    }

    private static func requestProfileActivityCounts(
        handle: String,
        session: URLSession
    ) async throws -> [ProfileActivityDay] {
        guard let url = URL(string: "https://cursor.com/@\(handle)") else {
            throw CursorAPIError.invalidResponse
        }

        // This page is public. Sending the dashboard session cookie makes
        // cursor.com 307-redirect in a loop, so use a cookieless session.
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "RSC")
        request.setValue("/@\(handle)", forHTTPHeaderField: "Next-Url")
        request.setValue("text/x-component", forHTTPHeaderField: "Accept")
        request.setValue("CursorBar/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let payload = String(data: data, encoding: .utf8)
        else {
            throw CursorAPIError.invalidResponse
        }

        if payload.contains("This profile is private") || payload.contains("profile is not public") {
            throw CursorAPIError.invalidResponse
        }

        return try parseActivityCounts(from: payload)
    }

    private static func parseActivityCounts(from payload: String) throws -> [ProfileActivityDay] {
        guard let countsJSON = extractJSONArray(from: payload, labeled: "activityCounts"),
              let data = countsJSON.data(using: .utf8),
              let counts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            throw CursorAPIError.invalidResponse
        }

        let days: [ProfileActivityDay] = counts.compactMap { day in
            guard let date = day["date"] as? String else { return nil }
            let count: Int
            switch day["count"] {
            case let number as NSNumber:
                count = number.intValue
            case let int as Int:
                count = int
            default:
                return nil
            }
            return ProfileActivityDay(date: date, count: count)
        }
        guard !days.isEmpty else { throw CursorAPIError.invalidResponse }
        return days
    }

    private static func extractJSONArray(from payload: String, labeled label: String) -> String? {
        let needle = "\"\(label)\":"
        guard let needleRange = payload.range(of: needle) else { return nil }

        var start = needleRange.upperBound
        while start < payload.endIndex, payload[start].isWhitespace {
            start = payload.index(after: start)
        }
        guard start < payload.endIndex, payload[start] == "[" else { return nil }

        var depth = 0
        var inString = false
        var escaping = false
        var index = start

        while index < payload.endIndex {
            let character = payload[index]
            if inString {
                if escaping {
                    escaping = false
                } else if character == "\\" {
                    escaping = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else if character == "[" {
                depth += 1
            } else if character == "]" {
                depth -= 1
                if depth == 0 {
                    return String(payload[start...index])
                }
            }
            index = payload.index(after: index)
        }
        return nil
    }

    private static func utcDateString(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "GMT")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

private struct ProfileActivityDay {
    let date: String
    let count: Int
}
