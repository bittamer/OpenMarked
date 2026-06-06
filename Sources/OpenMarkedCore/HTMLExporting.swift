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

    public init(
        embedsLocalImages: Bool = true,
        embedsThemeCSS: Bool = true,
        embedsRichContentRuntime: Bool = true
    ) {
        self.embedsLocalImages = embedsLocalImages
        self.embedsThemeCSS = embedsThemeCSS
        self.embedsRichContentRuntime = embedsRichContentRuntime
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

        if !options.embedsThemeCSS {
            html = stripEmbeddedStyles(from: html)
        }

        if options.embedsRichContentRuntime {
            html = embedTrustedRichContentRuntime(in: html, state: renderResult.richMarkdownState)
        }

        return html
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
        let pattern = #"(?i)(<img\b[^>]*\bsrc\s*=\s*)(["'])([^"']+)(["'])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return html
        }

        var exportedHTML = html
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

            let source = HTMLUtilities.decodeEntities(in: String(html[sourceRange]))
            guard
                let imageURL = LocalAssetReferenceExtractor.localFileURL(
                    for: source,
                    relativeTo: document.sourceURL.deletingLastPathComponent()
                ),
                FileManager.default.fileExists(atPath: imageURL.path),
                let data = try? Data(contentsOf: imageURL)
            else {
                continue
            }

            let dataURL = "data:\(mimeType(for: imageURL));base64,\(data.base64EncodedString())"
            let replacement = "\(html[prefixRange])\(html[quoteRange])\(HTMLUtilities.escapeAttribute(dataURL))\(html[quoteRange])"
            exportedHTML.replaceSubrange(fullRange, with: replacement)
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
