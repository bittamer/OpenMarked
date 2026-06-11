import Foundation
import ImageIO

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

public struct MetadataField: Equatable, Identifiable, Sendable {
    public let id: String
    public let key: String
    public let label: String
    public let value: String
    public let valueKind: MetadataValueKind
    public let tokens: [String]
    public let source: MetadataFieldSource
    public let isStandard: Bool

    public init(
        key: String,
        label: String,
        value: String,
        valueKind: MetadataValueKind = .text,
        tokens: [String] = [],
        source: MetadataFieldSource,
        isStandard: Bool
    ) {
        self.key = key
        self.label = label
        self.value = value
        self.valueKind = valueKind
        self.tokens = tokens
        self.source = source
        self.isStandard = isStandard
        self.id = "\(source.rawValue):\(key)"
    }
}

public enum MetadataValueKind: String, Equatable, Sendable {
    case text
    case list
    case boolean
    case number
    case date
    case object
    case empty
}

public enum MetadataFieldSource: String, Equatable, Sendable {
    case frontMatter
    case file
}

public struct DocumentSectionStatistic: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let level: Int
    public let wordCount: Int
    public let paragraphCount: Int

    public init(
        id: String,
        title: String,
        level: Int,
        wordCount: Int,
        paragraphCount: Int
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.wordCount = wordCount
        self.paragraphCount = paragraphCount
    }
}

public struct RichDocumentStatistics: Equatable, Sendable {
    public let words: Int
    public let characters: Int
    public let lines: Int
    public let readingTimeMinutes: Int
    public let estimatedPageCount: Int
    public let wordsPerMinute: Int
    public let includesFrontMatter: Bool
    public let headingCount: Int
    public let headingLevels: [Int: Int]
    public let sectionStatistics: [DocumentSectionStatistic]
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
        estimatedPageCount: Int = 0,
        wordsPerMinute: Int = DocumentStatisticsOptions.defaultWordsPerMinute,
        includesFrontMatter: Bool = false,
        headingCount: Int,
        headingLevels: [Int: Int],
        sectionStatistics: [DocumentSectionStatistic] = [],
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
        self.estimatedPageCount = estimatedPageCount
        self.wordsPerMinute = wordsPerMinute
        self.includesFrontMatter = includesFrontMatter
        self.headingCount = headingCount
        self.headingLevels = headingLevels
        self.sectionStatistics = sectionStatistics
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

    public var longestSection: DocumentSectionStatistic? {
        sectionStatistics.max { left, right in
            if left.wordCount == right.wordCount {
                return left.title > right.title
            }
            return left.wordCount < right.wordCount
        }
    }

    public static let empty = RichDocumentStatistics(
        words: 0,
        characters: 0,
        lines: 0,
        readingTimeMinutes: 0,
        estimatedPageCount: 0,
        wordsPerMinute: DocumentStatisticsOptions.defaultWordsPerMinute,
        includesFrontMatter: false,
        headingCount: 0,
        headingLevels: [:],
        sectionStatistics: [],
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
    public let resolvedPath: String?
    public let fragment: String?
    public let kind: DocumentReferenceKind
    public let status: DocumentReferenceStatus
    public let diagnostics: [RenderDiagnostic]

    public init(
        id: String,
        text: String,
        target: String,
        resolvedPath: String? = nil,
        fragment: String? = nil,
        kind: DocumentReferenceKind,
        status: DocumentReferenceStatus,
        diagnostics: [RenderDiagnostic]
    ) {
        self.id = id
        self.text = text
        self.target = target
        self.resolvedPath = resolvedPath
        self.fragment = fragment
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
    public let fileInfo: DocumentAssetFileInfo?
    public let kind: DocumentAssetKind
    public let status: DocumentReferenceStatus
    public let diagnostics: [RenderDiagnostic]

    public init(
        id: String,
        source: String,
        altText: String,
        resolvedPath: String?,
        fileInfo: DocumentAssetFileInfo? = nil,
        kind: DocumentAssetKind,
        status: DocumentReferenceStatus,
        diagnostics: [RenderDiagnostic]
    ) {
        self.id = id
        self.source = source
        self.altText = altText
        self.resolvedPath = resolvedPath
        self.fileInfo = fileInfo
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

public struct DocumentAssetFileInfo: Equatable, Sendable {
    public let byteSize: Int64?
    public let pixelWidth: Int?
    public let pixelHeight: Int?

    public init(byteSize: Int64?, pixelWidth: Int?, pixelHeight: Int?) {
        self.byteSize = byteSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    public var hasDimensions: Bool {
        pixelWidth != nil && pixelHeight != nil
    }
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
    public static func build(
        document: MarkdownDocument,
        renderResult: RenderResult,
        statisticsOptions: DocumentStatisticsOptions = .default
    ) -> DocumentInspectionReport {
        buildReport(document: document, renderResult: renderResult, statisticsOptions: statisticsOptions)
    }

    public static func build(
        document: MarkdownDocument,
        renderResult: RenderResult? = nil,
        statisticsOptions: DocumentStatisticsOptions = .default
    ) -> DocumentInspectionReport {
        buildReport(document: document, renderResult: renderResult, statisticsOptions: statisticsOptions)
    }

    private static func buildReport(
        document: MarkdownDocument,
        renderResult: RenderResult?,
        statisticsOptions: DocumentStatisticsOptions
    ) -> DocumentInspectionReport {
        let diagnostics = deduplicatedDiagnostics(document.frontMatterDiagnostics + (renderResult?.diagnostics ?? []))
        let bodyHTML = renderResult?.bodyHTML ?? ""
        let htmlIndex = renderResult?.htmlIndex ?? (bodyHTML.isEmpty ? .empty : RenderedHTMLIndex.build(from: bodyHTML, document: document))
        let diagnosticsBySource = Dictionary(grouping: diagnostics.compactMap { diagnostic -> (String, RenderDiagnostic)? in
            guard let source = diagnostic.source else {
                return nil
            }
            return (source, diagnostic)
        }, by: \.0).mapValues { pairs in pairs.map(\.1) }
        let links = buildLinks(from: htmlIndex, document: document, diagnosticsBySource: diagnosticsBySource)
        let assets = buildAssets(from: htmlIndex, document: document, diagnosticsBySource: diagnosticsBySource)
        let statistics = buildStatistics(
            document: document,
            renderResult: renderResult,
            htmlIndex: htmlIndex,
            links: links,
            assets: assets,
            diagnostics: diagnostics,
            statisticsOptions: statisticsOptions
        )
        let exportReadiness = buildExportReadiness(
            document: document,
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
        let standardKeys = ["title", "description", "author", "date", "tags", "slug", "draft", "layout"]
        let standardKeySet = Set(standardKeys)
        let fields = document.frontMatter?.values
            .sorted { left, right in
                let leftIndex = standardKeys.firstIndex(of: left.key) ?? Int.max
                let rightIndex = standardKeys.firstIndex(of: right.key) ?? Int.max
                if leftIndex == rightIndex {
                    return left.key < right.key
                }
                return leftIndex < rightIndex
            }
            .map { key, value in
                metadataField(
                    key: key,
                    source: .frontMatter,
                    isStandard: standardKeySet.contains(key),
                    value: value
                )
            } ?? []

        return DocumentMetadataInspection(
            displayTitle: document.resolvedTitle,
            titleSource: document.resolvedTitleSource,
            frontMatterFormat: document.frontMatter?.format,
            fields: fields,
            fileFacts: fileFacts(for: document)
        )
    }

    private static func fileFacts(for document: MarkdownDocument) -> [MetadataField] {
        let fileExtension = document.sourceURL.pathExtension.isEmpty ? "none" : document.sourceURL.pathExtension
        var fields = [
            metadataField(key: "title", label: "Title", source: .file, isStandard: true, value: document.resolvedTitle),
            metadataField(key: "titleSource", label: "Title Source", source: .file, isStandard: true, value: titleSourceLabel(document.resolvedTitleSource)),
            MetadataField(key: "fileName", label: "File Name", value: document.displayName, source: .file, isStandard: true),
            MetadataField(key: "documentType", label: "Type", value: document.sourceURL.pathExtension.uppercased(), source: .file, isStandard: true),
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

    private static func metadataField(
        key: String,
        label: String? = nil,
        source: MetadataFieldSource,
        isStandard: Bool,
        value: String
    ) -> MetadataField {
        let normalized = MetadataValueNormalizer.normalize(value)
        return MetadataField(
            key: key,
            label: label ?? displayLabel(for: key),
            value: normalized.value,
            valueKind: normalized.kind,
            tokens: normalized.tokens,
            source: source,
            isStandard: isStandard
        )
    }

    private static func buildLinks(
        from htmlIndex: RenderedHTMLIndex,
        document: MarkdownDocument,
        diagnosticsBySource: [String: [RenderDiagnostic]]
    ) -> [DocumentLinkReference] {
        htmlIndex.links.map { reference in
            let matchingDiagnostics = diagnosticsBySource[reference.source] ?? []
            let kind = linkKind(for: reference.source, diagnostics: matchingDiagnostics)
            let status = linkStatus(for: reference.source, kind: kind, diagnostics: matchingDiagnostics)

            return DocumentLinkReference(
                id: reference.id,
                text: reference.text,
                target: reference.source,
                resolvedPath: resolvedLocalLinkPath(for: reference.source, kind: kind, document: document),
                fragment: linkFragment(for: reference.source),
                kind: kind,
                status: status,
                diagnostics: matchingDiagnostics
            )
        }
    }

    private static func buildAssets(
        from htmlIndex: RenderedHTMLIndex,
        document: MarkdownDocument,
        diagnosticsBySource: [String: [RenderDiagnostic]]
    ) -> [DocumentAssetReference] {
        htmlIndex.images.map { reference in
            let matchingDiagnostics = diagnosticsBySource[reference.source] ?? []
            let kind = assetKind(for: reference.source)
            let resolvedURL = reference.resolvedLocalURL ?? resolvedLocalAssetURL(for: reference.source, kind: kind, document: document)
            let status = assetStatus(for: reference, kind: kind, resolvedURL: resolvedURL, diagnostics: matchingDiagnostics)

            return DocumentAssetReference(
                id: "\(reference.occurrenceIndex):\(reference.source)",
                source: reference.source,
                altText: reference.altText,
                resolvedPath: resolvedURL?.path,
                fileInfo: resolvedURL.flatMap(assetFileInfo),
                kind: kind,
                status: status,
                diagnostics: matchingDiagnostics
            )
        }
    }

    private static func buildStatistics(
        document: MarkdownDocument,
        renderResult: RenderResult?,
        htmlIndex: RenderedHTMLIndex,
        links: [DocumentLinkReference],
        assets: [DocumentAssetReference],
        diagnostics: [RenderDiagnostic],
        statisticsOptions: DocumentStatisticsOptions
    ) -> RichDocumentStatistics {
        let normalizedOptions = statisticsOptions.normalized()
        let baseStatistics = normalizedOptions == .default
            ? document.statistics
            : DocumentStatisticsCalculator.calculate(document: document, options: normalizedOptions)
        let codeBlockCount = countFencedCodeBlocks(in: document.bodyText)
        let outline = renderResult?.outline ?? []
        let headingLevels = outline.reduce(into: [Int: Int]()) { counts, item in
            counts[item.level, default: 0] += 1
        }
        let sectionStatistics = buildSectionStatistics(
            in: document.bodyText,
            outline: outline
        )
        let missingReferenceKinds: Set<RenderDiagnosticKind> = [
            .missingLocalImage,
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .unsupportedLinkScheme
        ]

        return RichDocumentStatistics(
            words: baseStatistics.wordCount,
            characters: baseStatistics.characterCount,
            lines: baseStatistics.lineCount,
            readingTimeMinutes: baseStatistics.readingTimeMinutes,
            estimatedPageCount: estimatedPDFPageCount(
                words: baseStatistics.wordCount,
                imageCount: assets.count,
                tableCount: htmlIndex.tableCount,
                codeBlockCount: codeBlockCount
            ),
            wordsPerMinute: normalizedOptions.wordsPerMinute,
            includesFrontMatter: normalizedOptions.includesFrontMatter,
            headingCount: outline.count,
            headingLevels: headingLevels,
            sectionStatistics: sectionStatistics,
            paragraphCount: htmlIndex.paragraphCount,
            linkCount: links.count,
            imageCount: assets.count,
            missingReferenceCount: diagnostics.filter { missingReferenceKinds.contains($0.kind) }.count,
            codeBlockCount: codeBlockCount,
            tableCount: htmlIndex.tableCount,
            footnoteCount: htmlIndex.footnoteReferenceCount,
            calloutCount: htmlIndex.calloutCount,
            mermaidDiagramCount: htmlIndex.mermaidDiagramCount,
            mathExpressionCount: htmlIndex.mathExpressionCount,
            wideTableCandidateCount: countWideTableCandidates(in: document.bodyText),
            diagnosticCount: diagnostics.count
        )
    }

    private static func buildExportReadiness(
        document: MarkdownDocument,
        diagnostics: [RenderDiagnostic],
        assets: [DocumentAssetReference],
        statistics: RichDocumentStatistics
    ) -> ExportReadinessReport {
        var issues: [ExportReadinessIssue] = diagnostics.compactMap(issue(for:))

        if document.resolvedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                ExportReadinessIssue(
                    severity: .warning,
                    title: "Empty title",
                    message: "Exports work best with a non-empty document title.",
                    source: nil
                )
            )
        }

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

        for asset in assets where asset.kind == .remoteImage && asset.status == .blocked {
            issues.append(
                ExportReadinessIssue(
                    severity: .warning,
                    title: "Remote image blocked",
                    message: "Remote image '\(asset.source)' is blocked by the current content setting.",
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

        if statistics.estimatedPageCount > 1 {
            issues.append(
                ExportReadinessIssue(
                    severity: .info,
                    title: "Multi-page export",
                    message: "Estimated \(statistics.estimatedPageCount) PDF pages. Review page breaks in Print or PDF export.",
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
        case .malformedFrontMatter:
            return ExportReadinessIssue(severity: .warning, title: "Malformed front matter", message: diagnostic.message, source: diagnostic.source)
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
        for reference: RenderedImageReference,
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

    private static func resolvedLocalLinkPath(
        for source: String,
        kind: DocumentReferenceKind,
        document: MarkdownDocument
    ) -> String? {
        guard kind == .localFile else {
            return nil
        }

        return LocalAssetReferenceExtractor.localFileURL(
            for: source,
            relativeTo: document.sourceURL.deletingLastPathComponent()
        )?
        .standardizedFileURL
        .path
    }

    private static func linkFragment(for source: String) -> String? {
        if source.hasPrefix("#") {
            return String(source.dropFirst()).removingPercentEncoding
        }

        return URLComponents(string: source)?.fragment?.removingPercentEncoding
    }

    private static func assetFileInfo(for url: URL) -> DocumentAssetFileInfo? {
        guard let metadata = ImageAssetMetadataCache.shared.metadata(for: url) else {
            return nil
        }

        return DocumentAssetFileInfo(
            byteSize: metadata.byteSize,
            pixelWidth: metadata.pixelWidth,
            pixelHeight: metadata.pixelHeight
        )
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

    private static func titleSourceLabel(_ source: DocumentTitleSource) -> String {
        switch source {
        case .frontMatter:
            return "Front matter"
        case .firstHeading:
            return "First heading"
        case .fileName:
            return "File name"
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func countFencedCodeBlocks(in markdown: String) -> Int {
        markdown.split(whereSeparator: \.isNewline).filter { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            return trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
        }.count / 2
    }

    private static func countWideTableCandidates(in markdown: String) -> Int {
        markdown.split(whereSeparator: \.isNewline).filter { line in
            let pipeCount = line.reduce(0) { $1 == "|" ? $0 + 1 : $0 }
            return pipeCount >= 8 || (pipeCount >= 4 && line.count > 120)
        }.count
    }

    private static func buildSectionStatistics(
        in markdown: String,
        outline: [OutlineItem]
    ) -> [DocumentSectionStatistic] {
        let headingIndex = MarkdownHeadingScanner.scan(markdown)
        guard !headingIndex.occurrences.isEmpty else {
            return []
        }

        let lines = markdown.components(separatedBy: "\n")
        let occurrences = headingIndex.occurrences
        return occurrences.indices.map { index in
            let occurrence = occurrences[index]
            let outlineItem = index < outline.count ? outline[index] : occurrence.item
            let outlineTitle = outlineItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextHeadingLine = index + 1 < occurrences.count ? occurrences[index + 1].lineIndex : lines.count
            let sectionStart = min(occurrence.contentStartLineIndex, lines.count)
            let sectionEnd = min(max(nextHeadingLine, sectionStart), lines.count)
            let sectionLines = lines[sectionStart..<sectionEnd]

            return DocumentSectionStatistic(
                id: outlineItem.id,
                title: outlineTitle.isEmpty ? occurrence.item.title : outlineTitle,
                level: outlineItem.level,
                wordCount: DocumentStatisticsCalculator.wordCount(in: sectionLines.joined(separator: "\n")),
                paragraphCount: countMarkdownParagraphs(in: sectionLines)
            )
        }
    }

    private static func countMarkdownParagraphs(in lines: ArraySlice<String>) -> Int {
        var count = 0
        var isInParagraph = false
        var isInFence = false

        func flushParagraph() {
            if isInParagraph {
                count += 1
                isInParagraph = false
            }
        }

        for rawLine in lines {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else {
                flushParagraph()
                continue
            }

            if isFenceLine(trimmedLine) {
                flushParagraph()
                isInFence.toggle()
                continue
            }

            if isInFence || isNonParagraphBlock(trimmedLine) {
                flushParagraph()
                continue
            }

            isInParagraph = true
        }

        flushParagraph()
        return count
    }

    private static func isNonParagraphBlock(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("|")
            || trimmedLine.hasPrefix("<")
            || trimmedLine == "---"
            || trimmedLine == "***"
            || MarkdownHeadingScanner.containsSingleLineHeading(trimmedLine)
    }

    private static func isFenceLine(_ trimmedLine: String) -> Bool {
        trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~")
    }

    private static func estimatedPDFPageCount(
        words: Int,
        imageCount: Int,
        tableCount: Int,
        codeBlockCount: Int
    ) -> Int {
        let weightedWords = Double(words + (imageCount * 120) + (tableCount * 80) + (codeBlockCount * 60))
        guard weightedWords > 0 else {
            return 0
        }
        return max(1, Int(ceil(weightedWords / 500.0)))
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

    private static func deduplicatedDiagnostics(_ diagnostics: [RenderDiagnostic]) -> [RenderDiagnostic] {
        var seenIDs = Set<String>()
        return diagnostics.filter { diagnostic in
            seenIDs.insert(diagnostic.id).inserted
        }
    }
}

private enum MetadataValueNormalizer {
    struct Result: Equatable {
        let value: String
        let kind: MetadataValueKind
        let tokens: [String]
    }

    static func normalize(_ rawValue: String) -> Result {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Result(value: "Empty", kind: .empty, tokens: [])
        }

        if let listItems = listItems(from: trimmed) {
            return Result(value: listItems.joined(separator: ", "), kind: .list, tokens: listItems)
        }

        let lowercased = trimmed.lowercased()
        if ["true", "false", "yes", "no"].contains(lowercased) {
            return Result(value: lowercased, kind: .boolean, tokens: [])
        }

        if isNumber(trimmed) {
            return Result(value: trimmed, kind: .number, tokens: [])
        }

        if isDateLike(trimmed) {
            return Result(value: trimmed, kind: .date, tokens: [])
        }

        if isObjectLike(trimmed) {
            return Result(value: compactWhitespace(trimmed), kind: .object, tokens: [])
        }

        return Result(value: unquoted(trimmed), kind: .text, tokens: [])
    }

    private static func listItems(from value: String) -> [String]? {
        guard value.hasPrefix("[") && value.hasSuffix("]") else {
            return nil
        }

        let inner = value.dropFirst().dropLast()
        let items = inner
            .split(separator: ",")
            .map { unquoted($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }

        return items.isEmpty ? nil : items
    }

    private static func isNumber(_ value: String) -> Bool {
        Double(value) != nil
    }

    private static func isDateLike(_ value: String) -> Bool {
        value.range(
            of: #"^\d{4}-\d{2}-\d{2}(?:[T ][0-9:.+-Z]*)?$"#,
            options: .regularExpression
        ) != nil
    }

    private static func isObjectLike(_ value: String) -> Bool {
        (value.hasPrefix("{") && value.hasSuffix("}")) || value.contains(";")
    }

    private static func compactWhitespace(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func unquoted(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}
