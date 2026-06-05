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
    let onStatusUpdate: (String) -> Void
    let onRichContentRendering: (Set<RichMarkdownFeature>) -> Void
    let onRichContentReady: (Set<RichMarkdownFeature>) -> Void
    let onRichContentFailed: (String) -> Void
    let onSearchResult: (PreviewSearchResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onStatusUpdate: onStatusUpdate,
            onRichContentRendering: onRichContentRendering,
            onRichContentReady: onRichContentReady,
            onRichContentFailed: onRichContentFailed,
            onSearchResult: onSearchResult
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = webView
        context.coordinator.load(renderResult: renderResult, baseURL: baseURL)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onStatusUpdate = onStatusUpdate
        context.coordinator.onRichContentRendering = onRichContentRendering
        context.coordinator.onRichContentReady = onRichContentReady
        context.coordinator.onRichContentFailed = onRichContentFailed
        context.coordinator.onSearchResult = onSearchResult
        context.coordinator.preservesScrollPosition = preservesScrollPosition
        context.coordinator.usesReducedMotion = usesReducedMotion
        context.coordinator.load(renderResult: renderResult, baseURL: baseURL)

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

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var onStatusUpdate: (String) -> Void
        var onRichContentRendering: (Set<RichMarkdownFeature>) -> Void
        var onRichContentReady: (Set<RichMarkdownFeature>) -> Void
        var onRichContentFailed: (String) -> Void
        var onSearchResult: (PreviewSearchResult) -> Void
        var lastHTML: String?
        var lastBaseURL: URL?
        var lastRichMarkdownState: RichMarkdownRenderState = .empty
        var lastNavigationRequestID: UUID?
        var lastSearchRequestID: UUID?
        var preservesScrollPosition = true
        var usesReducedMotion = false
        private var pendingNavigationID: String?
        private var pendingSearchRequest: PreviewSearchRequest?
        private var activeSearchQuery = ""
        private var scrollRatio: Double = 0

        init(
            onStatusUpdate: @escaping (String) -> Void,
            onRichContentRendering: @escaping (Set<RichMarkdownFeature>) -> Void,
            onRichContentReady: @escaping (Set<RichMarkdownFeature>) -> Void,
            onRichContentFailed: @escaping (String) -> Void,
            onSearchResult: @escaping (PreviewSearchResult) -> Void
        ) {
            self.onStatusUpdate = onStatusUpdate
            self.onRichContentRendering = onRichContentRendering
            self.onRichContentReady = onRichContentReady
            self.onRichContentFailed = onRichContentFailed
            self.onSearchResult = onSearchResult
        }

        func load(renderResult: RenderResult, baseURL: URL) {
            let securedHTML = PreviewHTMLSecurityPolicy.sanitize(renderResult.fullHTML)
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

            let escapedID = PreviewJavaScriptEscaper.escape(id)
            let behavior = usesReducedMotion ? "auto" : "smooth"
            let script = """
            (function() {
              var target = document.getElementById('\(escapedID)');
              if (!target) { return false; }
              target.scrollIntoView({ behavior: '\(behavior)', block: 'start' });
              target.classList.add('om-heading-target');
              window.setTimeout(function() { target.classList.remove('om-heading-target'); }, 900);
              return true;
            })();
            """

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

            let actionName: String
            switch request.action {
            case .setQuery:
                actionName = "set"
            case .next:
                actionName = "next"
            case .previous:
                actionName = "previous"
            case .clear:
                actionName = "clear"
            }

            activeSearchQuery = request.query
            let escapedQuery = PreviewJavaScriptEscaper.escape(request.query)
            let script = """
            (function() {
              if (!window.openMarkedSearch) { return { query: '\(escapedQuery)', count: 0, selectedIndex: 0 }; }
              return window.openMarkedSearch.run('\(escapedQuery)', '\(actionName)');
            })();
            """

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
            let script = """
            (function() {
              var scrollable = Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
              window.scrollTo(0, scrollable * \(boundedRatio));
            })();
            """
            webView?.evaluateJavaScript(script)
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
            let css = """
            (function() {
              if (!document.getElementById('om-preview-helpers')) {
                var style = document.createElement('style');
                style.id = 'om-preview-helpers';
                style.textContent = '.om-heading-target { outline: 2px solid -webkit-focus-ring-color; outline-offset: 4px; transition: outline-color 0.2s ease; } .om-search-match { background: color-mix(in srgb, Highlight 28%, transparent); color: inherit; border-radius: 2px; } .om-search-current { background: Mark; color: MarkText; }';
                document.head.appendChild(style);
              }
              window.openMarkedPrefersReducedMotion = \(usesReducedMotion ? "true" : "false");
              window.openMarkedSearch = {
                state: { query: '', index: -1 },
                clear: function() {
                  var matches = Array.prototype.slice.call(document.querySelectorAll('.om-search-match'));
                  matches.forEach(function(match) {
                    var text = document.createTextNode(match.textContent || '');
                    match.parentNode.replaceChild(text, match);
                    if (text.parentNode) { text.parentNode.normalize(); }
                  });
                },
                textNodes: function(root) {
                  var nodes = [];
                  var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
                    acceptNode: function(node) {
                      if (!node.nodeValue || !node.nodeValue.trim()) { return NodeFilter.FILTER_REJECT; }
                      var parent = node.parentElement;
                      if (!parent) { return NodeFilter.FILTER_REJECT; }
                      if (parent.closest('script, style, textarea, select, .om-search-match')) { return NodeFilter.FILTER_REJECT; }
                      return NodeFilter.FILTER_ACCEPT;
                    }
                  });
                  while (walker.nextNode()) { nodes.push(walker.currentNode); }
                  return nodes;
                },
                highlight: function(query) {
                  var root = document.querySelector('.om-document') || document.body;
                  var lowerQuery = query.toLocaleLowerCase();
                  var nodes = this.textNodes(root);
                  var matches = [];
                  nodes.forEach(function(node) {
                    var text = node.nodeValue;
                    var lowerText = text.toLocaleLowerCase();
                    var start = 0;
                    var index = lowerText.indexOf(lowerQuery, start);
                    if (index === -1) { return; }
                    var fragment = document.createDocumentFragment();
                    while (index !== -1) {
                      if (index > start) {
                        fragment.appendChild(document.createTextNode(text.slice(start, index)));
                      }
                      var span = document.createElement('mark');
                      span.className = 'om-search-match';
                      span.textContent = text.slice(index, index + query.length);
                      fragment.appendChild(span);
                      matches.push(span);
                      start = index + query.length;
                      index = lowerText.indexOf(lowerQuery, start);
                    }
                    if (start < text.length) {
                      fragment.appendChild(document.createTextNode(text.slice(start)));
                    }
                    node.parentNode.replaceChild(fragment, node);
                  });
                  return matches;
                },
                run: function(query, action) {
                  this.clear();
                  query = query || '';
                  if (!query) {
                    this.state = { query: '', index: -1 };
                    return { query: '', count: 0, selectedIndex: 0 };
                  }
                  var prior = this.state;
                  var matches = this.highlight(query);
                  if (!matches.length) {
                    this.state = { query: query, index: -1 };
                    return { query: query, count: 0, selectedIndex: 0 };
                  }
                  var index = 0;
                  if (prior.query === query && prior.index >= 0) {
                    if (action === 'previous') {
                      index = (prior.index - 1 + matches.length) % matches.length;
                    } else if (action === 'next') {
                      index = (prior.index + 1) % matches.length;
                    } else {
                      index = Math.min(prior.index, matches.length - 1);
                    }
                  }
                  matches[index].classList.add('om-search-current');
                  matches[index].scrollIntoView({ behavior: window.openMarkedPrefersReducedMotion ? 'auto' : 'smooth', block: 'center' });
                  this.state = { query: query, index: index };
                  return { query: query, count: matches.length, selectedIndex: index + 1 };
                }
              };
            })();
            """
            webView?.evaluateJavaScript(css) { _, _ in
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

enum PreviewJavaScriptEscaper {
    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
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
