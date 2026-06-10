import Foundation

public enum ExportError: Error, Equatable, LocalizedError, Sendable {
    case missingRenderedDocument
    case writeFailed(path: String, reason: String)
    case pdfFailed(path: String, reason: String)
    case printFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .missingRenderedDocument:
            return "OpenMarked does not have a rendered document to export."
        case .writeFailed(let path, let reason):
            return "OpenMarked could not write \(path). \(reason)"
        case .pdfFailed(let path, let reason):
            return "OpenMarked could not export \(path) as PDF. \(reason)"
        case .printFailed(let reason):
            return "OpenMarked could not print this document. \(reason)"
        }
    }
}

public struct HTMLExportOptions: Equatable, Sendable {
    public var embedsLocalImages: Bool
    public var embedsThemeCSS: Bool
    public var embedsRichContentRuntime: Bool
    public var printConfiguration: PrintConfiguration

    public init(
        embedsLocalImages: Bool = true,
        embedsThemeCSS: Bool = true,
        embedsRichContentRuntime: Bool = true,
        printConfiguration: PrintConfiguration = .default
    ) {
        self.embedsLocalImages = embedsLocalImages
        self.embedsThemeCSS = embedsThemeCSS
        self.embedsRichContentRuntime = embedsRichContentRuntime
        self.printConfiguration = printConfiguration
    }
}

public enum HTMLExportDocumentBuilder {
    public static func standaloneHTML(
        renderResult: RenderResult,
        document: MarkdownDocument,
        options: HTMLExportOptions = HTMLExportOptions()
    ) -> String {
        var html = retitle(
            PreviewHTMLSecurityPolicy.sanitize(renderResult.fullHTML),
            title: document.resolvedTitle
        )

        if options.embedsLocalImages {
            html = embedLocalImages(in: html, document: document)
        }

        if options.embedsThemeCSS {
            html = applyPrintConfiguration(
                to: html,
                title: document.resolvedTitle,
                configuration: options.printConfiguration
            )
        } else {
            html = stripEmbeddedStyles(from: html)
        }

        if options.embedsRichContentRuntime {
            html = embedTrustedRichContentRuntime(in: html, state: renderResult.richMarkdownState)
        }

        return html
    }

    private static func applyPrintConfiguration(
        to html: String,
        title: String,
        configuration: PrintConfiguration
    ) -> String {
        let normalized = configuration.normalized()
        guard normalized.requiresPrintStyleOverrides else {
            return html
        }

        var updatedHTML = html
        updatedHTML = addBodyClasses(normalized.bodyClasses, to: updatedHTML)
        updatedHTML = insertPrintTitleIfNeeded(into: updatedHTML, title: title, configuration: normalized)

        let css = HTMLDocumentAssembler.printCSS(theme: PreviewThemeStore.defaultTheme, configuration: normalized)
        if !css.isEmpty {
            updatedHTML = insertStyleBlock(
                """
                <style data-openmarked-print-configuration>
                \(HTMLDocumentAssembler.printDocumentTitleScreenCSS(configuration: normalized))
                @media print {
                \(css)
                }
                </style>
                """,
                into: updatedHTML
            )
        }

        return updatedHTML
    }

    private static func addBodyClasses(_ classes: [String], to html: String) -> String {
        guard !classes.isEmpty,
              let regex = try? NSRegularExpression(pattern: #"(?is)<body\b([^>]*)>"#),
              let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: (html as NSString).length)),
              let fullRange = Range(match.range(at: 0), in: html),
              let attributeRange = Range(match.range(at: 1), in: html)
        else {
            return html
        }

        var attributes = String(html[attributeRange])
        let classValue = classes.joined(separator: " ")
        if let classRange = attributes.range(
            of: #"(?is)\bclass\s*=\s*(["'])(.*?)\1"#,
            options: .regularExpression
        ) {
            let classAttribute = String(attributes[classRange])
            if let valueRange = classAttribute.range(
                of: #"(?is)(["'])(.*?)\1"#,
                options: .regularExpression
            ) {
                let quotedValue = String(classAttribute[valueRange])
                let quote = quotedValue.first.map(String.init) ?? #"""#
                let existingClasses = quotedValue.dropFirst().dropLast()
                let replacement = "\(quote)\(existingClasses) \(classValue)\(quote)"
                let updatedClassAttribute = classAttribute.replacingOccurrences(of: quotedValue, with: replacement)
                attributes.replaceSubrange(classRange, with: updatedClassAttribute)
            }
        } else {
            attributes += #" class="\#(HTMLUtilities.escapeAttribute(classValue))""#
        }

        var updatedHTML = html
        updatedHTML.replaceSubrange(fullRange, with: "<body\(attributes)>")
        return updatedHTML
    }

    private static func insertPrintTitleIfNeeded(
        into html: String,
        title: String,
        configuration: PrintConfiguration
    ) -> String {
        guard configuration.normalized().includesDocumentTitle,
              !html.contains("om-print-document-title")
        else {
            return html
        }

        let titleHTML = HTMLDocumentAssembler.printDocumentTitleHTML(title: title, configuration: configuration)
        if let mainRange = html.range(of: #"(?is)<main\b[^>]*>"#, options: .regularExpression) {
            var updatedHTML = html
            updatedHTML.insert(contentsOf: "\n\(titleHTML)", at: mainRange.upperBound)
            return updatedHTML
        }

        if let bodyRange = html.range(of: #"(?is)<body\b[^>]*>"#, options: .regularExpression) {
            var updatedHTML = html
            updatedHTML.insert(contentsOf: "\n\(titleHTML)", at: bodyRange.upperBound)
            return updatedHTML
        }

        return html
    }

    private static func insertStyleBlock(_ styleBlock: String, into html: String) -> String {
        if let headCloseRange = html.range(of: "</head>", options: [.caseInsensitive, .backwards]) {
            var updatedHTML = html
            updatedHTML.insert(contentsOf: "\n\(styleBlock)", at: headCloseRange.lowerBound)
            return updatedHTML
        }

        return "\(styleBlock)\n\(html)"
    }

    private static func retitle(_ html: String, title: String) -> String {
        let escapedTitle = HTMLUtilities.escapeText(title)
        if let titleRange = html.range(of: #"(?is)<title>.*?</title>"#, options: .regularExpression) {
            var updatedHTML = html
            updatedHTML.replaceSubrange(titleRange, with: "<title>\(escapedTitle)</title>")
            return updatedHTML
        }
        return html
    }

    private static func embedTrustedRichContentRuntime(in html: String, state: RichMarkdownRenderState) -> String {
        guard state.requiresRichContentRuntime,
              let scripts = try? RichContentRuntimeAssembler.runtimeScripts(for: state),
              !scripts.isEmpty
        else {
            return html
        }

        let runtimeScript = (scripts + [exportInvocationScript(for: state)])
            .joined(separator: "\n")
            .replacingOccurrences(of: "</script", with: "<\\/script", options: [.caseInsensitive])
        let scriptBlock = """

        <script data-openmarked-rich-content-runtime>
        \(runtimeScript)
        </script>
        """

        if let bodyCloseRange = html.range(of: "</body>", options: [.caseInsensitive, .backwards]) {
            var exportedHTML = html
            exportedHTML.insert(contentsOf: scriptBlock, at: bodyCloseRange.lowerBound)
            return exportedHTML
        }

        return html + scriptBlock
    }

    private static func exportInvocationScript(for state: RichMarkdownRenderState) -> String {
        let invocationScript = RichContentRuntimeAssembler.invocationScript(for: state)
        return """
        (function() {
          function runOpenMarkedRichContent() {
            window.openMarkedPrefersReducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
            \(invocationScript)
          }

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', runOpenMarkedRichContent, { once: true });
          } else {
            runOpenMarkedRichContent();
          }
        })();
        """
    }

    private static func stripEmbeddedStyles(from html: String) -> String {
        html.replacingOccurrences(
            of: #"(?is)\s*<style\b[^>]*>.*?</style>"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func embedLocalImages(in html: String, document: MarkdownDocument) -> String {
        var exportedHTML = html
        let imageTags = HTMLTagScanner.tags(in: html, named: "img")
        for tag in imageTags.reversed() {
            guard
                let sourceAttribute = tag.attribute(named: "src"),
                let valueRange = sourceAttribute.valueRange
            else {
                continue
            }

            guard
                let imageURL = LocalAssetReferenceExtractor.localFileURL(
                    for: sourceAttribute.value,
                    relativeTo: document.sourceURL.deletingLastPathComponent()
                ),
                FileManager.default.fileExists(atPath: imageURL.path),
                let data = try? Data(contentsOf: imageURL)
            else {
                continue
            }

            let dataURL = "data:\(mimeType(for: imageURL));base64,\(data.base64EncodedString())"
            exportedHTML.replaceSubrange(valueRange, with: HTMLUtilities.escapeAttribute(dataURL))
        }

        return exportedHTML
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "apng":
            return "image/apng"
        case "avif":
            return "image/avif"
        case "gif":
            return "image/gif"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "svg":
            return "image/svg+xml"
        case "webp":
            return "image/webp"
        default:
            return "application/octet-stream"
        }
    }
}

public enum HTMLExportWriter {
    public static func write(
        html: String,
        to destinationURL: URL,
        encoding: String.Encoding = .utf8
    ) throws {
        do {
            try html.write(to: destinationURL, atomically: true, encoding: encoding)
        } catch {
            throw ExportError.writeFailed(path: destinationURL.path, reason: error.localizedDescription)
        }
    }
}
