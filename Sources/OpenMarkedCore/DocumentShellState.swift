import Foundation

public struct OpenedDocument: Equatable, Identifiable {
    public let id: String
    public let url: URL
    public let displayName: String
    public let fileExtension: String
    public let openedAt: Date
    public let markdownDocument: MarkdownDocument?

    public init(url: URL, openedAt: Date = Date(), markdownDocument: MarkdownDocument? = nil) {
        self.url = url
        self.displayName = markdownDocument?.displayTitle ?? (url.lastPathComponent.isEmpty ? "Untitled" : url.lastPathComponent)
        self.fileExtension = url.pathExtension.lowercased()
        self.openedAt = openedAt
        self.markdownDocument = markdownDocument
        self.id = markdownDocument?.id ?? url.standardizedFileURL.path
    }

    public init(markdownDocument: MarkdownDocument, openedAt: Date = Date()) {
        self.init(url: markdownDocument.sourceURL, openedAt: openedAt, markdownDocument: markdownDocument)
    }
}

public struct PendingDocument: Equatable {
    public let url: URL
    public let displayName: String

    public init(url: URL) {
        self.url = url
        self.displayName = url.lastPathComponent.isEmpty ? "Document" : url.lastPathComponent
    }
}

public enum DocumentOpenErrorKind: String, Equatable, Sendable {
    case unsupportedFileType
    case missingFile
    case directory
    case unreadable
    case encodingFailure
    case bookmarkCreationFailure
    case bookmarkResolutionFailure
    case noSupportedFiles
}

public struct DocumentOpenError: Error, Equatable, LocalizedError, Sendable {
    public let kind: DocumentOpenErrorKind
    public let url: URL?
    public let message: String

    public init(kind: DocumentOpenErrorKind, url: URL? = nil, message: String) {
        self.kind = kind
        self.url = url
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

public enum DocumentOpenValidator {
    public static func validate(url: URL, fileManager: FileManager = .default, openedAt: Date = Date()) throws -> OpenedDocument {
        let fileExtension = url.pathExtension.lowercased()
        guard AppInfo.supportsFileExtension(fileExtension) else {
            throw DocumentOpenError(
                kind: .unsupportedFileType,
                url: url,
                message: "\(url.lastPathComponent) is not a supported Markdown or text file."
            )
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw DocumentOpenError(
                kind: .missingFile,
                url: url,
                message: "\(url.lastPathComponent) could not be found."
            )
        }

        guard !isDirectory.boolValue else {
            throw DocumentOpenError(
                kind: .directory,
                url: url,
                message: "\(url.lastPathComponent) is a folder. OpenMarked MVP accepts individual Markdown files."
            )
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            throw DocumentOpenError(
                kind: .unreadable,
                url: url,
                message: "\(url.lastPathComponent) is not readable."
            )
        }

        return OpenedDocument(url: url, openedAt: openedAt)
    }
}

public enum WindowContentState: Equatable {
    case empty
    case loading(PendingDocument)
    case loaded(OpenedDocument)
    case error(DocumentOpenError)
}

public enum PreviewShellState: Equatable {
    case idle
    case loading
    case rendered(RenderResult)
    case placeholder
    case error(PreviewError)
}

public enum PreviewErrorKind: String, Equatable, Sendable {
    case documentOpen
    case render
}

public struct PreviewError: Error, Equatable, LocalizedError, Sendable {
    public let kind: PreviewErrorKind
    public let message: String

    public init(kind: PreviewErrorKind, message: String) {
        self.kind = kind
        self.message = message
    }

    public init(documentOpenError: DocumentOpenError) {
        self.init(kind: .documentOpen, message: documentOpenError.message)
    }

    public init(error: Error) {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            self.init(kind: .render, message: description)
        } else {
            self.init(kind: .render, message: "OpenMarked could not render the document.")
        }
    }

    public var errorDescription: String? {
        message
    }
}

public struct WindowLayoutState: Equatable {
    public var isOutlineVisible: Bool
    public var selectedThemeID: String
    public var fontScale: Double

    public init(isOutlineVisible: Bool = true, selectedThemeID: String = "default", fontScale: Double = 1.0) {
        self.isOutlineVisible = isOutlineVisible
        self.selectedThemeID = selectedThemeID
        self.fontScale = fontScale
    }
}

extension WindowLayoutState: Codable, Sendable {}

public enum LivePreviewStatus: Equatable, Sendable {
    case inactive
    case watching
    case updating
    case updated(Date)
    case failed(String)
}

public struct PreviewSearchState: Equatable, Sendable {
    public var isVisible: Bool
    public var query: String
    public var matchCount: Int
    public var selectedMatchIndex: Int?

    public init(
        isVisible: Bool = false,
        query: String = "",
        matchCount: Int = 0,
        selectedMatchIndex: Int? = nil
    ) {
        self.isVisible = isVisible
        self.query = query
        self.matchCount = matchCount
        self.selectedMatchIndex = selectedMatchIndex
    }

    public var resultSummary: String {
        guard !query.isEmpty else {
            return ""
        }

        guard matchCount > 0, let selectedMatchIndex else {
            return "No results"
        }

        return "\(selectedMatchIndex) of \(matchCount)"
    }
}

public struct DocumentWindowState: Equatable {
    public var content: WindowContentState
    public var preview: PreviewShellState
    public var layout: WindowLayoutState
    public var livePreview: LivePreviewStatus
    public var search: PreviewSearchState
    public var statusMessage: String

    public init(
        content: WindowContentState = .empty,
        preview: PreviewShellState = .idle,
        layout: WindowLayoutState = WindowLayoutState(),
        livePreview: LivePreviewStatus = .inactive,
        search: PreviewSearchState = PreviewSearchState(),
        statusMessage: String = "No document"
    ) {
        self.content = content
        self.preview = preview
        self.layout = layout
        self.livePreview = livePreview
        self.search = search
        self.statusMessage = statusMessage
    }

    public var currentDocument: OpenedDocument? {
        if case let .loaded(document) = content {
            return document
        }
        return nil
    }

    public var hasDocument: Bool {
        currentDocument != nil
    }

    public var windowTitle: String {
        switch content {
        case .empty:
            return AppInfo.name
        case .loading(let pending):
            return "Opening \(pending.displayName)"
        case .loaded(let document):
            return document.displayName
        case .error:
            return "\(AppInfo.name) Error"
        }
    }

    public var canReloadPreview: Bool {
        hasDocument
    }

    public var canExport: Bool {
        hasDocument
    }

    public var currentMarkdownDocument: MarkdownDocument? {
        currentDocument?.markdownDocument
    }

    public var currentRenderResult: RenderResult? {
        if case let .rendered(result) = preview {
            return result
        }
        return nil
    }

    public mutating func beginOpening(url: URL) {
        content = .loading(PendingDocument(url: url))
        preview = .loading
        livePreview = .inactive
        search = PreviewSearchState()
        statusMessage = "Opening \(url.lastPathComponent)"
    }

    public mutating func finishOpening(document: OpenedDocument) {
        content = .loaded(document)
        preview = .placeholder
        statusMessage = "Opened \(document.displayName)"
    }

    public mutating func beginRendering(documentName: String) {
        preview = .loading
        statusMessage = "Rendering \(documentName)"
    }

    public mutating func finishRendering(_ result: RenderResult) {
        preview = .rendered(result)
        let warningCount = result.diagnostics.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            statusMessage = "Rendered with \(warningCount) warning\(warningCount == 1 ? "" : "s")"
        } else {
            statusMessage = "Rendered"
        }
    }

    public mutating func failRendering(_ error: Error) {
        let previewError = PreviewError(error: error)
        preview = .error(previewError)
        statusMessage = previewError.message
    }

    public mutating func applyRestoredLayout(_ layout: WindowLayoutState) {
        self.layout = layout
    }

    public mutating func failOpening(_ error: DocumentOpenError) {
        content = .error(error)
        preview = .error(PreviewError(documentOpenError: error))
        livePreview = .inactive
        statusMessage = error.message
    }

    public mutating func resetToEmpty() {
        content = .empty
        preview = .idle
        livePreview = .inactive
        search = PreviewSearchState()
        statusMessage = "No document"
    }

    public mutating func toggleOutline() {
        layout.isOutlineVisible.toggle()
        statusMessage = layout.isOutlineVisible ? "Outline shown" : "Outline hidden"
    }

    public mutating func setTheme(id: String) {
        layout.selectedThemeID = id
        statusMessage = "Theme: \(id)"
    }

    public mutating func zoomIn() {
        layout.fontScale = min(2.0, layout.fontScale + 0.1)
        statusMessage = "Zoom: \(Int((layout.fontScale * 100).rounded()))%"
    }

    public mutating func zoomOut() {
        layout.fontScale = max(0.6, layout.fontScale - 0.1)
        statusMessage = "Zoom: \(Int((layout.fontScale * 100).rounded()))%"
    }

    public mutating func resetZoom() {
        layout.fontScale = 1.0
        statusMessage = "Zoom: 100%"
    }

    public mutating func notePlaceholderAction(_ message: String) {
        statusMessage = message
    }

    public mutating func noteLivePreviewWatching() {
        livePreview = .watching
    }

    public mutating func noteLivePreviewInactive() {
        livePreview = .inactive
    }

    public mutating func beginLivePreviewUpdate() {
        livePreview = .updating
    }

    public mutating func finishLivePreviewUpdate(updatedAt: Date = Date()) {
        livePreview = .updated(updatedAt)
    }

    public mutating func failLivePreviewUpdate(_ error: DocumentOpenError) {
        preview = .error(PreviewError(documentOpenError: error))
        livePreview = .failed(error.message)
        statusMessage = error.message
    }

    public mutating func failLivePreviewUpdate(_ error: Error) {
        let previewError = PreviewError(error: error)
        preview = .error(previewError)
        livePreview = .failed(previewError.message)
        statusMessage = previewError.message
    }

    public mutating func showPreviewSearch() {
        search.isVisible = true
    }

    public mutating func hidePreviewSearch() {
        search.isVisible = false
        search.query = ""
        search.matchCount = 0
        search.selectedMatchIndex = nil
    }

    public mutating func updatePreviewSearchQuery(_ query: String) {
        search.isVisible = true
        search.query = query
        search.matchCount = 0
        search.selectedMatchIndex = nil
    }

    public mutating func updatePreviewSearchResult(matchCount: Int, selectedMatchIndex: Int?) {
        search.matchCount = max(0, matchCount)
        if let selectedMatchIndex, selectedMatchIndex > 0, selectedMatchIndex <= matchCount {
            search.selectedMatchIndex = selectedMatchIndex
        } else {
            search.selectedMatchIndex = nil
        }
    }
}
