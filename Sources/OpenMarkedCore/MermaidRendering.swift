import Foundation

public enum MermaidPostProcessor {
    public struct Result: Equatable, Sendable {
        public let html: String
        public let diagnostics: [RenderDiagnostic]
        public let diagramCount: Int

        public init(html: String, diagnostics: [RenderDiagnostic] = [], diagramCount: Int = 0) {
            self.html = html
            self.diagnostics = diagnostics
            self.diagramCount = diagramCount
        }
    }

    public static func process(_ html: String, isEnabled: Bool = true) -> Result {
        guard isEnabled else {
            return Result(html: html)
        }

        let blocks = HTMLCodeBlockScanner.blocks(in: html)
        guard !blocks.isEmpty else {
            return Result(html: html)
        }

        var replacements: [(range: Range<String.Index>, html: String)] = []
        var diagnostics: [RenderDiagnostic] = []
        var diagramCount = 0

        for block in blocks {
            guard isMermaidLanguage(block.language) else {
                continue
            }

            diagramCount += 1
            let diagramID = "om-mermaid-\(diagramCount)"
            let source = HTMLUtilities.decodeEntities(in: block.codeHTML)
            let replacement = placeholderHTML(id: diagramID, index: diagramCount, source: source)
            diagnostics.append(contentsOf: preflightDiagnostics(for: source, diagramID: diagramID))
            replacements.append((block.range, replacement))
        }

        var rendered = html
        for replacement in replacements.reversed() {
            rendered.replaceSubrange(replacement.range, with: replacement.html)
        }

        return Result(html: rendered, diagnostics: diagnostics, diagramCount: diagramCount)
    }

    private static func placeholderHTML(id: String, index: Int, source: String) -> String {
        let escapedID = HTMLUtilities.escapeAttribute(id)
        let label = "Mermaid diagram \(index)"
        let escapedLabel = HTMLUtilities.escapeAttribute(label)
        let escapedSource = HTMLUtilities.escapeText(source)

        return """
        <figure class="om-mermaid" data-openmarked-rich="mermaid" id="\(escapedID)">
          <figcaption class="om-rich-content-status">\(HTMLUtilities.escapeText(label))</figcaption>
          <pre class="om-mermaid-source"><code>\(escapedSource)</code></pre>
          <div class="om-mermaid-output" role="img" aria-label="\(escapedLabel)" aria-live="polite"></div>
        </figure>
        """
    }

    private static func preflightDiagnostics(for source: String, diagramID: String) -> [RenderDiagnostic] {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return [
                RenderDiagnostic(
                    severity: .warning,
                    kind: .mermaidRenderFailure,
                    message: "Mermaid diagram \(diagramID) is empty.",
                    source: diagramID
                )
            ]
        }

        let lines = trimmedSource.split(whereSeparator: \.isNewline).map(String.init)
        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if lineEndsWithDanglingConnector(trimmedLine) {
                return [
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .mermaidRenderFailure,
                        message: "Mermaid diagram \(diagramID) may be incomplete near line \(index + 1).",
                        source: diagramID
                    )
                ]
            }
        }

        return []
    }

    private static func lineEndsWithDanglingConnector(_ line: String) -> Bool {
        line.range(
            of: #"(?:(?:--|==|-\.)(?:[ox>])?|(?:-->|==>|-\.->))\s*$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isMermaidLanguage(_ language: String?) -> Bool {
        guard let language else {
            return false
        }
        return language.lowercased() == "mermaid" || language.lowercased() == "mmd"
    }

}
