import Foundation

public enum RichContentAssetError: Error, Equatable, LocalizedError, Sendable {
    case missingResource(String)
    case unreadableResource(String)

    public var errorDescription: String? {
        switch self {
        case .missingResource(let path):
            return "OpenMarked could not find bundled rich content resource \(path)."
        case .unreadableResource(let path):
            return "OpenMarked could not read bundled rich content resource \(path)."
        }
    }
}

public struct RichContentPackage: Equatable, Sendable {
    public let name: String
    public let version: String
    public let license: String
    public let sourceURL: String
    public let registryURL: String

    public init(name: String, version: String, license: String, sourceURL: String, registryURL: String) {
        self.name = name
        self.version = version
        self.license = license
        self.sourceURL = sourceURL
        self.registryURL = registryURL
    }
}

public struct RichContentAssetManifest: Equatable, Sendable {
    public let mermaid: RichContentPackage
    public let katex: RichContentPackage
    public let hasMermaidRuntime: Bool
    public let hasKaTeXRuntime: Bool
    public let hasKaTeXCSS: Bool
    public let hasOpenMarkedRuntime: Bool
    public let hasOpenMarkedCSS: Bool
    public let katexFontCount: Int

    public init(
        mermaid: RichContentPackage,
        katex: RichContentPackage,
        hasMermaidRuntime: Bool,
        hasKaTeXRuntime: Bool,
        hasKaTeXCSS: Bool,
        hasOpenMarkedRuntime: Bool,
        hasOpenMarkedCSS: Bool,
        katexFontCount: Int
    ) {
        self.mermaid = mermaid
        self.katex = katex
        self.hasMermaidRuntime = hasMermaidRuntime
        self.hasKaTeXRuntime = hasKaTeXRuntime
        self.hasKaTeXCSS = hasKaTeXCSS
        self.hasOpenMarkedRuntime = hasOpenMarkedRuntime
        self.hasOpenMarkedCSS = hasOpenMarkedCSS
        self.katexFontCount = katexFontCount
    }
}

public enum RichContentAssetStore {
    public static let mermaidPackage = RichContentPackage(
        name: "mermaid",
        version: "11.15.0",
        license: "MIT",
        sourceURL: "https://github.com/mermaid-js/mermaid",
        registryURL: "https://registry.npmjs.org/mermaid/-/mermaid-11.15.0.tgz"
    )

    public static let katexPackage = RichContentPackage(
        name: "katex",
        version: "0.17.0",
        license: "MIT",
        sourceURL: "https://github.com/KaTeX/KaTeX",
        registryURL: "https://registry.npmjs.org/katex/-/katex-0.17.0.tgz"
    )

    public static func manifest() -> RichContentAssetManifest {
        RichContentAssetManifest(
            mermaid: mermaidPackage,
            katex: katexPackage,
            hasMermaidRuntime: resourceExists("RichContent/Mermaid/mermaid.min.js"),
            hasKaTeXRuntime: resourceExists("RichContent/KaTeX/katex.min.js"),
            hasKaTeXCSS: resourceExists("RichContent/KaTeX/katex.min.css"),
            hasOpenMarkedRuntime: resourceExists("RichContent/OpenMarked/rich-content-runtime.js"),
            hasOpenMarkedCSS: resourceExists("RichContent/OpenMarked/rich-content.css"),
            katexFontCount: katexFontURLs().count
        )
    }

    public static func requiredResourceURL(_ relativePath: String) throws -> URL {
        guard let resourceURL = Bundle.module.resourceURL else {
            throw RichContentAssetError.missingResource(relativePath)
        }

        let nestedURL = resourceURL.appendingPathComponent(relativePath)
        if FileManager.default.fileExists(atPath: nestedURL.path) {
            return nestedURL
        }

        let leafURL = URL(fileURLWithPath: relativePath)
        let resourceName = leafURL.deletingPathExtension().lastPathComponent
        let resourceExtension = leafURL.pathExtension.isEmpty ? nil : leafURL.pathExtension
        if let flattenedURL = Bundle.module.url(forResource: resourceName, withExtension: resourceExtension),
           FileManager.default.fileExists(atPath: flattenedURL.path) {
            return flattenedURL
        }

        throw RichContentAssetError.missingResource(relativePath)
    }

    public static func resourceString(_ relativePath: String) throws -> String {
        let url = try requiredResourceURL(relativePath)
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw RichContentAssetError.unreadableResource(relativePath)
        }
    }

    public static func mermaidRuntimeJavaScript() throws -> String {
        try resourceString("RichContent/Mermaid/mermaid.min.js")
    }

    public static func katexRuntimeJavaScript() throws -> String {
        try resourceString("RichContent/KaTeX/katex.min.js")
    }

    public static func katexCSS() throws -> String {
        try resourceString("RichContent/KaTeX/katex.min.css")
    }

    public static func katexCSSForHTML() throws -> String {
        var css = try katexCSS()

        for fontURL in katexFontURLs() {
            css = css.replacingOccurrences(
                of: "url(fonts/\(fontURL.lastPathComponent))",
                with: "url('\(fontURL.absoluteString)')"
            )
        }

        return css
    }

    public static func openMarkedRuntimeJavaScript() throws -> String {
        try resourceString("RichContent/OpenMarked/rich-content-runtime.js")
    }

    public static func openMarkedRichContentCSS() throws -> String {
        try resourceString("RichContent/OpenMarked/rich-content.css")
    }

    public static func katexFontURLs() -> [URL] {
        guard let resourceURL = Bundle.module.resourceURL else {
            return []
        }

        let nestedDirectoryURL = resourceURL.appendingPathComponent("RichContent/KaTeX/fonts")
        let searchURL = FileManager.default.fileExists(atPath: nestedDirectoryURL.path) ? nestedDirectoryURL : resourceURL

        return ((try? FileManager.default.contentsOfDirectory(
            at: searchURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { url in
                url.lastPathComponent.hasPrefix("KaTeX_")
                    && ["ttf", "woff", "woff2"].contains(url.pathExtension.lowercased())
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func resourceExists(_ relativePath: String) -> Bool {
        (try? requiredResourceURL(relativePath)) != nil
    }
}

public enum RichContentHTMLAssets {
    public static func styleBlock(for state: RichMarkdownRenderState) -> String {
        guard state.requiresRichContentStyles else {
            return ""
        }

        var cssBlocks: [String] = []
        if let openMarkedCSS = try? RichContentAssetStore.openMarkedRichContentCSS() {
            cssBlocks.append(openMarkedCSS)
        }

        if state.requiresMathRuntime, let katexCSS = try? RichContentAssetStore.katexCSSForHTML() {
            cssBlocks.append(katexCSS)
        }

        guard !cssBlocks.isEmpty else {
            return ""
        }

        return """

          <style id="om-rich-content-assets" data-openmarked-rich-content="\(featureAttribute(for: state))">
          \(cssBlocks.joined(separator: "\n"))
          </style>
        """
    }

    private static func featureAttribute(for state: RichMarkdownRenderState) -> String {
        state.richContentRuntimeFeatures
            .map(\.rawValue)
            .sorted()
            .joined(separator: " ")
    }
}

public enum RichContentRuntimeAssembler {
    public static let defaultTimeoutMilliseconds = 4_000

    public static func runtimeScripts(for state: RichMarkdownRenderState) throws -> [String] {
        guard state.requiresRichContentRuntime else {
            return []
        }

        var scripts = [try RichContentAssetStore.openMarkedRuntimeJavaScript()]
        if state.requiresMermaidRuntime {
            scripts.append(try RichContentAssetStore.mermaidRuntimeJavaScript())
        }
        if state.requiresMathRuntime {
            scripts.append(try RichContentAssetStore.katexRuntimeJavaScript())
        }

        return scripts
    }

    public static func invocationScript(for state: RichMarkdownRenderState) -> String {
        guard state.requiresRichContentRuntime else {
            return "({ ready: true, skipped: true, errors: [] });"
        }

        return """
        (function() {
          if (!window.openMarkedRichContent || !window.openMarkedRichContent.run) {
            return JSON.stringify({ ready: false, errors: ['OpenMarked rich content runtime is unavailable.'] });
          }

          return JSON.stringify(window.openMarkedRichContent.run({
            mermaid: \(state.requiresMermaidRuntime ? "true" : "false"),
            katex: \(state.requiresMathRuntime ? "true" : "false")
          }));
        })();
        """
    }

    public static func waitUntilReadyScript(timeoutMilliseconds: Int = defaultTimeoutMilliseconds) -> String {
        """
        (function() {
          if (!window.openMarkedRichContent || !window.openMarkedRichContent.waitUntilReady) {
            return JSON.stringify({ ready: false, errors: ['OpenMarked rich content runtime is unavailable.'] });
          }

          return window.openMarkedRichContent.waitUntilReady(\(timeoutMilliseconds)).then(function(result) {
            return JSON.stringify(result);
          });
        })();
        """
    }

    public static func waitUntilReadyAsyncScript(timeoutMilliseconds: Int = defaultTimeoutMilliseconds) -> String {
        """
        if (!window.openMarkedRichContent || !window.openMarkedRichContent.waitUntilReady) {
          return JSON.stringify({ ready: false, errors: ['OpenMarked rich content runtime is unavailable.'] });
        }

        const result = await window.openMarkedRichContent.waitUntilReady(\(timeoutMilliseconds));
        return JSON.stringify(result);
        """
    }
}
