import Foundation
import AppKit

enum UpdateError: Error, LocalizedError {
    case requestFailed
    case invalidRelease

    var errorDescription: String? {
        switch self {
        case .requestFailed:
            "Could not reach GitHub."
        case .invalidRelease:
            "GitHub returned an invalid release."
        }
    }
}

@MainActor
final class UpdateChecker: ObservableObject {
    struct Release: Equatable {
        let version: String
        let pageURL: URL
    }

    @Published private(set) var availableUpdate: Release?
    @Published private(set) var isChecking = false
    @Published private(set) var statusMessage: String?

    static var currentVersion: String { AppIdentity.version }

    private let session: URLSession
    private let endpoint: URL
    private let installedVersion: String

    init(
        session: URLSession = SecureNetworkSession.make(),
        endpoint: URL = AppIdentity.latestReleaseAPIURL,
        installedVersion: String = AppIdentity.version
    ) {
        self.session = session
        self.endpoint = endpoint
        self.installedVersion = installedVersion
    }

    /// - Parameter announceResult: when true (manual check), also report "up to date" and failures.
    func checkForUpdates(announceResult: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        if announceResult {
            statusMessage = nil
        }
        defer { isChecking = false }

        do {
            guard endpoint == AppIdentity.latestReleaseAPIURL else {
                throw UpdateError.requestFailed
            }
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("CursorBar/\(installedVersion)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw UpdateError.requestFailed
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            guard release.htmlURL.scheme == "https",
                  release.htmlURL.host == AppIdentity.repositoryURL.host,
                  release.htmlURL.path.hasPrefix("/smallyunet/cursorbar/releases/")
            else { throw UpdateError.invalidRelease }

            if Self.isVersion(latestVersion, newerThan: installedVersion) {
                availableUpdate = Release(version: latestVersion, pageURL: release.htmlURL)
                statusMessage = nil
            } else {
                availableUpdate = nil
                if announceResult {
                    statusMessage = "Up to date (v\(installedVersion))"
                }
            }
        } catch {
            if announceResult {
                statusMessage = "Update check failed: \(error.localizedDescription)"
            }
        }
    }

    func openAvailableRelease() {
        guard let release = availableUpdate else { return }
        NSWorkspace.shared.open(release.pageURL)
    }

    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        guard let lhs = versionComponents(candidate),
              let rhs = versionComponents(current) else {
            return false
        }
        return lhs.lexicographicallyPrecedes(rhs) == false && lhs != rhs
    }

    private static func versionComponents(_ value: String) -> [Int]? {
        let normalized = value.hasPrefix("v") || value.hasPrefix("V")
            ? String(value.dropFirst())
            : value
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) })
        else { return nil }
        let components = parts.compactMap { Int($0) }
        return components.count == 3 ? components : nil
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
