import Foundation

enum SecureNetworkSession {
    static func make() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(
            configuration: configuration,
            delegate: SameHostHTTPSRedirectDelegate(),
            delegateQueue: nil
        )
    }
}

private final class SameHostHTTPSRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard request.url?.scheme == "https",
              request.url?.host == task.originalRequest?.url?.host else {
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
