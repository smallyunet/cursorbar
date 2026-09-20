import Foundation

enum AppIdentity {
    static let bundleIdentifier = "com.smallyunet.cursorbar"
    static let repositoryURL = URL(string: "https://github.com/smallyunet/cursorbar")!
    static let latestReleaseAPIURL = URL(
        string: "https://api.github.com/repos/smallyunet/cursorbar/releases/latest"
    )!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "development"
    }
}
