import Foundation

struct MarkdownHeadingIndex: Equatable, Sendable {
    let outline: [OutlineItem]
    let headingIDs: Set<String>
    let firstHeadingTitle: String?
    let occurrences: [MarkdownHeadingOccurrence]

    static let empty = MarkdownHeadingIndex(outline: [], headingIDs: [], firstHeadingTitle: nil, occurrences: [])
}

struct MarkdownHeadingOccurrence: Equatable, Sendable {
    let item: OutlineItem
    let lineIndex: Int
    let contentStartLineIndex: Int
}

enum MarkdownHeadingScanner {
    static func firstHeadingTitle(in markdown: String) -> String? {
        scan(markdown, mode: .firstHeadingTitle).firstHeadingTitle
    }

    static func scan(_ markdown: String, slugStyle: HeadingSlugStyle = .openMarked) -> MarkdownHeadingIndex {
        scan(markdown, slugStyle: slugStyle, mode: .all)
    }

    private static func scan(
        _ markdown: String,
        slugStyle: HeadingSlugStyle = .openMarked,
        mode: ScanMode
    ) -> MarkdownHeadingIndex {
        guard !markdown.isEmpty else {
            return .empty
        }

        var outline: [OutlineItem] = []
        var occurrences: [MarkdownHeadingOccurrence] = []
        var usedSlugs: [String: Int] = [:]
        var fence: Fence?
        var setextCandidate: SetextCandidate?
        var firstHeadingTitle: String?
        var lineIndex = 0

        markdown.enumerateSubstrings(in: markdown.startIndex..<markdown.endIndex, options: [.byLines, .substringNotRequired]) { _, lineRange, _, stop in
            defer { lineIndex += 1 }

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

            if appendRawHTMLHeadings(
                from: line,
                lineIndex: lineIndex,
                to: &outline,
                occurrences: &occurrences,
                firstHeadingTitle: &firstHeadingTitle,
                usedSlugs: &usedSlugs,
                slugStyle: slugStyle
            ) {
                setextCandidate = nil
                stop = shouldStopScanning(mode: mode, firstHeadingTitle: firstHeadingTitle)
                return
            }

            if let heading = atxHeading(from: indented) {
                append(
                    title: heading.title,
                    level: heading.level,
                    lineIndex: lineIndex,
                    contentStartLineIndex: lineIndex + 1,
                    to: &outline,
                    occurrences: &occurrences,
                    firstHeadingTitle: &firstHeadingTitle,
                    usedSlugs: &usedSlugs,
                    slugStyle: slugStyle
                )
                setextCandidate = nil
                stop = shouldStopScanning(mode: mode, firstHeadingTitle: firstHeadingTitle)
                return
            }

            if let level = setextLevel(from: indented), let candidate = setextCandidate {
                append(
                    title: candidate.title,
                    level: level,
                    lineIndex: candidate.lineIndex,
                    contentStartLineIndex: lineIndex + 1,
                    to: &outline,
                    occurrences: &occurrences,
                    firstHeadingTitle: &firstHeadingTitle,
                    usedSlugs: &usedSlugs,
                    slugStyle: slugStyle
                )
                setextCandidate = nil
                stop = shouldStopScanning(mode: mode, firstHeadingTitle: firstHeadingTitle)
                return
            }

            setextCandidate = nextSetextCandidate(from: indented, lineIndex: lineIndex)
        }

        return MarkdownHeadingIndex(
            outline: outline,
            headingIDs: Set(outline.map(\.id)),
            firstHeadingTitle: firstHeadingTitle,
            occurrences: occurrences
        )
    }

    static func containsSingleLineHeading(_ line: String) -> Bool {
        let indented = IndentedLine(line)
        if atxHeading(from: indented) != nil {
            return true
        }
        return rawHTMLHeading(in: line) != nil
    }

    private static func shouldStopScanning(mode: ScanMode, firstHeadingTitle: String?) -> Bool {
        mode == .firstHeadingTitle && firstHeadingTitle != nil
    }

    private static func append(
        title rawTitle: String,
        level: Int,
        lineIndex: Int,
        contentStartLineIndex: Int,
        to outline: inout [OutlineItem],
        occurrences: inout [MarkdownHeadingOccurrence],
        firstHeadingTitle: inout String?,
        usedSlugs: inout [String: Int],
        slugStyle: HeadingSlugStyle
    ) {
        let title = markdownPlainText(rawTitle)
        let id = uniqueSlug(for: title, slugStyle: slugStyle, usedSlugs: &usedSlugs)
        append(
            item: OutlineItem(id: id, level: level, title: title.isEmpty ? "Untitled Heading" : title),
            documentTitle: title.isEmpty ? nil : title,
            lineIndex: lineIndex,
            contentStartLineIndex: contentStartLineIndex,
            to: &outline,
            occurrences: &occurrences,
            firstHeadingTitle: &firstHeadingTitle
        )
    }

    private static func appendRawHTMLHeadings(
        from line: String,
        lineIndex: Int,
        to outline: inout [OutlineItem],
        occurrences: inout [MarkdownHeadingOccurrence],
        firstHeadingTitle: inout String?,
        usedSlugs: inout [String: Int],
        slugStyle: HeadingSlugStyle
    ) -> Bool {
        var appended = false

        for heading in rawHTMLHeadings(in: line) {
            let id = heading.id ?? uniqueSlug(for: heading.title, slugStyle: slugStyle, usedSlugs: &usedSlugs)
            append(
                item: OutlineItem(id: id, level: heading.level, title: heading.title.isEmpty ? "Untitled Heading" : heading.title),
                documentTitle: heading.title.isEmpty ? nil : heading.title,
                lineIndex: lineIndex,
                contentStartLineIndex: lineIndex + 1,
                to: &outline,
                occurrences: &occurrences,
                firstHeadingTitle: &firstHeadingTitle
            )
            appended = true
        }

        return appended
    }

    private static func append(
        item: OutlineItem,
        documentTitle: String?,
        lineIndex: Int,
        contentStartLineIndex: Int,
        to outline: inout [OutlineItem],
        occurrences: inout [MarkdownHeadingOccurrence],
        firstHeadingTitle: inout String?
    ) {
        outline.append(item)
        occurrences.append(
            MarkdownHeadingOccurrence(
                item: item,
                lineIndex: lineIndex,
                contentStartLineIndex: contentStartLineIndex
            )
        )
        if firstHeadingTitle == nil {
            firstHeadingTitle = documentTitle
        }
    }

    private static func rawHTMLHeading(in line: String) -> (level: Int, title: String, id: String?)? {
        rawHTMLHeadings(in: line).first
    }

    private static func rawHTMLHeadings(in line: String) -> [(level: Int, title: String, id: String?)] {
        HTMLTagScanner.tags(in: line).compactMap { tag in
            guard
                tag.name.count == 2,
                tag.name.first == "h",
                let level = Int(String(tag.name.suffix(1))),
                (1...6).contains(level),
                let closingStart = HTMLTagScanner.closingTagStart(named: tag.name, in: line, from: tag.range.upperBound)
            else {
                return nil
            }

            let title = HTMLUtilities.plainText(fromHTMLFragment: String(line[tag.range.upperBound..<closingStart]))
            return (level, title, tag.attributeValue(named: "id"))
        }
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

    private static func nextSetextCandidate(from line: IndentedLine, lineIndex: Int) -> SetextCandidate? {
        guard line.indentation <= 3 else {
            return nil
        }

        let trimmed = line.content.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }

        return SetextCandidate(title: trimmed, lineIndex: lineIndex)
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

    private struct SetextCandidate {
        let title: String
        let lineIndex: Int
    }

    private enum ScanMode {
        case all
        case firstHeadingTitle
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
