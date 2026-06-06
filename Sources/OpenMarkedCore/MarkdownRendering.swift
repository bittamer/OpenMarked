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

    public init(
        bodyHTML: String,
        fullHTML: String,
        outline: [OutlineItem],
        diagnostics: [RenderDiagnostic],
        statistics: DocumentStatistics,
        rendererName: String,
        rendererVersion: String?,
        richMarkdownState: RichMarkdownRenderState = .empty
    ) {
        self.bodyHTML = bodyHTML
        self.fullHTML = fullHTML
        self.outline = outline
        self.diagnostics = diagnostics
        self.statistics = statistics
        self.rendererName = rendererName
        self.rendererVersion = rendererVersion
        self.richMarkdownState = richMarkdownState
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
        let numberByID = outlineNumbering(for: outline)
        let filteredOutline = OutlineFilter.filter(outline, query: query)
        let visibleOutline = trimmedQuery.isEmpty
            ? filteredOutline.filter { $0.level <= normalizedOptions.maximumVisibleLevel }
            : filteredOutline

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
        diagnostics.append(
            contentsOf: RenderDiagnosticsCollector.collect(
                from: policyHTML,
                document: request.document,
                outline: processed.outline,
                options: request.options.richMarkdownOptions,
                renderProfile: request.options.renderProfile
            )
        )
        let fullHTML = HTMLDocumentAssembler.assemble(
            title: request.document.resolvedTitle,
            bodyHTML: policyHTML,
            baseURL: request.document.sourceURL.deletingLastPathComponent(),
            theme: request.theme,
            fontScale: request.fontScale,
            richMarkdownState: richMarkdownState
        )

        return RenderResult(
            bodyHTML: policyHTML,
            fullHTML: fullHTML,
            outline: processed.outline,
            diagnostics: diagnostics,
            statistics: request.document.statistics,
            rendererName: "cmark-gfm",
            rendererVersion: cmarkVersionString(),
            richMarkdownState: richMarkdownState
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
        richMarkdownState: RichMarkdownRenderState = .empty
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
          @media print {
          \(theme.printCSS)
          }
          </style>\(richContentStyles)
        </head>
        <body>
          <main class="om-document">
        \(bodyHTML)
          </main>
        </body>
        </html>
        """
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
        let pattern = #"(?i)(<img\b[^>]*\bsrc\s*=\s*)(["'])(https?://[^"']+)(["'])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return html
        }

        var rendered = html
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: (html as NSString).length))
        for match in matches.reversed() {
            guard
                let fullRange = Range(match.range(at: 0), in: html),
                let prefixRange = Range(match.range(at: 1), in: html),
                let quoteRange = Range(match.range(at: 2), in: html),
                let sourceRange = Range(match.range(at: 3), in: html)
            else {
                continue
            }

            let source = String(html[sourceRange])
            let quote = String(html[quoteRange])
            let replacement = "\(html[prefixRange])\(quote)about:blank\(quote) data-openmarked-blocked-src=\(quote)\(HTMLUtilities.escapeAttribute(source))\(quote)"
            rendered.replaceSubrange(fullRange, with: replacement)
        }

        return rendered
    }
}

public enum RenderDiagnosticsCollector {
    public static func collect(
        from html: String,
        document: MarkdownDocument,
        outline: [OutlineItem] = [],
        options: RichMarkdownOptions = .default,
        renderProfile: MarkdownRenderProfile = .openMarked
    ) -> [RenderDiagnostic] {
        deduplicated(
            collectMissingLocalImages(from: html, document: document)
                + LinkValidator.diagnostics(
                    from: html,
                    document: document,
                    outline: outline,
                    options: options,
                    renderProfile: renderProfile
                )
        )
    }

    private static func collectMissingLocalImages(from html: String, document: MarkdownDocument) -> [RenderDiagnostic] {
        let imageURLsBySource = LocalAssetReferenceExtractor.localImageSources(from: html, document: document)
        return imageURLsBySource.compactMap { source, imageURL in
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
        let urls = localImageSources(from: html, document: document).map(\.url)
        var seen = Set<String>()
        return urls.filter { url in
            let key = url.standardizedFileURL.path
            guard !seen.contains(key) else {
                return false
            }
            seen.insert(key)
            return true
        }
    }

    public static func localImageSources(from html: String, document: MarkdownDocument) -> [(source: String, url: URL)] {
        let pattern = #"<img\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsHTML = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)).compactMap { match in
            guard
                let range = Range(match.range(at: 1), in: html)
            else {
                return nil
            }

            let source = HTMLUtilities.decodeEntities(in: String(html[range]))
            guard isLocalImagePath(source) else {
                return nil
            }

            guard let imageURL = localFileURL(for: source, relativeTo: document.sourceURL.deletingLastPathComponent()) else {
                return nil
            }

            return (source, imageURL)
        }
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
        var decoded = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")

        let numericPattern = #"&#([0-9]+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let nsDecoded = decoded as NSString
            for match in regex.matches(in: decoded, range: NSRange(location: 0, length: nsDecoded.length)).reversed() {
                guard
                    let fullRange = Range(match.range(at: 0), in: decoded),
                    let valueRange = Range(match.range(at: 1), in: decoded),
                    let value = UInt32(decoded[valueRange]),
                    let scalar = UnicodeScalar(value)
                else {
                    continue
                }
                decoded.replaceSubrange(fullRange, with: String(scalar))
            }
        }

        return decoded
    }
}

public enum PreviewHTMLSecurityPolicy {
    public static func sanitize(_ html: String) -> String {
        html
            .replacingOccurrences(
                of: #"(?is)<script\b[^>]*>.*?</script>"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\s+on[a-z]+\s*=\s*"[^"]*""#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"(?i)\s+on[a-z]+\s*=\s*'[^']*'"#,
                with: "",
                options: .regularExpression
            )
    }
}
