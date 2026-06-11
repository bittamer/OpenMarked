import CMarkdownGFM
import Darwin
import Foundation

public protocol MarkdownRenderer {
    func render(_ request: RenderRequest) throws -> RenderResult
}

public struct RenderRequest: Equatable, Sendable {
    public let document: MarkdownDocument
    public let options: RenderOptions
    public let theme: PreviewTheme
    public let fontScale: Double
    public let allowsRemoteImages: Bool

    public init(
        document: MarkdownDocument,
        options: RenderOptions = RenderOptions(),
        theme: PreviewTheme = PreviewThemeStore.defaultTheme,
        fontScale: Double = 1.0,
        allowsRemoteImages: Bool = true
    ) {
        self.document = document
        self.options = options
        self.theme = theme
        self.fontScale = fontScale
        self.allowsRemoteImages = allowsRemoteImages
    }
}

public struct RenderOptions: Equatable, Sendable {
    public var allowsRawHTML: Bool
    public var parsesFootnotes: Bool
    public var validatesUTF8: Bool
    public var usesGitHubCodeBlockLanguageClass: Bool
    public var enabledExtensions: Set<GFMExtension>
    public var renderProfile: MarkdownRenderProfile
    public var richMarkdownOptions: RichMarkdownOptions

    public init(
        allowsRawHTML: Bool = true,
        parsesFootnotes: Bool = true,
        validatesUTF8: Bool = true,
        usesGitHubCodeBlockLanguageClass: Bool = true,
        enabledExtensions: Set<GFMExtension> = Set(GFMExtension.allCases),
        renderProfile: MarkdownRenderProfile = .openMarked,
        richMarkdownOptions: RichMarkdownOptions = .default
    ) {
        self.allowsRawHTML = allowsRawHTML
        self.parsesFootnotes = parsesFootnotes
        self.validatesUTF8 = validatesUTF8
        self.usesGitHubCodeBlockLanguageClass = usesGitHubCodeBlockLanguageClass
        self.enabledExtensions = enabledExtensions
        self.renderProfile = renderProfile
        self.richMarkdownOptions = richMarkdownOptions
    }

    var cmarkOptions: Int32 {
        var options = Int32(CMARK_OPT_DEFAULT)

        if allowsRawHTML {
            options |= Int32(CMARK_OPT_UNSAFE)
        }

        if parsesFootnotes {
            options |= Int32(CMARK_OPT_FOOTNOTES)
        }

        if validatesUTF8 {
            options |= Int32(CMARK_OPT_VALIDATE_UTF8)
        }

        if usesGitHubCodeBlockLanguageClass {
            options |= Int32(CMARK_OPT_GITHUB_PRE_LANG)
        }

        return options
    }
}

public enum GFMExtension: String, CaseIterable, Sendable {
    case table
    case strikethrough
    case autolink
    case tagfilter
    case tasklist
}

public struct RenderResult: Equatable, Sendable {
    public let bodyHTML: String
    public let fullHTML: String
    public let outline: [OutlineItem]
    public let diagnostics: [RenderDiagnostic]
    public let statistics: DocumentStatistics
    public let rendererName: String
    public let rendererVersion: String?
    public let richMarkdownState: RichMarkdownRenderState
    public let htmlIndex: RenderedHTMLIndex?
    public let previewHTML: String?
    public let performanceProfile: DocumentPerformanceProfile?

    public init(
        bodyHTML: String,
        fullHTML: String,
        outline: [OutlineItem],
        diagnostics: [RenderDiagnostic],
        statistics: DocumentStatistics,
        rendererName: String,
        rendererVersion: String?,
        richMarkdownState: RichMarkdownRenderState = .empty,
        htmlIndex: RenderedHTMLIndex? = nil,
        previewHTML: String? = nil,
        performanceProfile: DocumentPerformanceProfile? = nil
    ) {
        self.bodyHTML = bodyHTML
        self.fullHTML = fullHTML
        self.outline = outline
        self.diagnostics = diagnostics
        self.statistics = statistics
        self.rendererName = rendererName
        self.rendererVersion = rendererVersion
        self.richMarkdownState = richMarkdownState
        self.htmlIndex = htmlIndex
        self.previewHTML = previewHTML
        self.performanceProfile = performanceProfile
    }

    public func withPreviewData(
        previewHTML: String,
        performanceProfile: DocumentPerformanceProfile
    ) -> RenderResult {
        RenderResult(
            bodyHTML: bodyHTML,
            fullHTML: fullHTML,
            outline: outline,
            diagnostics: diagnostics,
            statistics: statistics,
            rendererName: rendererName,
            rendererVersion: rendererVersion,
            richMarkdownState: richMarkdownState,
            htmlIndex: htmlIndex,
            previewHTML: previewHTML,
            performanceProfile: performanceProfile
        )
    }
}

public struct OutlineItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let level: Int
    public let title: String

    public init(id: String, level: Int, title: String) {
        self.id = id
        self.level = level
        self.title = title
    }
}

public enum OutlineDisplayMode: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case hierarchical
    case flat

    public var id: String {
        rawValue
    }
}

public struct OutlineDisplayOptions: Codable, Equatable, Sendable {
    public var mode: OutlineDisplayMode
    public var maximumVisibleLevel: Int
    public var showsAutoNumbers: Bool

    public init(
        mode: OutlineDisplayMode = .hierarchical,
        maximumVisibleLevel: Int = 6,
        showsAutoNumbers: Bool = false
    ) {
        self.mode = mode
        self.maximumVisibleLevel = maximumVisibleLevel
        self.showsAutoNumbers = showsAutoNumbers
    }

    public static let `default` = OutlineDisplayOptions()

    public func normalized() -> OutlineDisplayOptions {
        var options = self
        options.maximumVisibleLevel = min(6, max(1, maximumVisibleLevel))
        return options
    }
}

public struct OutlineDisplayItem: Equatable, Identifiable, Sendable {
    public let item: OutlineItem
    public let displayTitle: String
    public let indentationLevel: Int

    public var id: String {
        item.id
    }
}

public enum OutlineDisplayBuilder {
    public static func items(
        outline: [OutlineItem],
        query: String = "",
        options: OutlineDisplayOptions = .default
    ) -> [OutlineDisplayItem] {
        let normalizedOptions = options.normalized()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibleOutline = trimmedQuery.isEmpty
            ? outline.filter { $0.level <= normalizedOptions.maximumVisibleLevel }
            : OutlineFilter.filter(outline, query: trimmedQuery)
        let numberByID = normalizedOptions.showsAutoNumbers ? outlineNumbering(for: outline) : [:]

        return visibleOutline.map { item in
            let displayTitle: String
            if normalizedOptions.showsAutoNumbers, let number = numberByID[item.id] {
                displayTitle = "\(number) \(item.title)"
            } else {
                displayTitle = item.title
            }

            return OutlineDisplayItem(
                item: item,
                displayTitle: displayTitle,
                indentationLevel: indentationLevel(
                    for: item,
                    mode: normalizedOptions.mode,
                    isFiltering: !trimmedQuery.isEmpty
                )
            )
        }
    }

    private static func indentationLevel(
        for item: OutlineItem,
        mode: OutlineDisplayMode,
        isFiltering: Bool
    ) -> Int {
        guard mode == .hierarchical, !isFiltering else {
            return 0
        }

        return max(0, item.level - 1)
    }

    private static func outlineNumbering(for outline: [OutlineItem]) -> [String: String] {
        var counters = Array(repeating: 0, count: 6)
        var numbering: [String: String] = [:]

        for item in outline {
            let index = min(5, max(0, item.level - 1))
            counters[index] += 1
            if index + 1 < counters.count {
                for resetIndex in (index + 1)..<counters.count {
                    counters[resetIndex] = 0
                }
            }

            let visibleCounters = counters[0...index].filter { $0 > 0 }
            numbering[item.id] = visibleCounters.map(String.init).joined(separator: ".")
        }

        return numbering
    }
}

public enum OutlineFilter {
    public static func filter(_ outline: [OutlineItem], query: String) -> [OutlineItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return outline
        }

        return outline.filter { item in
            item.title.range(of: trimmedQuery, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

public enum RenderDiagnosticSeverity: String, Equatable, Sendable {
    case info
    case warning
    case error
}

public enum RenderDiagnosticKind: String, CaseIterable, Equatable, Sendable {
    case missingLocalImage
    case missingLocalLink
    case missingHeadingFragment
    case malformedLink
    case malformedFrontMatter
    case unsupportedLinkScheme
    case mermaidRenderFailure
    case mathRenderFailure
    case richContentDisabled
    case malformedGitHubCallout
    case linkValidationSkipped
    case unsupportedExtension
    case renderFailure
}

public struct RenderDiagnostic: Equatable, Identifiable, Sendable {
    public let id: String
    public let severity: RenderDiagnosticSeverity
    public let kind: RenderDiagnosticKind
    public let message: String
    public let source: String?

    public init(
        severity: RenderDiagnosticSeverity,
        kind: RenderDiagnosticKind,
        message: String,
        source: String? = nil
    ) {
        self.id = "\(kind.rawValue):\(source ?? message)"
        self.severity = severity
        self.kind = kind
        self.message = message
        self.source = source
    }
}

public enum RenderError: Error, Equatable, LocalizedError {
    case parserCreationFailed
    case parserFinishFailed
    case htmlRenderingFailed

    public var errorDescription: String? {
        switch self {
        case .parserCreationFailed:
            return "OpenMarked could not create a cmark-gfm parser."
        case .parserFinishFailed:
            return "OpenMarked could not finish parsing the Markdown document."
        case .htmlRenderingFailed:
            return "OpenMarked could not render the Markdown document to HTML."
        }
    }
}

public final class CMarkGFMRenderer: MarkdownRenderer {
    public init() {}

    public func render(_ request: RenderRequest) throws -> RenderResult {
        cmark_gfm_core_extensions_ensure_registered()
        let richMarkdownState = RichMarkdownRenderState(
            options: request.options.richMarkdownOptions,
            documentFeatures: RichMarkdownDocumentFeatures.detect(in: request.document)
        )

        guard let parser = cmark_parser_new(request.options.cmarkOptions) else {
            throw RenderError.parserCreationFailed
        }
        defer { cmark_parser_free(parser) }

        var diagnostics = request.document.frontMatterDiagnostics
        diagnostics.append(contentsOf: attachExtensions(to: parser, options: request.options))
        diagnostics.append(contentsOf: richMarkdownState.disabledFeatureDiagnostics)

        request.document.bodyText.withCString { pointer in
            cmark_parser_feed(parser, pointer, request.document.bodyText.utf8.count)
        }

        guard let root = cmark_parser_finish(parser) else {
            throw RenderError.parserFinishFailed
        }
        defer { cmark_node_free(root) }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let htmlPointer = cmark_render_html(root, request.options.cmarkOptions, extensions) else {
            throw RenderError.htmlRenderingFailed
        }
        defer { free(htmlPointer) }

        let renderedHTML = String(cString: htmlPointer)
        let processed = HeadingPostProcessor.process(
            renderedHTML,
            slugStyle: request.options.renderProfile.headingSlugStyle
        )
        let calloutProcessed = GitHubCalloutPostProcessor.process(
            processed.html,
            sourceMarkdown: request.document.bodyText,
            isEnabled: request.options.richMarkdownOptions.rendersGitHubCallouts
        )
        diagnostics.append(contentsOf: calloutProcessed.diagnostics)
        let mermaidProcessed = MermaidPostProcessor.process(
            calloutProcessed.html,
            isEnabled: request.options.richMarkdownOptions.rendersMermaid
        )
        diagnostics.append(contentsOf: mermaidProcessed.diagnostics)
        let mathProcessed = MathPostProcessor.process(
            mermaidProcessed.html,
            isEnabled: request.options.richMarkdownOptions.rendersMath
        )
        diagnostics.append(contentsOf: mathProcessed.diagnostics)
        let highlightedHTML = CodeHighlighter.highlight(mathProcessed.html)
        let policyHTML = request.allowsRemoteImages ? highlightedHTML : HTMLResourcePolicy.blockRemoteImages(in: highlightedHTML)
        let imageProcessedHTML = ImageAttributePostProcessor.process(policyHTML, document: request.document)
        let htmlIndex = RenderedHTMLIndex.build(from: imageProcessedHTML, document: request.document)
        diagnostics.append(
            contentsOf: RenderDiagnosticsCollector.collect(
                from: imageProcessedHTML,
                document: request.document,
                htmlIndex: htmlIndex,
                outline: processed.outline,
                options: request.options.richMarkdownOptions,
                renderProfile: request.options.renderProfile
            )
        )
        let fullHTML = HTMLDocumentAssembler.assemble(
            title: request.document.resolvedTitle,
            bodyHTML: imageProcessedHTML,
            baseURL: request.document.sourceURL.deletingLastPathComponent(),
            theme: request.theme,
            fontScale: request.fontScale,
            richMarkdownState: richMarkdownState
        )

        return RenderResult(
            bodyHTML: imageProcessedHTML,
            fullHTML: fullHTML,
            outline: processed.outline,
            diagnostics: diagnostics,
            statistics: request.document.statistics,
            rendererName: "cmark-gfm",
            rendererVersion: cmarkVersionString(),
            richMarkdownState: richMarkdownState,
            htmlIndex: htmlIndex
        )
    }

    private func attachExtensions(to parser: OpaquePointer, options: RenderOptions) -> [RenderDiagnostic] {
        var diagnostics: [RenderDiagnostic] = []

        for extensionName in options.enabledExtensions.map(\.rawValue).sorted() {
            guard let syntaxExtension = cmark_find_syntax_extension(extensionName) else {
                diagnostics.append(
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .unsupportedExtension,
                        message: "The cmark-gfm extension '\(extensionName)' was not available.",
                        source: extensionName
                    )
                )
                continue
            }

            guard cmark_parser_attach_syntax_extension(parser, syntaxExtension) != 0 else {
                diagnostics.append(
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .unsupportedExtension,
                        message: "The cmark-gfm extension '\(extensionName)' could not be attached.",
                        source: extensionName
                    )
                )
                continue
            }
        }

        return diagnostics
    }

    private func cmarkVersionString() -> String? {
        guard let versionPointer = cmark_version_string() else {
            return nil
        }

        return String(cString: versionPointer)
    }
}

public enum GitHubCalloutKind: String, CaseIterable, Sendable {
    case note
    case tip
    case important
    case warning
    case caution

    public init?(marker: String) {
        self.init(rawValue: marker.lowercased())
    }

    public var title: String {
        switch self {
        case .note:
            return "Note"
        case .tip:
            return "Tip"
        case .important:
            return "Important"
        case .warning:
            return "Warning"
        case .caution:
            return "Caution"
        }
    }

    public var marker: String {
        rawValue.uppercased()
    }
}

public enum GitHubCalloutPostProcessor {
    public struct Result: Equatable, Sendable {
        public let html: String
        public let diagnostics: [RenderDiagnostic]

        public init(html: String, diagnostics: [RenderDiagnostic] = []) {
            self.html = html
            self.diagnostics = diagnostics
        }
    }

    public static func process(_ html: String, sourceMarkdown: String, isEnabled: Bool = true) -> Result {
        guard isEnabled else {
            return Result(html: html)
        }

        var rendered = html
        let diagnostics = malformedMarkerDiagnostics(in: sourceMarkdown)
        let pattern = #"(?is)<blockquote([^>]*)>\s*(.*?)\s*</blockquote>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Result(html: html, diagnostics: diagnostics)
        }

        let matches = regex.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length))
        for match in matches.reversed() {
            guard
                let fullRange = Range(match.range(at: 0), in: html),
                let innerRange = Range(match.range(at: 2), in: html)
            else {
                continue
            }

            let innerHTML = String(html[innerRange])
            guard let calloutHTML = transformBlockquoteInnerHTML(innerHTML) else {
                continue
            }

            rendered.replaceSubrange(fullRange, with: calloutHTML)
        }

        return Result(html: rendered, diagnostics: diagnostics)
    }

    public static func malformedMarkerDiagnostics(in markdown: String) -> [RenderDiagnostic] {
        var diagnostics: [RenderDiagnostic] = []
        var seenSources = Set<String>()

        for line in markdown.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix(">") else {
                continue
            }

            let markerSource = trimmedLine
                .dropFirst()
                .trimmingCharacters(in: .whitespaces)

            guard markerSource.hasPrefix("[!") else {
                continue
            }

            let uppercasedMarker = markerSource.uppercased()
            if GitHubCalloutKind.allCases.contains(where: { uppercasedMarker.hasPrefix("[!\($0.marker)]") }) {
                continue
            }

            guard GitHubCalloutKind.allCases.contains(where: { uppercasedMarker.hasPrefix("[!\($0.marker)") }) else {
                continue
            }

            guard seenSources.insert(markerSource).inserted else {
                continue
            }

            diagnostics.append(
                RenderDiagnostic(
                    severity: .info,
                    kind: .malformedGitHubCallout,
                    message: "GitHub callout marker '\(markerSource)' is malformed and was left as a blockquote.",
                    source: markerSource
                )
            )
        }

        return diagnostics
    }

    private static func transformBlockquoteInnerHTML(_ innerHTML: String) -> String? {
        let markerPattern = #"(?is)^\s*<p>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*(.*?)</p>"#
        guard
            let markerRegex = try? NSRegularExpression(pattern: markerPattern),
            let match = markerRegex.firstMatch(in: innerHTML, range: NSRange(location: 0, length: (innerHTML as NSString).length)),
            let firstParagraphRange = Range(match.range(at: 0), in: innerHTML),
            let markerRange = Range(match.range(at: 1), in: innerHTML),
            let remainderRange = Range(match.range(at: 2), in: innerHTML),
            let kind = GitHubCalloutKind(marker: String(innerHTML[markerRange]))
        else {
            return nil
        }

        let firstParagraphRemainder = normalizedFirstParagraphRemainder(String(innerHTML[remainderRange]))
        let firstParagraphReplacement = firstParagraphRemainder.isEmpty ? "" : "<p>\(firstParagraphRemainder)</p>"
        var bodyHTML = innerHTML
        bodyHTML.replaceSubrange(firstParagraphRange, with: firstParagraphReplacement)
        bodyHTML = bodyHTML.trimmingCharacters(in: .whitespacesAndNewlines)

        let body = bodyHTML.isEmpty ? "" : "\n\(bodyHTML)\n  "
        return """
        <aside class="om-callout om-callout-\(kind.rawValue)" data-callout="\(kind.rawValue)">
          <p class="om-callout-title">\(kind.title)</p>
          <div class="om-callout-body">\(body)</div>
        </aside>
        """
    }

    private static func normalizedFirstParagraphRemainder(_ remainder: String) -> String {
        remainder
            .replacingOccurrences(
                of: #"(?is)^\s*(?:<br\s*/?>)?\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum HTMLDocumentAssembler {
    public static let themeCSSPlaceholder = "/* OpenMarked: theme CSS */"
    public static let codeHighlightingPlaceholder = "/* OpenMarked: code highlighting CSS */"

    public static func assemble(
        title: String,
        bodyHTML: String,
        baseURL: URL? = nil,
        theme: PreviewTheme = PreviewThemeStore.defaultTheme,
        fontScale: Double = 1.0,
        richMarkdownState: RichMarkdownRenderState = .empty,
        printConfiguration: PrintConfiguration = .default
    ) -> String {
        let escapedTitle = HTMLUtilities.escapeText(title)
        let baseElement: String
        if let baseURL {
            baseElement = #"<base href="\#(HTMLUtilities.escapeAttribute(baseURL.absoluteString))">"#
        } else {
            baseElement = ""
        }
        let boundedFontScale = min(2.0, max(0.6, fontScale))
        let maxWidth = max(560, theme.defaultMaxWidth)
        let richContentStyles = RichContentHTMLAssets.styleBlock(for: richMarkdownState)
        let normalizedPrintConfiguration = printConfiguration.normalized()
        let bodyClassAttribute = bodyClassAttribute(for: normalizedPrintConfiguration)
        let printDocumentTitleHTML = printDocumentTitleHTML(title: title, configuration: normalizedPrintConfiguration)
        let printDocumentTitleScreenCSS = printDocumentTitleScreenCSS(configuration: normalizedPrintConfiguration)
        let printCSS = printCSS(theme: theme, configuration: normalizedPrintConfiguration)

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          \(baseElement)
          <title>\(escapedTitle)</title>
          <style>
          :root {
            --om-font-scale: \(String(format: "%.3f", boundedFontScale));
            --om-content-max-width: \(maxWidth)px;
          }
          \(theme.screenCSS)
          \(theme.codeHighlightingCSS)
          \(printDocumentTitleScreenCSS)
          @media print {
          \(theme.printCSS)
          \(printCSS)
          }
          </style>\(richContentStyles)
        </head>
        <body\(bodyClassAttribute)>
          <main class="om-document">
        \(printDocumentTitleHTML)
        \(bodyHTML)
          </main>
        </body>
        </html>
        """
    }

    public static func printCSS(theme: PreviewTheme, configuration: PrintConfiguration) -> String {
        let normalized = configuration.normalized()
        guard normalized.requiresPrintStyleOverrides else {
            return ""
        }

        var cssParts: [String] = []

        if normalized.themeMode == .defaultPrint {
            cssParts.append(PreviewThemeStore.defaultTheme.printCSS)
        }

        if normalized.overridesPageSetup {
            cssParts.append(
                """
                @page {
                  size: \(normalized.pageSize.cssValue);
                  margin: \(normalized.margins.cssValue);
                }
                """
            )
        }

        if let contentMaxWidth = normalized.contentMaxWidth {
            cssParts.append(
                """
                body.om-print-limit-width .om-document {
                  max-width: min(\(contentMaxWidth)px, 100%);
                  margin-left: auto;
                  margin-right: auto;
                }
                """
            )
        }

        if normalized.includesDocumentTitle {
            cssParts.append(
                """
                body.om-print-include-title .om-print-document-title {
                  display: block;
                  margin: 0 0 1.4em;
                  padding: 0 0 0.5em;
                  border-bottom: 1pt solid currentColor;
                  font-size: 18pt;
                  font-weight: 700;
                  line-height: 1.25;
                }
                """
            )
        }

        if normalized.startsHeadingOneOnNewPage {
            cssParts.append(
                """
                body.om-print-break-h1 .om-document h1:not(:first-of-type) {
                  break-before: page;
                }
                """
            )
        }

        if normalized.startsHeadingTwoOnNewPage {
            cssParts.append(
                """
                body.om-print-break-h2 .om-document h2 {
                  break-before: page;
                }
                """
            )
        }

        return cssParts.joined(separator: "\n")
    }

    public static func printDocumentTitleScreenCSS(configuration: PrintConfiguration) -> String {
        guard configuration.normalized().includesDocumentTitle else {
            return ""
        }

        return """
        .om-print-document-title {
          display: none;
        }
        """
    }

    public static func bodyClassAttribute(for configuration: PrintConfiguration) -> String {
        let classes = configuration.normalized().bodyClasses
        guard !classes.isEmpty else {
            return ""
        }

        return #" class="\#(HTMLUtilities.escapeAttribute(classes.joined(separator: " ")))""#
    }

    public static func printDocumentTitleHTML(title: String, configuration: PrintConfiguration) -> String {
        guard configuration.normalized().includesDocumentTitle else {
            return ""
        }

        return #"<header class="om-print-document-title">\#(HTMLUtilities.escapeText(title))</header>"#
    }
}

public enum HeadingPostProcessor {
    public static func process(
        _ html: String,
        slugStyle: HeadingSlugStyle = .openMarked
    ) -> (html: String, outline: [OutlineItem]) {
        let pattern = #"<h([1-6])([^>]*)>(.*?)</h\1>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return (html, [])
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        guard !matches.isEmpty else {
            return (html, [])
        }

        var outline: [OutlineItem] = []
        var usedSlugs: [String: Int] = [:]
        var rendered = html
        var replacements: [(range: Range<String.Index>, replacement: String)] = []

        for match in matches {
            guard
                let fullRange = Range(match.range(at: 0), in: html),
                let levelRange = Range(match.range(at: 1), in: html),
                let attributesRange = Range(match.range(at: 2), in: html),
                let contentRange = Range(match.range(at: 3), in: html),
                let level = Int(html[levelRange])
            else {
                continue
            }

            let attributes = String(html[attributesRange])
            let content = String(html[contentRange])
            let title = HTMLUtilities.plainText(fromHTMLFragment: content)
            let existingHeadingID = existingID(in: attributes)
            let headingID = existingHeadingID ?? uniqueSlug(for: title, slugStyle: slugStyle, usedSlugs: &usedSlugs)
            let updatedAttributes = existingHeadingID == nil ? "\(attributes) id=\"\(HTMLUtilities.escapeAttribute(headingID))\"" : attributes
            let replacement = "<h\(level)\(updatedAttributes)>\(content)</h\(level)>"

            replacements.append((fullRange, replacement))
            outline.append(OutlineItem(id: headingID, level: level, title: title.isEmpty ? "Untitled Heading" : title))
        }

        for item in replacements.reversed() {
            rendered.replaceSubrange(item.range, with: item.replacement)
        }

        return (rendered, outline)
    }

    private static func existingID(in attributes: String) -> String? {
        let pattern = #"id\s*=\s*["']([^"']+)["']"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: attributes, range: NSRange(location: 0, length: (attributes as NSString).length)),
            let range = Range(match.range(at: 1), in: attributes)
        else {
            return nil
        }

        return String(attributes[range])
    }

    private static func uniqueSlug(
        for title: String,
        slugStyle: HeadingSlugStyle,
        usedSlugs: inout [String: Int]
    ) -> String {
        let base = slug(for: title, style: slugStyle)
        let priorCount = usedSlugs[base, default: 0]
        usedSlugs[base] = priorCount + 1

        if priorCount == 0 {
            return base
        }

        return "\(base)-\(priorCount)"
    }

    public static func slug(for title: String, style: HeadingSlugStyle = .openMarked) -> String {
        let decoded = HTMLUtilities.decodeEntities(in: HTMLUtilities.plainText(fromHTMLFragment: title))
        var scalars: [UnicodeScalar] = []
        var previousWasSeparator = false

        for scalar in decoded.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
                previousWasSeparator = false
            } else if scalar == "_" && style == .gitHub {
                scalars.append(scalar)
                previousWasSeparator = false
            } else if scalar == " " || scalar == "-" || scalar == "_" {
                if !previousWasSeparator, !scalars.isEmpty {
                    scalars.append("-")
                    previousWasSeparator = true
                }
            }
        }

        while scalars.last == "-" {
            scalars.removeLast()
        }

        let slug = String(String.UnicodeScalarView(scalars))
        return slug.isEmpty ? "heading" : slug
    }
}

public enum HTMLResourcePolicy {
    public static func blockRemoteImages(in html: String) -> String {
        var rendered = html
        for tag in HTMLTagScanner.tags(in: html, named: "img").reversed() {
            guard
                let sourceAttribute = tag.attribute(named: "src"),
                let valueRange = sourceAttribute.valueRange,
                sourceAttribute.value.lowercased().hasPrefix("http://")
                    || sourceAttribute.value.lowercased().hasPrefix("https://")
            else {
                continue
            }

            let originalSource = HTMLUtilities.escapeAttribute(sourceAttribute.value)
            let updatedTag = String(html[tag.range.lowerBound..<valueRange.lowerBound])
                + "about:blank"
                + String(html[valueRange.upperBound..<tag.range.upperBound])
            rendered.replaceSubrange(
                tag.range,
                with: HTMLTagRewriter.appending(
                    attributes: [#"data-openmarked-blocked-src="\#(originalSource)""#],
                    to: updatedTag
                )
            )
        }

        return rendered
    }
}

public enum RenderDiagnosticsCollector {
    public static func collect(
        from html: String,
        document: MarkdownDocument,
        htmlIndex: RenderedHTMLIndex? = nil,
        outline: [OutlineItem] = [],
        options: RichMarkdownOptions = .default,
        renderProfile: MarkdownRenderProfile = .openMarked
    ) -> [RenderDiagnostic] {
        let index = htmlIndex ?? RenderedHTMLIndex.build(from: html, document: document)
        return deduplicated(
            collectMissingLocalImages(from: index)
                + LinkValidator.diagnostics(
                    for: index.links,
                    document: document,
                    outline: outline,
                    options: options,
                    renderProfile: renderProfile
                )
        )
    }

    private static func collectMissingLocalImages(from htmlIndex: RenderedHTMLIndex) -> [RenderDiagnostic] {
        htmlIndex.localImageSources.compactMap { source, imageURL in
            guard !FileManager.default.fileExists(atPath: imageURL.path) else {
                return nil
            }

            return RenderDiagnostic(
                severity: .warning,
                kind: .missingLocalImage,
                message: "Local image '\(source)' could not be found.",
                source: source
            )
        }
    }

    private static func deduplicated(_ diagnostics: [RenderDiagnostic]) -> [RenderDiagnostic] {
        var seenIDs = Set<String>()
        return diagnostics.filter { diagnostic in
            seenIDs.insert(diagnostic.id).inserted
        }
    }
}

public enum LocalAssetReferenceExtractor {
    public static func imageURLs(from html: String, document: MarkdownDocument) -> [URL] {
        RenderedHTMLIndex.build(from: html, document: document).localImageURLs
    }

    public static func localImageSources(from html: String, document: MarkdownDocument) -> [(source: String, url: URL)] {
        RenderedHTMLIndex.build(from: html, document: document).localImageSources
    }

    public static func isLocalImagePath(_ source: String) -> Bool {
        guard !source.isEmpty else {
            return false
        }

        if source.hasPrefix("#") || source.hasPrefix("data:") {
            return false
        }

        if let components = URLComponents(string: source), components.scheme != nil {
            return components.scheme == "file"
        }

        return true
    }

    public static func localFileURL(for source: String, relativeTo baseURL: URL) -> URL? {
        if let components = URLComponents(string: source), let scheme = components.scheme {
            guard scheme == "file" else {
                return nil
            }
            return URL(string: source)?.standardizedFileURL
        }

        if let components = URLComponents(string: source), !components.path.isEmpty {
            let path = components.path.removingPercentEncoding ?? components.path
            return URL(fileURLWithPath: path, relativeTo: baseURL).standardizedFileURL
        }

        return URL(fileURLWithPath: source, relativeTo: baseURL).standardizedFileURL
    }
}

public enum HTMLUtilities {
    private static let numericEntityRegex = try? NSRegularExpression(pattern: #"(?i)&#(x[0-9a-f]+|[0-9]+);"#)

    public static func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    public static func escapeAttribute(_ text: String) -> String {
        escapeText(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    public static func plainText(fromHTMLFragment html: String) -> String {
        let withoutTags = html.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        return decodeEntities(in: withoutTags)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func decodeEntities(in text: String) -> String {
        let decoded = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        return decodeNumericEntities(in: decoded)
    }

    private static func decodeNumericEntities(in text: String) -> String {
        guard text.range(of: "&#") != nil, let regex = numericEntityRegex else {
            return text
        }

        var decoded = text
        let nsDecoded = decoded as NSString
        let range = NSRange(location: 0, length: nsDecoded.length)
        for match in regex.matches(in: decoded, range: range).reversed() {
            guard
                let fullRange = Range(match.range(at: 0), in: decoded),
                let valueRange = Range(match.range(at: 1), in: decoded)
            else {
                continue
            }

            let rawValue = String(decoded[valueRange])
            let isHex = rawValue.first == "x" || rawValue.first == "X"
            let digits = isHex ? String(rawValue.dropFirst()) : rawValue
            guard
                let value = UInt32(digits, radix: isHex ? 16 : 10),
                let scalar = UnicodeScalar(value)
            else {
                continue
            }

            decoded.replaceSubrange(fullRange, with: String(scalar))
        }
        return decoded
    }
}

public enum PreviewHTMLSecurityPolicy {
    private static let urlAttributeNames: Set<String> = ["action", "background", "cite", "data", "formaction", "href", "poster", "src", "srcset", "xlink:href"]

    private static let ignoredURLCharacters = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)

    public static func sanitize(_ html: String) -> String {
        guard !html.isEmpty else {
            return html
        }

        var mutations: [(range: Range<String.Index>, replacement: String)] = []
        var scriptRanges: [Range<String.Index>] = []

        for tag in HTMLTagScanner.tags(in: html) {
            if scriptRanges.contains(where: { $0.contains(tag.range.lowerBound) }) {
                continue
            }

            if tag.name == "script" {
                let range = scriptBlockRange(for: tag, in: html)
                scriptRanges.append(range)
                mutations.append((range, ""))
                continue
            }

            let unsafeAttributes = tag.attributes.filter { shouldRemove($0, tagName: tag.name) }
            guard !unsafeAttributes.isEmpty else {
                continue
            }

            mutations.append((tag.range, tagHTML(removing: unsafeAttributes, from: tag, in: html)))
        }

        guard !mutations.isEmpty else {
            return html
        }

        var sanitized = html
        for mutation in mutations.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            sanitized.replaceSubrange(mutation.range, with: mutation.replacement)
        }
        return sanitized
    }

    private static func scriptBlockRange(for tag: HTMLTagOccurrence, in html: String) -> Range<String.Index> {
        guard
            let closingStart = HTMLTagScanner.closingTagStart(named: "script", in: html, from: tag.range.upperBound),
            let closingEnd = html[closingStart...].firstIndex(of: ">")
        else {
            return tag.range
        }

        return tag.range.lowerBound..<html.index(after: closingEnd)
    }

    private static func shouldRemove(_ attribute: HTMLTagAttributeOccurrence, tagName: String) -> Bool {
        if attribute.lowercasedName.hasPrefix("on") {
            return true
        }

        guard urlAttributeNames.contains(attribute.lowercasedName) else {
            return false
        }

        return hasDangerousURL(attribute.value, attributeName: attribute.lowercasedName, tagName: tagName)
    }

    private static func hasDangerousURL(_ value: String, attributeName: String, tagName: String) -> Bool {
        let candidates = attributeName == "srcset" ? value.split(separator: ",").map(srcsetURLCandidate) : [value]
        return candidates.contains { candidate in
            let normalized = normalizedURLValue(candidate)
            guard !normalized.isEmpty, !normalized.hasPrefix("#") else {
                return false
            }

            if normalized.hasPrefix("data:") {
                return !isAllowedDataImageURL(normalized, attributeName: attributeName, tagName: tagName)
            }

            guard let colonIndex = normalized.firstIndex(of: ":") else {
                return false
            }

            let scheme = normalized[..<colonIndex]
            return scheme == "javascript" || scheme == "vbscript"
        }
    }

    private static func normalizedURLValue(_ value: String) -> String {
        let value = value
            .replacingOccurrences(of: "&Tab;", with: "\t", options: .caseInsensitive)
            .replacingOccurrences(of: "&NewLine;", with: "\n", options: .caseInsensitive)
        var normalized = ""
        normalized.reserveCapacity(value.count)

        for scalar in value.unicodeScalars where !ignoredURLCharacters.contains(scalar) {
            normalized.append(String(scalar))
        }

        return normalized.lowercased()
    }

    private static func isAllowedDataImageURL(
        _ normalized: String,
        attributeName: String,
        tagName: String
    ) -> Bool {
        let isImageSourceAttribute = attributeName == "src" || attributeName == "srcset"
        return isImageSourceAttribute && (tagName == "img" || tagName == "source") && normalized.hasPrefix("data:image/")
    }

    private static func srcsetURLCandidate(from candidate: Substring) -> String {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstWhitespace = trimmed.firstIndex(where: \.isWhitespace) else {
            return trimmed
        }
        return String(trimmed[..<firstWhitespace])
    }

    private static func tagHTML(
        removing attributes: [HTMLTagAttributeOccurrence],
        from tag: HTMLTagOccurrence,
        in html: String
    ) -> String {
        let attributes = attributes.sorted { $0.range.lowerBound < $1.range.lowerBound }
        var updatedTag = ""
        updatedTag.reserveCapacity(html[tag.range].count)
        var cursor = tag.range.lowerBound

        for attribute in attributes {
            updatedTag.append(contentsOf: html[cursor..<attribute.range.lowerBound])
            cursor = attribute.range.upperBound
        }

        updatedTag.append(contentsOf: html[cursor..<tag.range.upperBound])
        return updatedTag
    }
}
