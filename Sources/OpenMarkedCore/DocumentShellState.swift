import Foundation

public struct OpenedDocument: Equatable, Identifiable {
    public let id: String
    public let url: URL
    public let displayName: String
    public let fileExtension: String
    public let openedAt: Date

    public init(url: URL, openedAt: Date = Date()) {
        self.url = url
        self.displayName = url.lastPathComponent.isEmpty ? "Untitled" : url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.openedAt = openedAt
        self.id = url.standardizedFileURL.path
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
    case placeholder
    case error(DocumentOpenError)
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

public struct DocumentWindowState: Equatable {
    public var content: WindowContentState
    public var preview: PreviewShellState
    public var layout: WindowLayoutState
    public var statusMessage: String

    public init(
        content: WindowContentState = .empty,
        preview: PreviewShellState = .idle,
        layout: WindowLayoutState = WindowLayoutState(),
        statusMessage: String = "No document"
    ) {
        self.content = content
        self.preview = preview
        self.layout = layout
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

    public mutating func beginOpening(url: URL) {
        content = .loading(PendingDocument(url: url))
        preview = .loading
        statusMessage = "Opening \(url.lastPathComponent)"
    }

    public mutating func finishOpening(document: OpenedDocument) {
        content = .loaded(document)
        preview = .placeholder
        statusMessage = "Opened \(document.displayName)"
    }

    public mutating func failOpening(_ error: DocumentOpenError) {
        content = .error(error)
        preview = .error(error)
        statusMessage = error.message
    }

    public mutating func resetToEmpty() {
        content = .empty
        preview = .idle
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
}
