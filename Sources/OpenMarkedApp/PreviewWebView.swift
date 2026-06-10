import AppKit
import SwiftUI
import WebKit
import OpenMarkedCore

struct PreviewNavigationRequest: Equatable, Identifiable {
    let id = UUID()
    let elementID: String
}

struct PreviewSearchRequest: Equatable, Identifiable {
    enum Action: Equatable {
        case setQuery(String)
        case next(String)
        case previous(String)
        case clear
    }

    let id = UUID()
    let action: Action

    var query: String {
        switch action {
        case .setQuery(let query), .next(let query), .previous(let query):
            return query
        case .clear:
            return ""
        }
    }
}

struct PreviewSearchResult: Equatable {
    let query: String
    let matchCount: Int
    let selectedMatchIndex: Int?
}

struct PreviewWebView: NSViewRepresentable {
    let renderResult: RenderResult
    let baseURL: URL
    let navigationRequest: PreviewNavigationRequest?
    let searchRequest: PreviewSearchRequest?
    let preservesScrollPosition: Bool
    let usesReducedMotion: Bool
    let currentSectionTrackingBehavior: CurrentSectionTrackingBehavior
    let onStatusUpdate: (String) -> Void
    let onRichContentRendering: (Set<RichMarkdownFeature>) -> Void
    let onRichContentReady: (Set<RichMarkdownFeature>) -> Void
    let onRichContentFailed: (String) -> Void
    let onSearchResult: (PreviewSearchResult) -> Void
    let onCurrentSectionChange: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onStatusUpdate: onStatusUpdate,
            onRichContentRendering: onRichContentRendering,
            onRichContentReady: onRichContentReady,
            onRichContentFailed: onRichContentFailed,
            onSearchResult: onSearchResult,
            onCurrentSectionChange: onCurrentSectionChange
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "openMarkedSection")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView
        context.coordinator.preservesScrollPosition = preservesScrollPosition
        context.coordinator.usesReducedMotion = usesReducedMotion
        context.coordinator.currentSectionTrackingBehavior = currentSectionTrackingBehavior
        context.coordinator.applySectionTrackingBehavior()
        context.coordinator.load(renderResult: renderResult, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onStatusUpdate = onStatusUpdate
        context.coordinator.onRichContentRendering = onRichContentRendering
        context.coordinator.onRichContentReady = onRichContentReady
        context.coordinator.onRichContentFailed = onRichContentFailed
        context.coordinator.onSearchResult = onSearchResult
        context.coordinator.onCurrentSectionChange = onCurrentSectionChange
        context.coordinator.preservesScrollPosition = preservesScrollPosition
        context.coordinator.usesReducedMotion = usesReducedMotion
        let previousSectionTrackingBehavior = context.coordinator.currentSectionTrackingBehavior
        context.coordinator.currentSectionTrackingBehavior = currentSectionTrackingBehavior
        context.coordinator.load(renderResult: renderResult, baseURL: baseURL)
        if previousSectionTrackingBehavior != currentSectionTrackingBehavior {
            context.coordinator.applySectionTrackingBehavior()
        }

        if context.coordinator.lastNavigationRequestID != navigationRequest?.id {
            context.coordinator.lastNavigationRequestID = navigationRequest?.id
            if let navigationRequest {
                context.coordinator.scrollToElement(id: navigationRequest.elementID)
            }
        }

        if context.coordinator.lastSearchRequestID != searchRequest?.id {
            context.coordinator.lastSearchRequestID = searchRequest?.id
            if let searchRequest {
                context.coordinator.performSearchRequest(searchRequest)
            }
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "openMarkedSection")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var onStatusUpdate: (String) -> Void
        var onRichContentRendering: (Set<RichMarkdownFeature>) -> Void
        var onRichContentReady: (Set<RichMarkdownFeature>) -> Void
        var onRichContentFailed: (String) -> Void
        var onSearchResult: (PreviewSearchResult) -> Void
        var onCurrentSectionChange: (String?) -> Void
        var lastHTML: String?
        var lastBaseURL: URL?
        var lastRichMarkdownState: RichMarkdownRenderState = .empty
        var lastNavigationRequestID: UUID?
        var lastSearchRequestID: UUID?
        var preservesScrollPosition = true
        var usesReducedMotion = false
        var currentSectionTrackingBehavior: CurrentSectionTrackingBehavior = .active
        private var pendingNavigationID: String?
        private var pendingSearchRequest: PreviewSearchRequest?
        private var activeSearchQuery = ""
        private var scrollRatio: Double = 0

        init(
            onStatusUpdate: @escaping (String) -> Void,
            onRichContentRendering: @escaping (Set<RichMarkdownFeature>) -> Void,
            onRichContentReady: @escaping (Set<RichMarkdownFeature>) -> Void,
            onRichContentFailed: @escaping (String) -> Void,
            onSearchResult: @escaping (PreviewSearchResult) -> Void,
            onCurrentSectionChange: @escaping (String?) -> Void
        ) {
            self.onStatusUpdate = onStatusUpdate
            self.onRichContentRendering = onRichContentRendering
            self.onRichContentReady = onRichContentReady
            self.onRichContentFailed = onRichContentFailed
            self.onSearchResult = onSearchResult
            self.onCurrentSectionChange = onCurrentSectionChange
        }

        func load(renderResult: RenderResult, baseURL: URL) {
            let securedHTML: String
            if let previewHTML = renderResult.previewHTML {
                securedHTML = previewHTML
            } else {
                let previewHTML = PreviewImageCache.shared.optimizedHTMLForPreview(renderResult.fullHTML, baseURL: baseURL)
                securedHTML = PreviewHTMLSecurityPolicy.sanitize(previewHTML)
            }
            let richMarkdownState = renderResult.richMarkdownState
            guard securedHTML != lastHTML || baseURL != lastBaseURL || richMarkdownState != lastRichMarkdownState else {
                return
            }

            let previousHTML = lastHTML
            lastHTML = securedHTML
            lastBaseURL = baseURL
            lastRichMarkdownState = richMarkdownState

            guard let webView else {
                return
            }

            if previousHTML == nil {
                webView.loadHTMLString(securedHTML, baseURL: baseURL)
                return
            }

            guard preservesScrollPosition else {
                scrollRatio = 0
                webView.loadHTMLString(securedHTML, baseURL: baseURL)
                return
            }

            captureScrollRatio { [weak self, weak webView] ratio in
                self?.scrollRatio = ratio
                webView?.loadHTMLString(securedHTML, baseURL: baseURL)
            }
        }

        func scrollToElement(id: String) {
            guard lastHTML != nil else {
                pendingNavigationID = id
                return
            }

            let behavior = usesReducedMotion ? "auto" : "smooth"
            let script = PreviewJavaScript.scrollToElementScript(id: id, behavior: behavior)

            webView?.evaluateJavaScript(script) { [weak self] result, _ in
                if (result as? Bool) == false {
                    self?.onStatusUpdate("Heading not found in preview")
                }
            }
        }

        func performSearchRequest(_ request: PreviewSearchRequest) {
            guard lastHTML != nil else {
                pendingSearchRequest = request
                return
            }

            activeSearchQuery = request.query
            let script = PreviewJavaScript.searchScript(
                query: request.query,
                actionName: request.action.javaScriptActionName
            )

            webView?.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self else {
                    return
                }

                let dictionary = result as? [String: Any]
                let query = dictionary?["query"] as? String ?? request.query
                let count = (dictionary?["count"] as? NSNumber)?.intValue ?? dictionary?["count"] as? Int ?? 0
                let selectedIndex = (dictionary?["selectedIndex"] as? NSNumber)?.intValue ?? dictionary?["selectedIndex"] as? Int
                self.onSearchResult(
                    PreviewSearchResult(
                        query: query,
                        matchCount: count,
                        selectedMatchIndex: selectedIndex == 0 ? nil : selectedIndex
                    )
                )
            }
        }

        func applySectionTrackingBehavior() {
            let script = PreviewJavaScript.sectionTrackingBehaviorScript(currentSectionTrackingBehavior)
            webView?.evaluateJavaScript(script)
        }

        private func captureScrollRatio(completion: @escaping (Double) -> Void) {
            let script = """
            (function() {
              var scrollable = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
              return window.scrollY / scrollable;
            })();
            """

            webView?.evaluateJavaScript(script) { result, _ in
                completion(result as? Double ?? 0)
            } ?? completion(0)
        }

        private func restoreScrollRatio() {
            let boundedRatio = max(0, min(1, scrollRatio))
            let script = PreviewJavaScript.restoreScrollRatioScript(boundedRatio)
            webView?.evaluateJavaScript(script)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "openMarkedSection" else {
                return
            }

            if let dictionary = message.body as? [String: Any] {
                let id = dictionary["id"] as? String
                onCurrentSectionChange(id?.isEmpty == true ? nil : id)
            } else if let id = message.body as? String {
                onCurrentSectionChange(id.isEmpty ? nil : id)
            } else {
                onCurrentSectionChange(nil)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            installPreviewHelpers { [weak self] in
                guard let self else {
                    return
                }

                self.installRichContentRuntime {
                    self.restoreScrollRatio()

                    if let pendingNavigationID = self.pendingNavigationID {
                        self.pendingNavigationID = nil
                        self.scrollToElement(id: pendingNavigationID)
                    }

                    if let pendingSearchRequest = self.pendingSearchRequest {
                        self.pendingSearchRequest = nil
                        self.performSearchRequest(pendingSearchRequest)
                    } else if !self.activeSearchQuery.isEmpty {
                        self.performSearchRequest(PreviewSearchRequest(action: .setQuery(self.activeSearchQuery)))
                    }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if url.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            if let fragment = url.fragment, url.deletingFragment() == webView.url?.deletingFragment() {
                scrollToElement(id: fragment)
                decisionHandler(.cancel)
                return
            }

            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }

        private func installPreviewHelpers(completion: @escaping () -> Void = {}) {
            let script: String
            do {
                script = try PreviewJavaScript.installHelpersScript(
                    prefersReducedMotion: usesReducedMotion,
                    sectionTrackingBehavior: currentSectionTrackingBehavior
                )
            } catch {
                onStatusUpdate("Preview helpers failed to load")
                completion()
                return
            }

            webView?.evaluateJavaScript(script) { _, _ in
                completion()
            }
        }

        private func installRichContentRuntime(completion: @escaping () -> Void = {}) {
            let state = lastRichMarkdownState
            guard state.requiresRichContentRuntime else {
                completion()
                return
            }

            guard let webView else {
                completion()
                return
            }

            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else {
                    completion()
                    return
                }

                do {
                    self.onRichContentRendering(state.richContentRuntimeFeatures)
                    let status = try await RichContentWebViewRuntime.installAndWait(for: state, in: webView)
                    if status.hasFailure {
                        self.onRichContentFailed(status.userMessage)
                    } else {
                        self.onRichContentReady(status.requestedFeatures)
                    }
                } catch {
                    self.onRichContentFailed("Rich content runtime failed: \(error.localizedDescription)")
                }

                completion()
            }
        }
    }
}

private extension PreviewSearchRequest.Action {
    var javaScriptActionName: String {
        switch self {
        case .setQuery:
            return "set"
        case .next:
            return "next"
        case .previous:
            return "previous"
        case .clear:
            return "clear"
        }
    }
}

enum PreviewJavaScript {
    private static let cachedHelperScript: Result<String, Error> = Result {
        guard let url = Bundle.module.url(forResource: "preview-helpers", withExtension: "js") else {
            throw PreviewJavaScriptError.missingHelperResource
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func helperScript() throws -> String {
        try cachedHelperScript.get()
    }

    static func installHelpersScript(
        prefersReducedMotion: Bool,
        sectionTrackingBehavior: CurrentSectionTrackingBehavior
    ) throws -> String {
        let configuration = """
        {"prefersReducedMotion": \(prefersReducedMotion ? "true" : "false"), "sectionTrackingBehavior": \(literal(sectionTrackingBehavior.rawValue))}
        """
        return """
        \(try helperScript())
        window.openMarkedPreviewHelpers.install(\(configuration));
        true;
        """
    }

    static func scrollToElementScript(id: String, behavior: String) -> String {
        """
        (function() {
          if (!window.openMarkedPreviewHelpers) { return false; }
          return window.openMarkedPreviewHelpers.scrollToElement(\(literal(id)), \(literal(behavior)));
        })();
        """
    }

    static func searchScript(query: String, actionName: String) -> String {
        let queryLiteral = literal(query)
        return """
        (function() {
          if (!window.openMarkedSearch) { return { query: \(queryLiteral), count: 0, selectedIndex: 0 }; }
          return window.openMarkedSearch.run(\(queryLiteral), \(literal(actionName)));
        })();
        """
    }

    static func sectionTrackingBehaviorScript(_ behavior: CurrentSectionTrackingBehavior) -> String {
        """
        (function() {
          if (window.openMarkedPreviewHelpers) {
            window.openMarkedPreviewHelpers.applySectionTrackingBehavior(\(literal(behavior.rawValue)));
          } else {
            window.openMarkedSectionTrackingBehavior = \(literal(behavior.rawValue));
          }
        })();
        """
    }

    static func restoreScrollRatioScript(_ ratio: Double) -> String {
        """
        (function() {
          if (window.openMarkedPreviewHelpers) {
            window.openMarkedPreviewHelpers.restoreScrollRatio(\(ratio));
          }
        })();
        """
    }

    static func literal(_ value: String) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: [value], options: [])
            let jsonArray = String(decoding: data, as: UTF8.self)
            let startIndex = jsonArray.index(after: jsonArray.startIndex)
            let endIndex = jsonArray.index(before: jsonArray.endIndex)
            return String(jsonArray[startIndex..<endIndex])
                .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        } catch {
            return "\"\""
        }
    }
}

private enum PreviewJavaScriptError: Error {
    case missingHelperResource
}

private extension URL {
    func deletingFragment() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.fragment = nil
        return components.url ?? self
    }
}
