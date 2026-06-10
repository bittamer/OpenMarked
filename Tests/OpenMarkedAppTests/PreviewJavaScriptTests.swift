@testable import OpenMarkedApp
@testable import OpenMarkedCore
import Foundation

#if canImport(WebKit) && canImport(Testing)
import WebKit
import Testing

@Test("Preview JavaScript literal uses JSON quoting")
func previewJavaScriptLiteralUsesJSONQuoting() {
    let literal = PreviewJavaScript.literal("quote \" apostrophe ' slash \\ line\nsep\u{2028}\u{2029}")

    #expect(literal.hasPrefix("\""))
    #expect(literal.hasSuffix("\""))
    #expect(literal.contains("\\\""))
    #expect(literal.contains("\\\\"))
    #expect(literal.contains("\\n"))
    #expect(literal.contains("\\u2028"))
    #expect(literal.contains("\\u2029"))
    #expect(!literal.contains("\u{2028}"))
    #expect(!literal.contains("\u{2029}"))
}

@Test("Preview search reuses matches for same-query navigation")
@MainActor
func previewSearchReusesMatchesForSameQueryNavigation() async throws {
    let (webView, observer) = try await makeLoadedWebView(
        html: """
        <!doctype html>
        <html>
        <head><meta charset="utf-8"></head>
        <body>
          <main class="om-document">
            <h1 id="intro">Intro</h1>
            <p>Alpha beta alpha.</p>
            <p>Alphabet soup.</p>
          </main>
        </body>
        </html>
        """
    )
    _ = observer

    try await evaluateJavaScript(
        try PreviewJavaScript.installHelpersScript(
            prefersReducedMotion: true,
            sectionTrackingBehavior: .active
        ),
        in: webView
    )

    let firstResult = try await searchResult(
        PreviewJavaScript.searchScript(query: "alpha", actionName: "set"),
        in: webView
    )
    #expect(firstResult == SearchPayload(query: "alpha", count: 3, selectedIndex: 1))

    try await evaluateJavaScript(
        """
        document.querySelectorAll('.om-search-match')[0].setAttribute('data-reuse-probe', 'kept');
        true;
        """,
        in: webView
    )

    let nextResult = try await searchResult(
        PreviewJavaScript.searchScript(query: "alpha", actionName: "next"),
        in: webView
    )
    #expect(nextResult == SearchPayload(query: "alpha", count: 3, selectedIndex: 2))
    let reuseProbe = try await evaluateJavaScript(
        "document.querySelectorAll('.om-search-match')[0].getAttribute('data-reuse-probe');",
        in: webView
    ) as? String
    #expect(reuseProbe == "kept")

    let previousResult = try await searchResult(
        PreviewJavaScript.searchScript(query: "alpha", actionName: "previous"),
        in: webView
    )
    #expect(previousResult == SearchPayload(query: "alpha", count: 3, selectedIndex: 1))

    let changedQueryResult = try await searchResult(
        PreviewJavaScript.searchScript(query: "beta", actionName: "set"),
        in: webView
    )
    #expect(changedQueryResult == SearchPayload(query: "beta", count: 1, selectedIndex: 1))
    let changedProbe = try await evaluateJavaScript(
        "document.querySelector('.om-search-match').getAttribute('data-reuse-probe');",
        in: webView
    ) as? String
    #expect(changedProbe == nil)
}

@Test("Section tracking behavior script updates live preview")
@MainActor
func sectionTrackingBehaviorScriptUpdatesLivePreview() async throws {
    let (webView, observer) = try await makeLoadedWebView(
        html: """
        <!doctype html>
        <html>
        <head><meta charset="utf-8"></head>
        <body><main class="om-document"><h1 id="intro">Intro</h1></main></body>
        </html>
        """
    )
    _ = observer

    try await evaluateJavaScript(
        try PreviewJavaScript.installHelpersScript(
            prefersReducedMotion: true,
            sectionTrackingBehavior: .active
        ),
        in: webView
    )
    try await evaluateJavaScript(PreviewJavaScript.sectionTrackingBehaviorScript(.disabled), in: webView)
    #expect(try await evaluateJavaScript("window.openMarkedSectionTrackingBehavior;", in: webView) as? String == "disabled")

    try await evaluateJavaScript(PreviewJavaScript.sectionTrackingBehaviorScript(.idleOnly), in: webView)
    #expect(try await evaluateJavaScript("window.openMarkedSectionTrackingBehavior;", in: webView) as? String == "idleOnly")
    #expect(try await evaluateJavaScript("window.openMarkedSectionTracker.installed;", in: webView) as? Bool == true)
}

private struct SearchPayload: Equatable {
    let query: String
    let count: Int
    let selectedIndex: Int
}

@MainActor
private func makeLoadedWebView(html: String) async throws -> (WKWebView, WebViewNavigationObserver) {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    let webView = WKWebView(frame: .zero, configuration: configuration)
    let observer = WebViewNavigationObserver()
    webView.navigationDelegate = observer

    try await observer.loadHTMLString(html, in: webView)
    return (webView, observer)
}

@discardableResult
@MainActor
private func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> Any {
    try await withCheckedThrowingContinuation { continuation in
        webView.evaluateJavaScript(script) { result, error in
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: result ?? NSNull())
            }
        }
    }
}

@MainActor
private func searchResult(_ script: String, in webView: WKWebView) async throws -> SearchPayload {
    let result = try await evaluateJavaScript(script, in: webView)
    guard let dictionary = result as? [String: Any] else {
        throw PreviewJavaScriptTestError.invalidSearchResult
    }

    return SearchPayload(
        query: dictionary["query"] as? String ?? "",
        count: (dictionary["count"] as? NSNumber)?.intValue ?? dictionary["count"] as? Int ?? 0,
        selectedIndex: (dictionary["selectedIndex"] as? NSNumber)?.intValue ?? dictionary["selectedIndex"] as? Int ?? 0
    )
}

@MainActor
private final class WebViewNavigationObserver: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func loadHTMLString(_ html: String, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString(html, baseURL: FileManager.default.temporaryDirectory)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private enum PreviewJavaScriptTestError: Error {
    case invalidSearchResult
}
#endif
