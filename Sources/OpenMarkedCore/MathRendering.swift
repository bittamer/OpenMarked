import Foundation

public enum MathDelimiterRules {
    public static func containsMath(in markdown: String) -> Bool {
        let searchableMarkdown = markdownRemovingSkippedSourceRanges(markdown)
        return containsDisplayMath(in: searchableMarkdown) || containsInlineMath(in: searchableMarkdown)
    }

    private static func markdownRemovingSkippedSourceRanges(_ markdown: String) -> String {
        var lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var insideFence = false

        for index in lines.indices {
            let trimmedLine = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~") {
                insideFence.toggle()
                lines[index] = ""
                continue
            }

            if insideFence {
                lines[index] = ""
            }
        }

        var markdown = lines.joined(separator: "\n")
        markdown = markdown.replacingOccurrences(of: #"`[^`]*`"#, with: "", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: #"!?\[[^\]]*\]\([^)]*\)"#, with: "", options: .regularExpression)
        return markdown
    }

    private static func containsDisplayMath(in text: String) -> Bool {
        var index = text.startIndex
        while index < text.endIndex {
            guard isDisplayDelimiter(at: index, in: text) else {
                index = text.index(after: index)
                continue
            }

            let contentStart = text.index(index, offsetBy: 2)
            if findDisplayClose(from: contentStart, in: text) != nil {
                return true
            }

            index = contentStart
        }

        return false
    }

    private static func containsInlineMath(in text: String) -> Bool {
        var index = text.startIndex
        while index < text.endIndex {
            guard isInlineOpeningDelimiter(at: index, in: text) else {
                index = text.index(after: index)
                continue
            }

            let contentStart = text.index(after: index)
            if findInlineClose(from: contentStart, in: text) != nil {
                return true
            }

            index = contentStart
        }

        return false
    }

    fileprivate static func findDisplayClose(from start: String.Index, in text: String) -> String.Index? {
        var index = start
        while index < text.endIndex {
            if isDisplayDelimiter(at: index, in: text), !isEscaped(at: index, in: text) {
                return index
            }
            index = text.index(after: index)
        }
        return nil
    }

    fileprivate static func findInlineClose(from start: String.Index, in text: String) -> String.Index? {
        var index = start
        while index < text.endIndex {
            guard text[index] == "$" else {
                index = text.index(after: index)
                continue
            }

            if isInlineClosingDelimiter(at: index, in: text) {
                return index
            }

            index = text.index(after: index)
        }
        return nil
    }

    fileprivate static func isDisplayDelimiter(at index: String.Index, in text: String) -> Bool {
        guard text[index] == "$" else {
            return false
        }

        let nextIndex = text.index(after: index)
        return nextIndex < text.endIndex && text[nextIndex] == "$" && !isEscaped(at: index, in: text)
    }

    fileprivate static func isInlineOpeningDelimiter(at index: String.Index, in text: String) -> Bool {
        guard text[index] == "$", !isEscaped(at: index, in: text) else {
            return false
        }

        let nextIndex = text.index(after: index)
        guard nextIndex < text.endIndex, text[nextIndex] != "$" else {
            return false
        }

        let nextCharacter = text[nextIndex]
        return !nextCharacter.isWhitespace && !nextCharacter.isNumber
    }

    fileprivate static func isInlineClosingDelimiter(at index: String.Index, in text: String) -> Bool {
        guard text[index] == "$", !isEscaped(at: index, in: text) else {
            return false
        }

        let previousIndex = text.index(before: index)
        guard text[previousIndex] != "$", !text[previousIndex].isWhitespace else {
            return false
        }

        let nextIndex = text.index(after: index)
        if nextIndex < text.endIndex {
            let nextCharacter = text[nextIndex]
            if nextCharacter.isLetter || nextCharacter.isNumber {
                return false
            }
        }

        return true
    }

    fileprivate static func isEscaped(at index: String.Index, in text: String) -> Bool {
        guard index > text.startIndex else {
            return false
        }

        var slashCount = 0
        var cursor = text.index(before: index)
        while text[cursor] == "\\" {
            slashCount += 1
            guard cursor > text.startIndex else {
                break
            }
            cursor = text.index(before: cursor)
        }

        return slashCount % 2 == 1
    }
}

public enum MathPostProcessor {
    public struct Result: Equatable, Sendable {
        public let html: String
        public let diagnostics: [RenderDiagnostic]
        public let expressionCount: Int

        public init(html: String, diagnostics: [RenderDiagnostic] = [], expressionCount: Int = 0) {
            self.html = html
            self.diagnostics = diagnostics
            self.expressionCount = expressionCount
        }
    }

    private enum SegmentKind {
        case tag
        case text
    }

    private struct Segment {
        let kind: SegmentKind
        let text: String
    }

    private struct ProcessedText {
        let html: String
        let diagnostics: [RenderDiagnostic]
        let expressionCount: Int
    }

    public static func process(_ html: String, isEnabled: Bool = true) -> Result {
        guard isEnabled else {
            return Result(html: html)
        }

        var rendered = ""
        var diagnostics: [RenderDiagnostic] = []
        var expressionCount = 0
        var skipStack: [Bool] = []

        for segment in segments(in: html) {
            switch segment.kind {
            case .tag:
                rendered += segment.text
                updateSkipStack(with: segment.text, skipStack: &skipStack)
            case .text:
                guard !skipStack.contains(true) else {
                    rendered += segment.text
                    continue
                }

                let processed = processTextSegment(segment.text, startingExpressionCount: expressionCount)
                rendered += processed.html
                diagnostics.append(contentsOf: processed.diagnostics)
                expressionCount = processed.expressionCount
            }
        }

        return Result(html: rendered, diagnostics: diagnostics, expressionCount: expressionCount)
    }

    private static func processTextSegment(_ text: String, startingExpressionCount: Int) -> ProcessedText {
        var rendered = ""
        var diagnostics: [RenderDiagnostic] = []
        var expressionCount = startingExpressionCount
        var index = text.startIndex

        while index < text.endIndex {
            if MathDelimiterRules.isDisplayDelimiter(at: index, in: text) {
                let contentStart = text.index(index, offsetBy: 2)
                if let closeIndex = MathDelimiterRules.findDisplayClose(from: contentStart, in: text) {
                    expressionCount += 1
                    let source = HTMLUtilities.decodeEntities(in: String(text[contentStart..<closeIndex]))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    rendered += placeholderHTML(id: "om-math-\(expressionCount)", index: expressionCount, source: source, isDisplay: true)
                    diagnostics.append(contentsOf: preflightDiagnostics(for: source, expressionID: "om-math-\(expressionCount)"))
                    index = text.index(closeIndex, offsetBy: 2)
                    continue
                }
            }

            if MathDelimiterRules.isInlineOpeningDelimiter(at: index, in: text) {
                let contentStart = text.index(after: index)
                if let closeIndex = MathDelimiterRules.findInlineClose(from: contentStart, in: text) {
                    expressionCount += 1
                    let source = HTMLUtilities.decodeEntities(in: String(text[contentStart..<closeIndex]))
                    rendered += placeholderHTML(id: "om-math-\(expressionCount)", index: expressionCount, source: source, isDisplay: false)
                    diagnostics.append(contentsOf: preflightDiagnostics(for: source, expressionID: "om-math-\(expressionCount)"))
                    index = text.index(after: closeIndex)
                    continue
                }
            }

            rendered.append(text[index])
            index = text.index(after: index)
        }

        return ProcessedText(html: rendered, diagnostics: diagnostics, expressionCount: expressionCount)
    }

    private static func placeholderHTML(id: String, index: Int, source: String, isDisplay: Bool) -> String {
        let escapedID = HTMLUtilities.escapeAttribute(id)
        let escapedSource = HTMLUtilities.escapeText(source)
        let escapedAttributeSource = HTMLUtilities.escapeAttribute(source)
        let label = isDisplay ? "Math equation \(index)" : "Inline math expression \(index)"
        let escapedLabel = HTMLUtilities.escapeAttribute(label)
        let className = isDisplay ? "om-math-display" : "om-math-inline"

        if !isDisplay {
            return #"<span class="\#(className)" data-openmarked-rich="math" data-openmarked-math-display="false" data-openmarked-math-source="\#(escapedAttributeSource)" id="\#(escapedID)"><span class="om-rich-content-status">\#(HTMLUtilities.escapeText(label))</span><span class="om-math-source">\#(escapedSource)</span><span class="om-math-output" aria-label="\#(escapedLabel)" aria-live="polite"></span></span>"#
        }

        return """
        <span class="\(className)" data-openmarked-rich="math" data-openmarked-math-display="\(isDisplay ? "true" : "false")" data-openmarked-math-source="\(escapedAttributeSource)" id="\(escapedID)">
          <span class="om-rich-content-status">\(HTMLUtilities.escapeText(label))</span>
          <span class="om-math-source">\(escapedSource)</span>
          <span class="om-math-output" aria-label="\(escapedLabel)" aria-live="polite"></span>
        </span>
        """
    }

    private static func preflightDiagnostics(for source: String, expressionID: String) -> [RenderDiagnostic] {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return [
                RenderDiagnostic(
                    severity: .warning,
                    kind: .mathRenderFailure,
                    message: "Math expression \(expressionID) is empty.",
                    source: expressionID
                )
            ]
        }

        guard bracesAreBalanced(in: source) else {
            return [
                RenderDiagnostic(
                    severity: .warning,
                    kind: .mathRenderFailure,
                    message: "Math expression \(expressionID) has unbalanced braces.",
                    source: expressionID
                )
            ]
        }

        return []
    }

    private static func bracesAreBalanced(in source: String) -> Bool {
        var depth = 0
        var previousCharacter: Character?

        for character in source {
            defer { previousCharacter = character }

            guard previousCharacter != "\\" else {
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth < 0 {
                    return false
                }
            }
        }

        return depth == 0
    }

    private static func segments(in html: String) -> [Segment] {
        var segments: [Segment] = []
        var cursor = html.startIndex

        while cursor < html.endIndex {
            guard let tagStart = html[cursor...].firstIndex(of: "<") else {
                segments.append(Segment(kind: .text, text: String(html[cursor...])))
                break
            }

            if tagStart > cursor {
                segments.append(Segment(kind: .text, text: String(html[cursor..<tagStart])))
            }

            guard let tagEnd = html[tagStart...].firstIndex(of: ">") else {
                segments.append(Segment(kind: .text, text: String(html[tagStart...])))
                break
            }

            segments.append(Segment(kind: .tag, text: String(html[tagStart...tagEnd])))
            cursor = html.index(after: tagEnd)
        }

        return segments
    }

    private static func updateSkipStack(with tag: String, skipStack: inout [Bool]) {
        guard let tagName = tagName(in: tag), !tagName.isEmpty else {
            return
        }

        if tag.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("</") {
            if !skipStack.isEmpty {
                skipStack.removeLast()
            }
            return
        }

        let isSelfClosing = tag.hasSuffix("/>") || isVoidElement(tagName)
        let shouldSkip = shouldSkipChildren(of: tagName, tag: tag)
        if !isSelfClosing {
            skipStack.append(shouldSkip)
        }
    }

    private static func tagName(in tag: String) -> String? {
        let pattern = #"^<\s*/?\s*([A-Za-z0-9:-]+)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length)),
            let range = Range(match.range(at: 1), in: tag)
        else {
            return nil
        }

        return String(tag[range]).lowercased()
    }

    private static func shouldSkipChildren(of tagName: String, tag: String) -> Bool {
        if ["a", "code", "kbd", "pre", "samp", "script", "style", "textarea"].contains(tagName) {
            return true
        }

        if tag.range(of: #"data-openmarked-rich\s*="#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        if tag.range(of: #"class\s*=\s*["'][^"']*\bom-(?:mermaid|math)[^"']*["']"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        return false
    }

    private static func isVoidElement(_ tagName: String) -> Bool {
        [
            "area",
            "base",
            "br",
            "col",
            "embed",
            "hr",
            "img",
            "input",
            "link",
            "meta",
            "param",
            "source",
            "track",
            "wbr"
        ].contains(tagName)
    }
}
