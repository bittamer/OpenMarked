import Foundation

public enum DocumentTitleSource: String, Equatable, Sendable {
    case frontMatter
    case firstHeading
    case fileName
}

public struct MarkdownDocument: Equatable, Identifiable, Sendable {
    public let id: String
    public let sourceURL: URL
    public let displayName: String
    public let sourceText: String
    public let bodyText: String
    public let frontMatter: FrontMatter?
    public let frontMatterDiagnostics: [RenderDiagnostic]
    public let metadata: DocumentFileMetadata
    public let statistics: DocumentStatistics
    public let loadedAt: Date
    public let securityScopedBookmark: SecurityScopedBookmark?

    public init(
        sourceURL: URL,
        sourceText: String,
        bodyText: String,
        frontMatter: FrontMatter?,
        frontMatterDiagnostics: [RenderDiagnostic] = [],
        metadata: DocumentFileMetadata,
        statistics: DocumentStatistics,
        loadedAt: Date,
        securityScopedBookmark: SecurityScopedBookmark?
    ) {
        self.sourceURL = sourceURL
        self.displayName = sourceURL.lastPathComponent.isEmpty ? "Untitled" : sourceURL.lastPathComponent
        self.sourceText = sourceText
        self.bodyText = bodyText
        self.frontMatter = frontMatter
        self.frontMatterDiagnostics = frontMatterDiagnostics
        self.metadata = metadata
        self.statistics = statistics
        self.loadedAt = loadedAt
        self.securityScopedBookmark = securityScopedBookmark
        self.id = sourceURL.standardizedFileURL.path
    }

    public var displayTitle: String {
        if let title = frontMatter?.title, !title.isEmpty {
            return title
        }
        return displayName
    }

    public var resolvedTitle: String {
        switch resolvedTitleSource {
        case .frontMatter:
            return frontMatter?.title ?? displayName
        case .firstHeading:
            return firstHeadingTitle ?? displayName
        case .fileName:
            return displayName
        }
    }

    public var resolvedTitleSource: DocumentTitleSource {
        if let title = frontMatter?.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .frontMatter
        }
        if firstHeadingTitle != nil {
            return .firstHeading
        }
        return .fileName
    }

    public var firstHeadingTitle: String? {
        MarkdownDocumentTitleResolver.firstHeadingTitle(in: bodyText)
    }
}

public struct DocumentFileMetadata: Equatable, Sendable {
    public let fileSize: Int64
    public let createdAt: Date?
    public let modifiedAt: Date?

    public init(fileSize: Int64, createdAt: Date?, modifiedAt: Date?) {
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public enum FrontMatterFormat: String, Equatable, Sendable {
    case yaml
    case toml
    case json
}

public struct FrontMatter: Equatable, Sendable {
    public let format: FrontMatterFormat
    public let raw: String
    public let values: [String: String]

    public init(format: FrontMatterFormat, raw: String, values: [String: String]) {
        self.format = format
        self.raw = raw
        self.values = values
    }

    public var title: String? {
        values["title"]
    }

    public var author: String? {
        values["author"]
    }

    public var date: String? {
        values["date"]
    }

    public var description: String? {
        values["description"]
    }
}

public struct DocumentStatistics: Equatable, Sendable {
    public let wordCount: Int
    public let characterCount: Int
    public let lineCount: Int
    public let readingTimeMinutes: Int

    public init(wordCount: Int, characterCount: Int, lineCount: Int, readingTimeMinutes: Int) {
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.lineCount = lineCount
        self.readingTimeMinutes = readingTimeMinutes
    }

    public static let empty = DocumentStatistics(wordCount: 0, characterCount: 0, lineCount: 0, readingTimeMinutes: 0)
}

public struct SecurityScopedBookmark: Equatable, Sendable {
    public let data: Data
    public let isStale: Bool

    public init(data: Data, isStale: Bool = false) {
        self.data = data
        self.isStale = isStale
    }
}

public struct ResolvedSecurityScopedBookmark: Equatable {
    public let url: URL
    public let bookmark: SecurityScopedBookmark

    public init(url: URL, bookmark: SecurityScopedBookmark) {
        self.url = url
        self.bookmark = bookmark
    }
}

public final class SecurityScopedResourceAccess {
    public let url: URL
    private var didStartAccessing: Bool

    public init(url: URL) {
        self.url = url
        self.didStartAccessing = url.startAccessingSecurityScopedResource()
    }

    deinit {
        stop()
    }

    public func stop() {
        guard didStartAccessing else {
            return
        }
        url.stopAccessingSecurityScopedResource()
        didStartAccessing = false
    }
}

public enum SecurityScopedBookmarkStore {
    public static func makeBookmark(for url: URL) throws -> SecurityScopedBookmark {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return SecurityScopedBookmark(data: data)
        } catch {
            throw DocumentOpenError(
                kind: .bookmarkCreationFailure,
                url: url,
                message: "OpenMarked could not create a security-scoped bookmark for \(url.lastPathComponent)."
            )
        }
    }

    public static func resolve(_ bookmark: SecurityScopedBookmark) throws -> ResolvedSecurityScopedBookmark {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark.data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let resolvedBookmark = SecurityScopedBookmark(data: bookmark.data, isStale: isStale)
            return ResolvedSecurityScopedBookmark(url: url, bookmark: resolvedBookmark)
        } catch {
            throw DocumentOpenError(
                kind: .bookmarkResolutionFailure,
                message: "OpenMarked could not resolve a saved security-scoped bookmark."
            )
        }
    }
}

public enum MarkdownDocumentLoader {
    public static func load(
        url: URL,
        fileManager: FileManager = .default,
        loadedAt: Date = Date(),
        createBookmark: Bool = true
    ) throws -> MarkdownDocument {
        _ = try DocumentOpenValidator.validate(url: url, fileManager: fileManager, openedAt: loadedAt)

        let access = SecurityScopedResourceAccess(url: url)
        defer { access.stop() }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DocumentOpenError(
                kind: .unreadable,
                url: url,
                message: "\(url.lastPathComponent) could not be read."
            )
        }

        let normalizedText = try decodeUTF8(data: data, url: url)
        let parsedFrontMatter = FrontMatterParser.parse(normalizedText)
        let metadata = try readMetadata(for: url, fileManager: fileManager)
        let statistics = DocumentStatisticsCalculator.calculate(bodyText: parsedFrontMatter.bodyText)
        let bookmark = createBookmark ? try? SecurityScopedBookmarkStore.makeBookmark(for: url) : nil

        return MarkdownDocument(
            sourceURL: url,
            sourceText: normalizedText,
            bodyText: parsedFrontMatter.bodyText,
            frontMatter: parsedFrontMatter.frontMatter,
            frontMatterDiagnostics: parsedFrontMatter.diagnostics,
            metadata: metadata,
            statistics: statistics,
            loadedAt: loadedAt,
            securityScopedBookmark: bookmark
        )
    }

    private static func decodeUTF8(data: Data, url: URL) throws -> String {
        guard !data.contains(0) else {
            throw DocumentOpenError(
                kind: .encodingFailure,
                url: url,
                message: "\(url.lastPathComponent) does not look like a UTF-8 text file."
            )
        }

        let utf8BOM = Data([0xEF, 0xBB, 0xBF])
        let textData = data.starts(with: utf8BOM) ? data.dropFirst(utf8BOM.count) : data[...]

        guard let text = String(data: Data(textData), encoding: .utf8) else {
            throw DocumentOpenError(
                kind: .encodingFailure,
                url: url,
                message: "\(url.lastPathComponent) could not be decoded as UTF-8."
            )
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func readMetadata(for url: URL, fileManager: FileManager) throws -> DocumentFileMetadata {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? NSNumber
        let createdAt = attributes[.creationDate] as? Date
        let modifiedAt = attributes[.modificationDate] as? Date

        return DocumentFileMetadata(
            fileSize: size?.int64Value ?? 0,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

public struct FrontMatterParseResult: Equatable, Sendable {
    public let frontMatter: FrontMatter?
    public let bodyText: String
    public let diagnostics: [RenderDiagnostic]

    public init(frontMatter: FrontMatter?, bodyText: String, diagnostics: [RenderDiagnostic] = []) {
        self.frontMatter = frontMatter
        self.bodyText = bodyText
        self.diagnostics = diagnostics
    }
}

public enum FrontMatterParser {
    public static func parse(_ sourceText: String) -> FrontMatterParseResult {
        if let parsed = parse(sourceText, delimiter: "---", format: .yaml) {
            return parsed
        }

        if let parsed = parse(sourceText, delimiter: "+++", format: .toml) {
            return parsed
        }

        if let parsed = parse(sourceText, delimiter: ";;;", format: .json) {
            return parsed
        }

        return FrontMatterParseResult(frontMatter: nil, bodyText: sourceText)
    }

    private static func parse(_ sourceText: String, delimiter: String, format: FrontMatterFormat) -> FrontMatterParseResult? {
        let lines = sourceText.components(separatedBy: "\n")
        guard lines.first == delimiter else {
            return nil
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == delimiter }) else {
            return FrontMatterParseResult(
                frontMatter: nil,
                bodyText: sourceText,
                diagnostics: [
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .malformedFrontMatter,
                        message: "Front matter opened with '\(delimiter)' but no closing delimiter was found.",
                        source: delimiter
                    )
                ]
            )
        }

        let raw = lines[1..<closingIndex].joined(separator: "\n")
        let bodyText: String
        if closingIndex + 1 < lines.count {
            bodyText = lines[(closingIndex + 1)..<lines.count].joined(separator: "\n")
        } else {
            bodyText = ""
        }

        let parsedValues = parseValues(raw, format: format)
        return FrontMatterParseResult(
            frontMatter: FrontMatter(format: format, raw: raw, values: parsedValues.values),
            bodyText: bodyText,
            diagnostics: parsedValues.diagnostics
        )
    }

    private static func parseValues(_ raw: String, format: FrontMatterFormat) -> (values: [String: String], diagnostics: [RenderDiagnostic]) {
        if format == .json {
            return parseJSONValues(raw)
        }

        var values: [String: String] = [:]
        var diagnostics: [RenderDiagnostic] = []
        var pendingNestedKey: String?
        var pendingNestedLines: [String] = []

        func flushNestedValue() {
            guard let key = pendingNestedKey else {
                return
            }
            values[key] = normalizedNestedValue(from: pendingNestedLines)
            pendingNestedKey = nil
            pendingNestedLines = []
        }

        for line in raw.components(separatedBy: "\n") {
            let isIndented = line.first?.isWhitespace == true
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }

            if isIndented, pendingNestedKey != nil {
                pendingNestedLines.append(trimmed)
                continue
            }

            flushNestedValue()

            let separator = format == .yaml ? ":" : "="
            guard let range = trimmed.range(of: separator), !trimmed.hasPrefix("[") else {
                diagnostics.append(
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .malformedFrontMatter,
                        message: "Front matter line '\(trimmed)' could not be parsed.",
                        source: trimmed
                    )
                )
                continue
            }

            let key = String(trimmed[..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
            let value = String(trimmed[range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            guard !key.isEmpty else {
                continue
            }

            if value.isEmpty {
                pendingNestedKey = key
                pendingNestedLines = []
            } else {
                values[key] = value
            }
        }

        flushNestedValue()

        return (values, diagnostics)
    }

    private static func parseJSONValues(_ raw: String) -> (values: [String: String], diagnostics: [RenderDiagnostic]) {
        do {
            let object = try JSONSerialization.jsonObject(with: Data(raw.utf8), options: [])
            guard let dictionary = object as? [String: Any] else {
                return (
                    [:],
                    [
                        RenderDiagnostic(
                            severity: .warning,
                            kind: .malformedFrontMatter,
                            message: "JSON front matter must be an object.",
                            source: "json"
                        )
                    ]
                )
            }

            var values: [String: String] = [:]
            for (key, value) in dictionary {
                values[key.lowercased()] = stringifyJSONValue(value)
            }
            return (values, [])
        } catch {
            return (
                [:],
                [
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .malformedFrontMatter,
                        message: "JSON front matter could not be parsed.",
                        source: "json"
                    )
                ]
            )
        }
    }

    private static func normalizedNestedValue(from lines: [String]) -> String {
        let values = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                return nil
            }
            if trimmed.hasPrefix("-") {
                return trimmed
                    .dropFirst()
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
            return trimmed
        }

        guard !values.isEmpty else {
            return ""
        }
        if lines.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") }) {
            return "[\(values.joined(separator: ", "))]"
        }
        return "{ \(values.joined(separator: "; ")) }"
    }

    private static func stringifyJSONValue(_ value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        case let array as [Any]:
            return "[\(array.map(stringifyJSONValue).joined(separator: ", "))]"
        case let dictionary as [String: Any]:
            let body = dictionary
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(stringifyJSONValue($0.value))" }
                .joined(separator: "; ")
            return "{ \(body) }"
        default:
            return "\(value)"
        }
    }
}

private enum MarkdownDocumentTitleResolver {
    static func firstHeadingTitle(in bodyText: String) -> String? {
        var isInFence = false

        for rawLine in bodyText.components(separatedBy: "\n") {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~") {
                isInFence.toggle()
                continue
            }

            guard !isInFence, trimmedLine.hasPrefix("#") else {
                continue
            }

            let hashCount = trimmedLine.prefix(while: { $0 == "#" }).count
            guard hashCount > 0, hashCount <= 6 else {
                continue
            }

            let remainderStart = trimmedLine.index(trimmedLine.startIndex, offsetBy: hashCount)
            guard remainderStart < trimmedLine.endIndex, trimmedLine[remainderStart].isWhitespace else {
                continue
            }

            let rawTitle = String(trimmedLine[remainderStart...])
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: #"\s+#+\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = normalizedHeadingTitle(rawTitle)
            if !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private static func normalizedHeadingTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: #"`([^`]*)`"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"[*_~]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum DocumentStatisticsCalculator {
    private static let wordsPerMinute = 225

    public static func calculate(bodyText: String) -> DocumentStatistics {
        let lineCount = bodyText.isEmpty ? 0 : bodyText.components(separatedBy: "\n").count
        let wordCount = countWords(in: textForWordCounting(bodyText))
        let readingTime = wordCount == 0 ? 0 : max(1, Int(ceil(Double(wordCount) / Double(wordsPerMinute))))

        return DocumentStatistics(
            wordCount: wordCount,
            characterCount: bodyText.count,
            lineCount: lineCount,
            readingTimeMinutes: readingTime
        )
    }

    private static func textForWordCounting(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"(?s)```.*?```"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"`([^`]*)`"#, with: " $1 ", options: .regularExpression)
            .replacingOccurrences(of: #"!\[[^\]]*\]\([^)]+\)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: " $1 ", options: .regularExpression)
            .replacingOccurrences(of: #"(?m)^#{1,6}\s*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[*_~>#\-\[\]\(\)]"#, with: " ", options: .regularExpression)
    }

    private static func countWords(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .localized]) { _, _, _, _ in
            count += 1
        }
        return count
    }
}
