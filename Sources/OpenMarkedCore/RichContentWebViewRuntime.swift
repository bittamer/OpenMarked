#if canImport(WebKit)
import Foundation
import WebKit

public struct RichContentRuntimeStatus: Equatable, Sendable {
    public let ready: Bool
    public let skipped: Bool
    public let timedOut: Bool
    public let requestedFeatures: Set<RichMarkdownFeature>
    public let errors: [String]

    public init(
        ready: Bool,
        skipped: Bool = false,
        timedOut: Bool = false,
        requestedFeatures: Set<RichMarkdownFeature> = [],
        errors: [String] = []
    ) {
        self.ready = ready
        self.skipped = skipped
        self.timedOut = timedOut
        self.requestedFeatures = requestedFeatures
        self.errors = errors
    }

    public var hasFailure: Bool {
        timedOut || !ready || !errors.isEmpty
    }

    public var userMessage: String {
        if skipped {
            return "Rich content skipped"
        }
        if timedOut {
            return "Rich content rendering timed out"
        }
        if let firstError = errors.first {
            return "Rich content rendering failed: \(firstError)"
        }
        return "Rich content ready"
    }
}

@MainActor
public enum RichContentWebViewRuntime {
    public static func installAndWait(
        for state: RichMarkdownRenderState,
        in webView: WKWebView,
        timeoutMilliseconds: Int = RichContentRuntimeAssembler.defaultTimeoutMilliseconds
    ) async throws -> RichContentRuntimeStatus {
        guard state.requiresRichContentRuntime else {
            return RichContentRuntimeStatus(
                ready: true,
                skipped: true,
                requestedFeatures: state.richContentRuntimeFeatures
            )
        }

        for script in try RichContentRuntimeAssembler.runtimeScripts(for: state) {
            _ = try await webView.evaluateJavaScript(script)
        }

        let invocationResult = try await webView.evaluateJavaScript(
            RichContentRuntimeAssembler.invocationScript(for: state)
        )
        let waitResult = try await webView.evaluateJavaScript(
            RichContentRuntimeAssembler.waitUntilReadyScript(timeoutMilliseconds: timeoutMilliseconds)
        )
        let statusResult = (waitResult as? [String: Any]) == nil ? invocationResult : waitResult

        return status(
            from: statusResult,
            requestedFeatures: state.richContentRuntimeFeatures
        )
    }

    public static func status(
        from javaScriptResult: Any?,
        requestedFeatures: Set<RichMarkdownFeature>
    ) -> RichContentRuntimeStatus {
        guard let dictionary = javaScriptResult as? [String: Any] else {
            return RichContentRuntimeStatus(ready: true, requestedFeatures: requestedFeatures)
        }

        return RichContentRuntimeStatus(
            ready: boolValue(in: dictionary, forKey: "ready") ?? false,
            skipped: boolValue(in: dictionary, forKey: "skipped") ?? false,
            timedOut: boolValue(in: dictionary, forKey: "timedOut") ?? false,
            requestedFeatures: requestedFeatures,
            errors: stringArray(in: dictionary, forKey: "errors")
        )
    }

    private static func boolValue(in dictionary: [String: Any], forKey key: String) -> Bool? {
        if let number = dictionary[key] as? NSNumber {
            return number.boolValue
        }
        return dictionary[key] as? Bool
    }

    private static func stringArray(in dictionary: [String: Any], forKey key: String) -> [String] {
        guard let values = dictionary[key] as? [Any] else {
            return []
        }

        return values.map { String(describing: $0) }
    }
}
#endif
