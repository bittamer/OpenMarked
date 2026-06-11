import Foundation

public enum CodeHighlighter {
    public static let supportedLanguages: Set<String> = [
        "swift",
        "javascript",
        "js",
        "json",
        "shell",
        "sh",
        "bash",
        "html",
        "xml"
    ]

    public static func highlight(_ html: String) -> String {
        let blocks = HTMLCodeBlockScanner.blocks(in: html)
        guard !blocks.isEmpty else {
            return html
        }
        var rendered = html

        for block in blocks.reversed() {
            let normalizedLanguage = normalize(block.language)
            let decodedCode = HTMLUtilities.decodeEntities(in: block.codeHTML)

            guard let normalizedLanguage, supportedLanguages.contains(normalizedLanguage) else {
                let replacement = #"<pre\#(block.preAttributes) class="om-code-block"><code\#(block.codeAttributes)>\#(block.codeHTML)</code></pre>"#
                rendered.replaceSubrange(block.range, with: replacement)
                continue
            }

            let highlighted = highlight(decodedCode, language: normalizedLanguage)
            let replacement = #"<pre\#(block.preAttributes) class="om-code-block om-code-\#(normalizedLanguage)"><code\#(block.codeAttributes)>\#(highlighted)</code></pre>"#
            rendered.replaceSubrange(block.range, with: replacement)
        }

        return rendered
    }

    public static func highlight(_ code: String, language: String) -> String {
        switch language {
        case "json":
            return highlightJSON(code)
        case "html", "xml":
            return highlightMarkup(code)
        default:
            return highlightCodeLikeLanguage(code, language: language)
        }
    }

    private static func normalize(_ language: String?) -> String? {
        guard let language else {
            return nil
        }

        let normalized = language.lowercased()
        switch normalized {
        case "js":
            return "javascript"
        case "sh":
            return "shell"
        default:
            return normalized
        }
    }

    private static func highlightJSON(_ code: String) -> String {
        var html = HTMLUtilities.escapeText(code)
        html = replacing(pattern: #"(&quot;[^&]*?&quot;)(\s*:)"#, in: html) { match in
            #"<span class="om-code-property">\#(match[1])</span>\#(match[2])"#
        }
        html = replacing(pattern: #"(:\s*)(&quot;.*?&quot;)"#, in: html) { match in
            #"\#(match[1])<span class="om-code-string">\#(match[2])</span>"#
        }
        html = replacing(pattern: #"\b(-?[0-9]+(?:\.[0-9]+)?)\b"#, in: html) { match in
            #"<span class="om-code-number">\#(match[1])</span>"#
        }
        html = replacing(pattern: #"\b(true|false|null)\b"#, in: html) { match in
            #"<span class="om-code-keyword">\#(match[1])</span>"#
        }
        return html
    }

    private static func highlightMarkup(_ code: String) -> String {
        let html = HTMLUtilities.escapeText(code)
        return replacing(
            pattern: #"(&lt;!--.*?--&gt;|&lt;/?[A-Za-z][A-Za-z0-9:-]*|[A-Za-z_:][A-Za-z0-9:._-]*(?==)|&quot;.*?&quot;)"#,
            in: html
        ) { match in
            let token = match[1]
            if token.hasPrefix("&lt;!--") {
                return #"<span class="om-code-comment">\#(token)</span>"#
            }
            if token.hasPrefix("&lt;") {
                return #"<span class="om-code-tag">\#(token)</span>"#
            }
            if token.hasPrefix("&quot;") {
                return #"<span class="om-code-string">\#(token)</span>"#
            }
            return #"<span class="om-code-property">\#(token)</span>"#
        }
    }

    private static func highlightCodeLikeLanguage(_ code: String, language: String) -> String {
        var html = HTMLUtilities.escapeText(code)
        let keywords = keywords(for: language)
        if !keywords.isEmpty {
            let keywordPattern = #"\b(\#(keywords.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")))\b"#
            html = replacing(pattern: keywordPattern, in: html) { match in
                #"<span class="om-code-keyword">\#(match[1])</span>"#
            }
        }

        let commentPattern = language == "shell" ? #"(?m)(#.*?$)"# : #"(?m)(//.*?$)"#
        html = replacing(pattern: commentPattern, in: html) { match in
            #"<span class="om-code-comment">\#(match[1])</span>"#
        }
        html = replacing(pattern: #"(&quot;.*?&quot;|'.*?')"#, in: html) { match in
            #"<span class="om-code-string">\#(match[1])</span>"#
        }
        html = replacing(pattern: #"\b([0-9]+(?:\.[0-9]+)?)\b"#, in: html) { match in
            #"<span class="om-code-number">\#(match[1])</span>"#
        }
        return html
    }

    private static func keywords(for language: String) -> [String] {
        switch language {
        case "swift":
            return ["actor", "as", "associatedtype", "await", "case", "class", "defer", "else", "enum", "extension", "false", "for", "func", "guard", "if", "import", "in", "init", "let", "nil", "private", "protocol", "public", "return", "self", "static", "struct", "switch", "throws", "true", "try", "var", "while"]
        case "javascript":
            return ["async", "await", "case", "catch", "class", "const", "else", "export", "false", "for", "function", "if", "import", "let", "new", "null", "return", "switch", "this", "throw", "true", "try", "var", "while"]
        case "shell":
            return ["case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if", "in", "then", "while"]
        default:
            return []
        }
    }

    private static func replacing(pattern: String, in text: String, transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        var rendered = text
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: text) else {
                continue
            }

            var captures: [String] = []
            for index in 0..<match.numberOfRanges {
                if let range = Range(match.range(at: index), in: text) {
                    captures.append(String(text[range]))
                } else {
                    captures.append("")
                }
            }

            rendered.replaceSubrange(fullRange, with: transform(captures))
        }

        return rendered
    }
}
