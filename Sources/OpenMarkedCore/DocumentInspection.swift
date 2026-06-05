import Foundation

public struct DocumentInspectionReport: Equatable, Sendable {
    public let metadata: DocumentMetadataInspection
    public let statistics: RichDocumentStatistics
    public let links: [DocumentLinkReference]
    public let assets: [DocumentAssetReference]
    public let diagnostics: [RenderDiagnostic]
    public let exportReadiness: ExportReadinessReport

    public init(
        metadata: DocumentMetadataInspection,
        statistics: RichDocumentStatistics,
        links: [DocumentLinkReference],
        assets: [DocumentAssetReference],
        diagnostics: [RenderDiagnostic],
        exportReadiness: ExportReadinessReport
    ) {
        self.metadata = metadata
        self.statistics = statistics
        self.links = links
        self.assets = assets
        self.diagnostics = diagnostics
        self.exportReadiness = exportReadiness
    }

    public static let empty = DocumentInspectionReport(
        metadata: .empty,
        statistics: .empty,
        links: [],
        assets: [],
        diagnostics: [],
        exportReadiness: .ready
    )
}

public struct DocumentMetadataInspection: Equatable, Sendable {
    public let displayTitle: String
    public let titleSource: DocumentTitleSource
    public let frontMatterFormat: FrontMatterFormat?
    public let fields: [MetadataField]
    public let fileFacts: [MetadataField]

    public init(
        displayTitle: String,
        titleSource: DocumentTitleSource,
        frontMatterFormat: FrontMatterFormat?,
        fields: [MetadataField],
        fileFacts: [MetadataField]
    ) {
        self.displayTitle = displayTitle
        self.titleSource = titleSource
        self.frontMatterFormat = frontMatterFormat
        self.fields = fields
        self.fileFacts = fileFacts
    }

    public static let empty = DocumentMetadataInspection(
        displayTitle: "Untitled",
        titleSource: .fileName,
        frontMatterFormat: nil,
        fields: [],
        fileFacts: []
    )
}

public enum DocumentTitleSource: String, Equatable, Sendable {
    case frontMatter
    case firstHeading
    case fileName
}

public struct MetadataField: Equatable, Identifiable, Sendable {
    public let id: String
    public let key: String
    public let label: String
    public let value: String
    public let source: MetadataFieldSource
    public let isStandard: Bool

    public init(
        key: String,
        label: String,
        value: String,
        source: MetadataFieldSource,
        isStandard: Bool
    ) {
        self.key = key
        self.label = label
        self.value = value
        self.source = source
        self.isStandard = isStandard
        self.id = "\(source.rawValue):\(key)"
    }
}

public enum MetadataFieldSource: String, Equatable, Sendable {
    case frontMatter
    case file
}

public struct RichDocumentStatistics: Equatable, Sendable {
    public let words: Int
    public let characters: Int
    public let lines: Int
    public let readingTimeMinutes: Int
    public let headingCount: Int
    public let headingLevels: [Int: Int]
    public let paragraphCount: Int
    public let linkCount: Int
    public let imageCount: Int
    public let missingReferenceCount: Int
    public let codeBlockCount: Int
    public let tableCount: Int
    public let footnoteCount: Int
    public let calloutCount: Int
    public let mermaidDiagramCount: Int
    public let mathExpressionCount: Int
    public let wideTableCandidateCount: Int
    public let diagnosticCount: Int

    public init(
        words: Int,
        characters: Int,
        lines: Int,
        readingTimeMinutes: Int,
        headingCount: Int,
        headingLevels: [Int: Int],
        paragraphCount: Int,
        linkCount: Int,
        imageCount: Int,
        missingReferenceCount: Int,
        codeBlockCount: Int,
        tableCount: Int,
        footnoteCount: Int,
        calloutCount: Int,
        mermaidDiagramCount: Int,
        mathExpressionCount: Int,
        wideTableCandidateCount: Int,
        diagnosticCount: Int
    ) {
        self.words = words
        self.characters = characters
        self.lines = lines
        self.readingTimeMinutes = readingTimeMinutes
        self.headingCount = headingCount
        self.headingLevels = headingLevels
        self.paragraphCount = paragraphCount
        self.linkCount = linkCount
        self.imageCount = imageCount
        self.missingReferenceCount = missingReferenceCount
        self.codeBlockCount = codeBlockCount
        self.tableCount = tableCount
        self.footnoteCount = footnoteCount
        self.calloutCount = calloutCount
        self.mermaidDiagramCount = mermaidDiagramCount
        self.mathExpressionCount = mathExpressionCount
        self.wideTableCandidateCount = wideTableCandidateCount
        self.diagnosticCount = diagnosticCount
    }

    public static let empty = RichDocumentStatistics(
        words: 0,
        characters: 0,
        lines: 0,
        readingTimeMinutes: 0,
        headingCount: 0,
        headingLevels: [:],
        paragraphCount: 0,
        linkCount: 0,
        imageCount: 0,
        missingReferenceCount: 0,
        codeBlockCount: 0,
        tableCount: 0,
        footnoteCount: 0,
        calloutCount: 0,
        mermaidDiagramCount: 0,
        mathExpressionCount: 0,
        wideTableCandidateCount: 0,
        diagnosticCount: 0
    )
}

public struct DocumentLinkReference: Equatable, Identifiable, Sendable {
    public let id: String
    public let text: String
    public let target: String
    public let kind: DocumentReferenceKind
    public let status: DocumentReferenceStatus
    public let diagnostics: [RenderDiagnostic]

    public init(
        id: String,
        text: String,
        target: String,
        kind: DocumentReferenceKind,
        status: DocumentReferenceStatus,
        diagnostics: [RenderDiagnostic]
    ) {
        self.id = id
        self.text = text
        self.target = target
        self.kind = kind
        self.status = status
        self.diagnostics = diagnostics
    }
}

public enum DocumentReferenceKind: String, Equatable, Sendable {
    case sameDocumentHeading
    case localFile
    case remoteURL
    case email
    case telephone
    case unsupportedScheme
    case malformed
    case unknown
}

public enum DocumentReferenceStatus: String, Equatable, Sendable {
    case valid
    case warning
    case skipped
    case missing
    case malformed
    case unsupported
    case blocked
}

public struct DocumentAssetReference: Equatable, Identifiable, Sendable {
    public let id: String
    public let source: String
    public let altText: String
    public let resolvedPath: String?
    public let kind: DocumentAssetKind
    public let status: DocumentReferenceStatus
    public let diagnostics: [RenderDiagnostic]

    public init(
        id: String,
        source: String,
        altText: String,
        resolvedPath: String?,
        kind: DocumentAssetKind,
        status: DocumentReferenceStatus,
        diagnostics: [RenderDiagnostic]
    ) {
        self.id = id
        self.source = source
        self.altText = altText
        self.resolvedPath = resolvedPath
        self.kind = kind
        self.status = status
        self.diagnostics = diagnostics
    }
}

public enum DocumentAssetKind: String, Equatable, Sendable {
    case localImage
    case remoteImage
    case dataImage
    case unknown
}

public struct ExportReadinessReport: Equatable, Sendable {
    public let issues: [ExportReadinessIssue]

    public init(issues: [ExportReadinessIssue]) {
        self.issues = issues
    }

    public var isReady: Bool {
        issues.allSatisfy { $0.severity == .info }
    }

    public static let ready = ExportReadinessReport(issues: [])
}

public struct ExportReadinessIssue: Equatable, Identifiable, Sendable {
    public let id: String
    public let severity: ExportReadinessSeverity
    public let title: String
    public let message: String
    public let source: String?

    public init(
        severity: ExportReadinessSeverity,
        title: String,
        message: String,
        source: String?
    ) {
        self.severity = severity
        self.title = title
        self.message = message
        self.source = source
        self.id = "\(severity.rawValue):\(title):\(source ?? message)"
    }
}

public enum ExportReadinessSeverity: String, Equatable, Sendable {
    case info
    case warning
    case error
}

public enum DocumentInspectionBuilder {
    public static func build(document: MarkdownDocument, renderResult: RenderResult) -> DocumentInspectionReport {
        buildReport(document: document, renderResult: renderResult)
    }

    public static func build(document: MarkdownDocument, renderResult: RenderResult? = nil) -> DocumentInspectionReport {
        buildReport(document: document, renderResult: renderResult)
    }

    private static func buildReport(document: MarkdownDocument, renderResult: RenderResult?) -> DocumentInspectionReport {
        let diagnostics = renderResult?.diagnostics ?? []
        let bodyHTML = renderResult?.bodyHTML ?? ""
        let links = buildLinks(from: bodyHTML, diagnostics: diagnostics)
        let assets = buildAssets(from: bodyHTML, document: document, diagnostics: diagnostics)
        let statistics = buildStatistics(
            document: document,
            renderResult: renderResult,
            links: links,
            assets: assets,
            diagnostics: diagnostics
        )
        let exportReadiness = buildExportReadiness(
            diagnostics: diagnostics,
            assets: assets,
            statistics: statistics
        )

        return DocumentInspectionReport(
            metadata: buildMetadata(document: document),
            statistics: statistics,
            links: links,
            assets: assets,
            diagnostics: diagnostics,
            exportReadiness: exportReadiness
        )
    }

    private static func buildMetadata(document: MarkdownDocument) -> DocumentMetadataInspection {
        let standardKeys: Set<String> = ["title", "description", "author", "date", "tags", "slug", "draft", "layout"]
        let fields = document.frontMatter?.values
            .sorted { $0.key < $1.key }
            .map { key, value in
                MetadataField(
                    key: key,
                    label: displayLabel(for: key),
                    value: value,
                    source: .frontMatter,
                    isStandard: standardKeys.contains(key)
                )
            } ?? []

        return DocumentMetadataInspection(
            displayTitle: document.displayTitle,
            titleSource: (document.frontMatter?.title?.isEmpty == false) ? .frontMatter : .fileName,
            frontMatterFormat: document.frontMatter?.format,
            fields: fields,
            fileFacts: fileFacts(for: document)
        )
    }

    private static func fileFacts(for document: MarkdownDocument) -> [MetadataField] {
        let fileExtension = document.sourceURL.pathExtension.isEmpty ? "none" : document.sourceURL.pathExtension
        var fields = [
            MetadataField(key: "fileName", label: "File Name", value: document.displayName, source: .file, isStandard: true),
            MetadataField(key: "fileExtension", label: "File Extension", value: fileExtension, source: .file, isStandard: true),
            MetadataField(key: "fileSize", label: "File Size", value: "\(document.metadata.fileSize) bytes", source: .file, isStandard: true),
            MetadataField(key: "path", label: "Path", value: document.sourceURL.standardizedFileURL.path, source: .file, isStandard: true),
            MetadataField(key: "directory", label: "Directory", value: document.sourceURL.deletingLastPathComponent().standardizedFileURL.path, source: .file, isStandard: true),
            MetadataField(key: "loadedAt", label: "Loaded At", value: formatDate(document.loadedAt), source: .file, isStandard: true)
        ]

        if let createdAt = document.metadata.createdAt {
            fields.append(MetadataField(key: "createdAt", label: "Created At", value: formatDate(createdAt), source: .file, isStandard: true))
        }

        if let modifiedAt = document.metadata.modifiedAt {
            fields.append(MetadataField(key: "modifiedAt", label: "Modified At", value: formatDate(modifiedAt), source: .file, isStandard: true))
        }

        return fields
    }

    private static func buildLinks(from html: String, diagnostics: [RenderDiagnostic]) -> [DocumentLinkReference] {
        let references = LinkReferenceExtractor.linkReferences(from: html)
        return references.map { reference in
            let matchingDiagnostics = diagnostics.filter { $0.source == reference.source }
            let kind = linkKind(for: reference.source, diagnostics: matchingDiagnostics)
            let status = linkStatus(for: reference.source, kind: kind, diagnostics: matchingDiagnostics)

            return DocumentLinkReference(
                id: reference.id,
                text: reference.text,
                target: reference.source,
                kind: kind,
                status: status,
                diagnostics: matchingDiagnostics
            )
        }
    }

    private static func buildAssets(
        from html: String,
        document: MarkdownDocument,
        diagnostics: [RenderDiagnostic]
    ) -> [DocumentAssetReference] {
        imageReferences(from: html).map { reference in
            let matchingDiagnostics = diagnostics.filter { $0.source == reference.source }
            let kind = assetKind(for: reference.source)
            let resolvedURL = resolvedLocalAssetURL(for: reference.source, kind: kind, document: document)
            let status = assetStatus(for: reference, kind: kind, resolvedURL: resolvedURL, diagnostics: matchingDiagnostics)

            return DocumentAssetReference(
                id: "\(reference.occurrenceIndex):\(reference.source)",
                source: reference.source,
                altText: reference.altText,
                resolvedPath: resolvedURL?.path,
                kind: kind,
                status: status,
                diagnostics: matchingDiagnostics
            )
        }
    }

    private static func buildStatistics(
        document: MarkdownDocument,
        renderResult: RenderResult?,
        links: [DocumentLinkReference],
        assets: [DocumentAssetReference],
        diagnostics: [RenderDiagnostic]
    ) -> RichDocumentStatistics {
        let html = renderResult?.bodyHTML ?? ""
        let outline = renderResult?.outline ?? []
        let headingLevels = outline.reduce(into: [Int: Int]()) { counts, item in
            counts[item.level, default: 0] += 1
        }
        let missingReferenceKinds: Set<RenderDiagnosticKind> = [
            .missingLocalImage,
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .unsupportedLinkScheme
        ]

        return RichDocumentStatistics(
            words: document.statistics.wordCount,
            characters: document.statistics.characterCount,
            lines: document.statistics.lineCount,
            readingTimeMinutes: document.statistics.readingTimeMinutes,
            headingCount: outline.count,
            headingLevels: headingLevels,
            paragraphCount: countOccurrences(of: #"<p(?:\s|>)"#, in: html),
            linkCount: links.count,
            imageCount: assets.count,
            missingReferenceCount: diagnostics.filter { missingReferenceKinds.contains($0.kind) }.count,
            codeBlockCount: countFencedCodeBlocks(in: document.bodyText),
            tableCount: countOccurrences(of: #"<table\b"#, in: html),
            footnoteCount: countOccurrences(of: #"data-footnote-ref|class="footnote-ref""#, in: html),
            calloutCount: countOccurrences(of: #"class=["'][^"']*\bom-callout(?:\s|["'])"#, in: html),
            mermaidDiagramCount: countOccurrences(of: #"id="om-mermaid-[0-9]+""#, in: html),
            mathExpressionCount: countOccurrences(of: #"id="om-math-[0-9]+""#, in: html),
            wideTableCandidateCount: countWideTableCandidates(in: document.bodyText),
            diagnosticCount: diagnostics.count
        )
    }

    private static func buildExportReadiness(
        diagnostics: [RenderDiagnostic],
        assets: [DocumentAssetReference],
        statistics: RichDocumentStatistics
    ) -> ExportReadinessReport {
        var issues: [ExportReadinessIssue] = diagnostics.compactMap(issue(for:))

        for asset in assets where asset.kind == .remoteImage && asset.status != .blocked {
            issues.append(
                ExportReadinessIssue(
                    severity: .info,
                    title: "Remote image",
                    message: "Remote image '\(asset.source)' may require network access outside OpenMarked.",
                    source: asset.source
                )
            )
        }

        if statistics.wideTableCandidateCount > 0 {
            issues.append(
                ExportReadinessIssue(
                    severity: .warning,
                    title: "Wide table",
                    message: "\(statistics.wideTableCandidateCount) table row may need print layout review.",
                    source: nil
                )
            )
        }

        return ExportReadinessReport(issues: deduplicatedIssues(issues))
    }

    private static func issue(for diagnostic: RenderDiagnostic) -> ExportReadinessIssue? {
        switch diagnostic.kind {
        case .missingLocalImage:
            return ExportReadinessIssue(severity: .warning, title: "Missing image", message: diagnostic.message, source: diagnostic.source)
        case .missingLocalLink:
            return ExportReadinessIssue(severity: .warning, title: "Missing local link", message: diagnostic.message, source: diagnostic.source)
        case .missingHeadingFragment:
            return ExportReadinessIssue(severity: .warning, title: "Missing heading", message: diagnostic.message, source: diagnostic.source)
        case .malformedLink:
            return ExportReadinessIssue(severity: .warning, title: "Malformed link", message: diagnostic.message, source: diagnostic.source)
        case .unsupportedLinkScheme:
            return ExportReadinessIssue(severity: .warning, title: "Unsupported link", message: diagnostic.message, source: diagnostic.source)
        case .mermaidRenderFailure:
            return ExportReadinessIssue(severity: .warning, title: "Mermaid render failure", message: diagnostic.message, source: diagnostic.source)
        case .mathRenderFailure:
            return ExportReadinessIssue(severity: .warning, title: "Math render failure", message: diagnostic.message, source: diagnostic.source)
        case .richContentDisabled:
            return ExportReadinessIssue(severity: .info, title: "Rich content disabled", message: diagnostic.message, source: diagnostic.source)
        case .malformedGitHubCallout:
            return ExportReadinessIssue(severity: .info, title: "Malformed callout", message: diagnostic.message, source: diagnostic.source)
        case .linkValidationSkipped:
            return ExportReadinessIssue(severity: .info, title: "Link validation skipped", message: diagnostic.message, source: diagnostic.source)
        case .unsupportedExtension, .renderFailure:
            return ExportReadinessIssue(severity: .warning, title: "Render issue", message: diagnostic.message, source: diagnostic.source)
        }
    }

    private static func linkKind(for source: String, diagnostics: [RenderDiagnostic]) -> DocumentReferenceKind {
        if diagnostics.contains(where: { $0.kind == .malformedLink }) {
            return .malformed
        }
        if diagnostics.contains(where: { $0.kind == .unsupportedLinkScheme }) {
            return .unsupportedScheme
        }
        if source.hasPrefix("#") {
            return .sameDocumentHeading
        }
        guard let components = URLComponents(string: source) else {
            return .malformed
        }
        guard let scheme = components.scheme?.lowercased() else {
            return .localFile
        }

        switch scheme {
        case "http", "https":
            return .remoteURL
        case "mailto":
            return .email
        case "tel":
            return .telephone
        case "file":
            return .localFile
        default:
            return .unsupportedScheme
        }
    }

    private static func linkStatus(
        for source: String,
        kind: DocumentReferenceKind,
        diagnostics: [RenderDiagnostic]
    ) -> DocumentReferenceStatus {
        if diagnostics.contains(where: { $0.kind == .missingLocalLink || $0.kind == .missingHeadingFragment }) {
            return .missing
        }
        if diagnostics.contains(where: { $0.kind == .malformedLink }) {
            return .malformed
        }
        if diagnostics.contains(where: { $0.kind == .unsupportedLinkScheme }) {
            return .unsupported
        }
        if diagnostics.contains(where: { $0.kind == .linkValidationSkipped }) {
            return .skipped
        }
        if kind == .remoteURL {
            return isValidRemoteURL(source) ? .skipped : .malformed
        }
        return .valid
    }

    private static func assetKind(for source: String) -> DocumentAssetKind {
        if source.hasPrefix("data:") {
            return .dataImage
        }
        guard let components = URLComponents(string: source), let scheme = components.scheme?.lowercased() else {
            return .localImage
        }

        switch scheme {
        case "http", "https":
            return .remoteImage
        case "file":
            return .localImage
        default:
            return .unknown
        }
    }

    private static func assetStatus(
        for reference: ImageReference,
        kind: DocumentAssetKind,
        resolvedURL: URL?,
        diagnostics: [RenderDiagnostic]
    ) -> DocumentReferenceStatus {
        if reference.isBlocked {
            return .blocked
        }
        if diagnostics.contains(where: { $0.kind == .missingLocalImage || $0.kind == .missingLocalLink }) {
            return .missing
        }
        if kind == .remoteImage {
            return .skipped
        }
        if kind == .dataImage {
            return .valid
        }
        guard kind == .localImage else {
            return .unsupported
        }
        guard let resolvedURL else {
            return .malformed
        }
        return FileManager.default.fileExists(atPath: resolvedURL.path) ? .valid : .missing
    }

    private static func resolvedLocalAssetURL(
        for source: String,
        kind: DocumentAssetKind,
        document: MarkdownDocument
    ) -> URL? {
        guard kind == .localImage else {
            return nil
        }
        return LocalAssetReferenceExtractor.localFileURL(
            for: source,
            relativeTo: document.sourceURL.deletingLastPathComponent()
        )
    }

    private struct ImageReference: Equatable {
        let source: String
        let altText: String
        let occurrenceIndex: Int
        let isBlocked: Bool
    }

    private static func imageReferences(from html: String) -> [ImageReference] {
        let pattern = #"<img\b[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsHTML = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)).enumerated().compactMap { index, match in
            guard let tagRange = Range(match.range(at: 0), in: html) else {
                return nil
            }

            let tag = String(html[tagRange])
            let blockedSource = attributeValue(named: "data-openmarked-blocked-src", in: tag)
            let source = blockedSource ?? attributeValue(named: "src", in: tag)
            guard let source, !source.isEmpty else {
                return nil
            }

            return ImageReference(
                source: source,
                altText: attributeValue(named: "alt", in: tag) ?? "",
                occurrenceIndex: index,
                isBlocked: blockedSource != nil
            )
        }
    }

    private static func attributeValue(named name: String, in tag: String) -> String? {
        let pattern = #"\b\#(name)\s*=\s*(["'])(.*?)\1"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let nsTag = tag as NSString
        guard
            let match = regex.firstMatch(in: tag, range: NSRange(location: 0, length: nsTag.length)),
            let valueRange = Range(match.range(at: 2), in: tag)
        else {
            return nil
        }

        return HTMLUtilities.decodeEntities(in: String(tag[valueRange]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func displayLabel(for key: String) -> String {
        key
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func countOccurrences(of pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return 0
        }
        return regex.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }

    private static func countFencedCodeBlocks(in markdown: String) -> Int {
        let fenceLineCount = countOccurrences(of: #"(?m)^\s*(?:```|~~~)"#, in: markdown)
        return fenceLineCount / 2
    }

    private static func countWideTableCandidates(in markdown: String) -> Int {
        markdown
            .split(whereSeparator: \.isNewline)
            .filter { line in
                let pipeCount = line.reduce(into: 0) { count, character in
                    if character == Character("|") {
                        count += 1
                    }
                }
                return pipeCount >= 8 || (pipeCount >= 4 && line.count > 120)
            }
            .count
    }

    private static func isValidRemoteURL(_ source: String) -> Bool {
        guard
            let components = URLComponents(string: source),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            let host = components.host,
            !host.isEmpty
        else {
            return false
        }
        return true
    }

    private static func deduplicatedIssues(_ issues: [ExportReadinessIssue]) -> [ExportReadinessIssue] {
        var seenIDs = Set<String>()
        return issues.filter { issue in
            seenIDs.insert(issue.id).inserted
        }
    }
}
