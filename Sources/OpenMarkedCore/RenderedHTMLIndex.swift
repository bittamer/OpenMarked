import Foundation

public struct RenderedImageReference: Equatable, Sendable {
    public let source: String
    public let altText: String
    public let occurrenceIndex: Int
    public let isBlocked: Bool
    public let resolvedLocalURL: URL?
}

public struct RenderedHTMLIndex: Equatable, Sendable {
    public let links: [LinkReference]
    public let images: [RenderedImageReference]
    public let tagCounts: [String: Int]

    public static let empty = RenderedHTMLIndex(links: [], images: [], tagCounts: [:])

    public var imageCount: Int {
        images.count
    }

    public var linkCount: Int {
        links.count
    }

    public var tableCount: Int {
        tagCount("table")
    }

    public var paragraphCount: Int {
        tagCount("p")
    }

    public func tagCount(_ name: String) -> Int {
        tagCounts[name.lowercased()] ?? 0
    }

    public var localImageSources: [(source: String, url: URL)] {
        images.compactMap { image in
            guard let url = image.resolvedLocalURL else {
                return nil
            }
            return (image.source, url)
        }
    }

    public var localImageURLs: [URL] {
        var seen = Set<String>()
        return localImageSources.map(\.url).filter { url in
            let key = url.standardizedFileURL.path
            guard seen.insert(key).inserted else {
                return false
            }
            return true
        }
    }

    public static func build(from html: String, document: MarkdownDocument? = nil) -> RenderedHTMLIndex {
        guard !html.isEmpty else {
            return .empty
        }

        let baseURL = document?.sourceURL.deletingLastPathComponent()
        var links: [LinkReference] = []
        var images: [RenderedImageReference] = []
        var tagCounts: [String: Int] = [:]
        var linkOccurrenceIndex = 0
        var imageOccurrenceIndex = 0

        for tag in HTMLTagScanner.tags(in: html) {
            tagCounts[tag.name, default: 0] += 1

            switch tag.name {
            case "a":
                guard let href = tag.attributeValue(named: "href") else {
                    continue
                }

                let occurrenceIndex = linkOccurrenceIndex
                linkOccurrenceIndex += 1

                let source = href.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty else {
                    continue
                }

                links.append(
                    LinkReference(
                        source: source,
                        text: linkText(in: html, after: tag),
                        occurrenceIndex: occurrenceIndex
                    )
                )
            case "img":
                let occurrenceIndex = imageOccurrenceIndex
                imageOccurrenceIndex += 1

                let blockedSource = tag.attributeValue(named: "data-openmarked-blocked-src")
                let source = (blockedSource ?? tag.attributeValue(named: "src"))?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let source, !source.isEmpty else {
                    continue
                }

                let resolvedURL: URL?
                if let baseURL, LocalAssetReferenceExtractor.isLocalImagePath(source) {
                    resolvedURL = LocalAssetReferenceExtractor.localFileURL(for: source, relativeTo: baseURL)
                } else {
                    resolvedURL = nil
                }

                images.append(
                    RenderedImageReference(
                        source: source,
                        altText: tag.attributeValue(named: "alt") ?? "",
                        occurrenceIndex: occurrenceIndex,
                        isBlocked: blockedSource != nil,
                        resolvedLocalURL: resolvedURL
                    )
                )
            default:
                continue
            }
        }

        return RenderedHTMLIndex(links: links, images: images, tagCounts: tagCounts)
    }

    private static func linkText(in html: String, after tag: HTMLTagOccurrence) -> String {
        guard let closingStart = HTMLTagScanner.closingTagStart(named: "a", in: html, from: tag.range.upperBound) else {
            return ""
        }

        return HTMLUtilities.plainText(fromHTMLFragment: String(html[tag.range.upperBound..<closingStart]))
    }
}

struct HTMLTagAttributeOccurrence: Equatable {
    let lowercasedName: String
    let value: String
    let valueRange: Range<String.Index>?
}

struct HTMLTagOccurrence: Equatable {
    let name: String
    let range: Range<String.Index>
    let attributes: [HTMLTagAttributeOccurrence]

    func hasAttribute(named name: String) -> Bool {
        let normalized = name.lowercased()
        return attributes.contains { $0.lowercasedName == normalized }
    }

    func attributeValue(named name: String) -> String? {
        let normalized = name.lowercased()
        return attributes.first { $0.lowercasedName == normalized }?.value
    }

    func attribute(named name: String) -> HTMLTagAttributeOccurrence? {
        let normalized = name.lowercased()
        return attributes.first { $0.lowercasedName == normalized }
    }
}

enum HTMLTagScanner {
    static func tags(in html: String, named requestedName: String? = nil) -> [HTMLTagOccurrence] {
        guard !html.isEmpty else {
            return []
        }

        let requestedName = requestedName?.lowercased()
        var tags: [HTMLTagOccurrence] = []
        var index = html.startIndex

        while let opening = html[index...].firstIndex(of: "<") {
            let afterOpening = html.index(after: opening)
            guard afterOpening < html.endIndex else {
                break
            }

            let first = html[afterOpening]
            guard first != "/", first != "!", first != "?" else {
                index = afterOpening
                continue
            }

            guard let tagEnd = tagEnd(in: html, from: afterOpening) else {
                break
            }

            guard let tag = parseTag(in: html, opening: opening, afterOpening: afterOpening, tagEnd: tagEnd) else {
                index = html.index(after: tagEnd)
                continue
            }

            if requestedName == nil || tag.name == requestedName {
                tags.append(tag)
            }
            index = html.index(after: tagEnd)
        }

        return tags
    }

    static func closingTagStart(named name: String, in html: String, from start: String.Index) -> String.Index? {
        let needle = "</\(name)"
        var searchRange = start..<html.endIndex

        while let range = html.range(of: needle, options: [.caseInsensitive], range: searchRange) {
            let nameEnd = range.upperBound
            guard nameEnd == html.endIndex || html[nameEnd].isWhitespace || html[nameEnd] == ">" else {
                searchRange = nameEnd..<html.endIndex
                continue
            }
            return range.lowerBound
        }

        return nil
    }

    private static func parseTag(
        in html: String,
        opening: String.Index,
        afterOpening: String.Index,
        tagEnd: String.Index
    ) -> HTMLTagOccurrence? {
        var cursor = afterOpening
        let nameStart = cursor

        while cursor < tagEnd, isNameCharacter(html[cursor]) {
            cursor = html.index(after: cursor)
        }

        guard nameStart < cursor else {
            return nil
        }

        let name = String(html[nameStart..<cursor]).lowercased()
        let attributes = parseAttributes(in: html, from: cursor, to: tagEnd)
        let range = opening..<html.index(after: tagEnd)

        return HTMLTagOccurrence(
            name: name,
            range: range,
            attributes: attributes
        )
    }

    private static func tagEnd(in html: String, from start: String.Index) -> String.Index? {
        var cursor = start
        var quote: Character?

        while cursor < html.endIndex {
            let character = html[cursor]
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return cursor
            }

            cursor = html.index(after: cursor)
        }

        return nil
    }

    private static func parseAttributes(
        in html: String,
        from start: String.Index,
        to tagEnd: String.Index
    ) -> [HTMLTagAttributeOccurrence] {
        var attributes: [HTMLTagAttributeOccurrence] = []
        var cursor = start

        while cursor < tagEnd {
            skipWhitespace(in: html, cursor: &cursor, end: tagEnd)
            guard cursor < tagEnd else {
                break
            }

            if html[cursor] == "/" {
                cursor = html.index(after: cursor)
                continue
            }

            let nameStart = cursor
            while cursor < tagEnd, !isAttributeNameTerminator(html[cursor]) {
                cursor = html.index(after: cursor)
            }

            guard nameStart < cursor else {
                cursor = html.index(after: cursor)
                continue
            }

            let rawName = String(html[nameStart..<cursor])
            skipWhitespace(in: html, cursor: &cursor, end: tagEnd)

            guard cursor < tagEnd, html[cursor] == "=" else {
                attributes.append(
                    HTMLTagAttributeOccurrence(
                        lowercasedName: rawName.lowercased(),
                        value: "",
                        valueRange: nil
                    )
                )
                continue
            }

            cursor = html.index(after: cursor)
            skipWhitespace(in: html, cursor: &cursor, end: tagEnd)

            let parsedValue = parseAttributeValue(in: html, cursor: &cursor, tagEnd: tagEnd)
            attributes.append(
                HTMLTagAttributeOccurrence(
                    lowercasedName: rawName.lowercased(),
                    value: HTMLUtilities.decodeEntities(in: parsedValue.value)
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    valueRange: parsedValue.range
                )
            )
        }

        return attributes
    }

    private static func parseAttributeValue(
        in html: String,
        cursor: inout String.Index,
        tagEnd: String.Index
    ) -> (value: String, range: Range<String.Index>?) {
        guard cursor < tagEnd else {
            return ("", nil)
        }

        if html[cursor] == "\"" || html[cursor] == "'" {
            let quote = html[cursor]
            cursor = html.index(after: cursor)
            let valueStart = cursor

            while cursor < tagEnd, html[cursor] != quote {
                cursor = html.index(after: cursor)
            }

            let valueEnd = cursor
            if cursor < tagEnd {
                cursor = html.index(after: cursor)
            }

            return (String(html[valueStart..<valueEnd]), valueStart..<valueEnd)
        }

        let valueStart = cursor
        while cursor < tagEnd, !html[cursor].isWhitespace {
            if html[cursor] == "/", html.index(after: cursor) == tagEnd {
                break
            }
            cursor = html.index(after: cursor)
        }

        return (String(html[valueStart..<cursor]), valueStart..<cursor)
    }

    private static func skipWhitespace(in html: String, cursor: inout String.Index, end: String.Index) {
        while cursor < end, html[cursor].isWhitespace {
            cursor = html.index(after: cursor)
        }
    }

    private static func isNameCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == ":" || character == "_"
    }

    private static func isAttributeNameTerminator(_ character: Character) -> Bool {
        character.isWhitespace || character == "=" || character == "/" || character == ">"
    }

}

enum HTMLTagRewriter {
    static func appending(attributes: [String], to tagText: String) -> String {
        guard !attributes.isEmpty else {
            return tagText
        }

        let insertion = " " + attributes.joined(separator: " ")
        if tagText.hasSuffix("/>") {
            return String(tagText.dropLast(2)) + insertion + " />"
        }
        return String(tagText.dropLast()) + insertion + ">"
    }
}
