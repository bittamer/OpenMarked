import AppKit
import SwiftUI
import WebKit
import OpenMarkedCore

struct PreviewNavigationRequest: Equatable, Identifiable {
    let id = UUID()
    let elementID: String
}

struct PreviewWebView: NSViewRepresentable {
    let renderResult: RenderResult
    let baseURL: URL
    let navigationRequest: PreviewNavigationRequest?
    let onStatusUpdate: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStatusUpdate: onStatusUpdate)
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
        context.coordinator.load(renderResult: renderResult, baseURL: baseURL)

        if context.coordinator.lastNavigationRequestID != navigationRequest?.id {
            context.coordinator.lastNavigationRequestID = navigationRequest?.id
            if let navigationRequest {
                context.coordinator.scrollToElement(id: navigationRequest.elementID)
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var onStatusUpdate: (String) -> Void
        var lastHTML: String?
        var lastBaseURL: URL?
        var lastNavigationRequestID: UUID?
        private var pendingNavigationID: String?
        private var scrollRatio: Double = 0

        init(onStatusUpdate: @escaping (String) -> Void) {
            self.onStatusUpdate = onStatusUpdate
        }

        func load(renderResult: RenderResult, baseURL: URL) {
            let securedHTML = PreviewHTMLSecurityPolicy.sanitize(renderResult.fullHTML)
            guard securedHTML != lastHTML || baseURL != lastBaseURL else {
                return
            }

            let previousHTML = lastHTML
            lastHTML = securedHTML
            lastBaseURL = baseURL

            guard let webView else {
                return
            }

            if previousHTML == nil {
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
            let script = """
            (function() {
              var target = document.getElementById('\(escapedID)');
              if (!target) { return false; }
              target.scrollIntoView({ behavior: 'smooth', block: 'start' });
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
            installPreviewHelpers()
            restoreScrollRatio()

            if let pendingNavigationID {
                self.pendingNavigationID = nil
                scrollToElement(id: pendingNavigationID)
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

        private func installPreviewHelpers() {
            let css = """
            (function() {
              if (document.getElementById('om-preview-helpers')) { return; }
              var style = document.createElement('style');
              style.id = 'om-preview-helpers';
              style.textContent = '.om-heading-target { outline: 2px solid -webkit-focus-ring-color; outline-offset: 4px; transition: outline-color 0.2s ease; }';
              document.head.appendChild(style);
            })();
            """
            webView?.evaluateJavaScript(css)
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
