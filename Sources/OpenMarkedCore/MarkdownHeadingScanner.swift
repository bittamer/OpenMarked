import Foundation

struct MarkdownHeadingIndex: Equatable, Sendable {
    let outline: [OutlineItem]
    let headingIDs: Set<String>

    static let empty = MarkdownHeadingIndex(outline: [], headingIDs: [])
}

enum MarkdownHeadingScanner {
    static func scan(_ markdown: String, slugStyle: HeadingSlugStyle = .openMarked) -> MarkdownHeadingIndex {
        guard !markdown.isEmpty else {
            return .empty
        }

        var outline: [OutlineItem] = []
        var usedSlugs: [String: Int] = [:]
        var fence: Fence?
        var setextCandidate: String?

        markdown.enumerateSubstrings(in: markdown.startIndex..<markdown.endIndex, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            let line = String(markdown[lineRange])
            let indented = IndentedLine(line)

            if let updatedFence = updatedFence(from: indented, current: fence) {
                fence = updatedFence.isClosed ? nil : updatedFence
                setextCandidate = nil
                return
            }

            guard fence == nil else {
                return
            }

            if appendRawHTMLHeadings(from: line, to: &outline, usedSlugs: &usedSlugs, slugStyle: slugStyle) {
                setextCandidate = nil
                return
            }

            if let heading = atxHeading(from: indented) {
                append(title: heading.title, level: heading.level, to: &outline, usedSlugs: &usedSlugs, slugStyle: slugStyle)
                setextCandidate = nil
                return
            }

            if let level = setextLevel(from: indented), let candidate = setextCandidate {
                append(title: candidate, level: level, to: &outline, usedSlugs: &usedSlugs, slugStyle: slugStyle)
                setextCandidate = nil
                return
            }

            setextCandidate = nextSetextCandidate(from: indented)
        }

        return MarkdownHeadingIndex(outline: outline, headingIDs: Set(outline.map(\.id)))
    }

    private static func append(
        title rawTitle: String,
        level: Int,
        to outline: inout [OutlineItem],
        usedSlugs: inout [String: Int],
        slugStyle: HeadingSlugStyle
    ) {
        let title = markdownPlainText(rawTitle)
        let id = uniqueSlug(for: title, slugStyle: slugStyle, usedSlugs: &usedSlugs)
        outline.append(OutlineItem(id: id, level: level, title: title.isEmpty ? "Untitled Heading" : title))
    }

    private static func appendRawHTMLHeadings(
        from line: String,
        to outline: inout [OutlineItem],
        usedSlugs: inout [String: Int],
        slugStyle: HeadingSlugStyle
    ) -> Bool {
        var appended = false

        for tag in HTMLTagScanner.tags(in: line) where tag.name.count == 2 && tag.name.first == "h" {
            guard
                let level = Int(String(tag.name.suffix(1))),
                (1...6).contains(level),
                let closingStart = HTMLTagScanner.closingTagStart(named: tag.name, in: line, from: tag.range.upperBound)
            else {
                continue
            }

            let title = HTMLUtilities.plainText(fromHTMLFragment: String(line[tag.range.upperBound..<closingStart]))
            let id = tag.attributeValue(named: "id") ?? uniqueSlug(for: title, slugStyle: slugStyle, usedSlugs: &usedSlugs)
            outline.append(OutlineItem(id: id, level: level, title: title.isEmpty ? "Untitled Heading" : title))
            appended = true
        }

        return appended
    }

    private static func atxHeading(from line: IndentedLine) -> (level: Int, title: String)? {
        guard line.indentation <= 3, line.content.first == "#" else {
            return nil
        }

        let level = line.content.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level) else {
            return nil
        }

        let markerEnd = line.content.index(line.content.startIndex, offsetBy: level)
        guard markerEnd == line.content.endIndex || line.content[markerEnd].isWhitespace else {
            return nil
        }

        let rawTitle = markerEnd == line.content.endIndex ? "" : String(line.content[markerEnd...])
        return (
            level,
            rawTitle
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"\s+#+\s*$"#, with: "", options: .regularExpression)
        )
    }

    private static func setextLevel(from line: IndentedLine) -> Int? {
        guard line.indentation <= 3 else {
            return nil
        }

        let trimmed = line.content.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first == "=" || first == "-" else {
            return nil
        }

        guard trimmed.allSatisfy({ $0 == first }) else {
            return nil
        }

        return first == "=" ? 1 : 2
    }

    private static func nextSetextCandidate(from line: IndentedLine) -> String? {
        guard line.indentation <= 3 else {
            return nil
        }

        let trimmed = line.content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private static func updatedFence(from line: IndentedLine, current: Fence?) -> Fence? {
        guard line.indentation <= 3 else {
            return nil
        }

        let trimmed = line.content.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else {
            return nil
        }

        let count = trimmed.prefix(while: { $0 == marker }).count
        guard count >= 3 else {
            return nil
        }

        if let current {
            return marker == current.marker && count >= current.count ? current.closed() : nil
        }

        return Fence(marker: marker, count: count)
    }

    private static func markdownPlainText(_ title: String) -> String {
        title
            .replacingOccurrences(of: #"!\[[^\]]*\]\([^)]+\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]*)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[*~]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func uniqueSlug(
        for title: String,
        slugStyle: HeadingSlugStyle,
        usedSlugs: inout [String: Int]
    ) -> String {
        let base = HeadingPostProcessor.slug(for: title, style: slugStyle)
        let priorCount = usedSlugs[base, default: 0]
        usedSlugs[base] = priorCount + 1
        return priorCount == 0 ? base : "\(base)-\(priorCount)"
    }

    private struct IndentedLine {
        let indentation: Int
        let content: Substring

        init(_ line: String) {
            var indentation = 0
            var start = line.startIndex

            while start < line.endIndex, line[start] == " " {
                indentation += 1
                start = line.index(after: start)
            }

            self.indentation = indentation
            self.content = line[start...]
        }
    }

    private struct Fence {
        let marker: Character
        let count: Int
        var isClosed = false

        func closed() -> Fence {
            Fence(marker: marker, count: count, isClosed: true)
        }
    }
}
