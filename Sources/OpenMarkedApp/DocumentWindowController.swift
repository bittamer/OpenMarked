import AppKit
import Foundation
import OpenMarkedCore

@MainActor
final class DocumentWindowController: ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var state = DocumentWindowState()
    @Published private(set) var previewNavigationRequest: PreviewNavigationRequest?

    private let stateStore = DocumentWindowStateStore.shared
    private let renderer: MarkdownRenderer = CMarkGFMRenderer()
    private var sourceWatcher: FileSystemWatcher?
    private var assetWatchers: [URL: FileSystemWatcher] = [:]

    weak var window: NSWindow? {
        didSet {
            updateWindowTitle()
        }
    }

    var shouldReplaceWithOpenedDocument: Bool {
        if case .empty = state.content {
            return true
        }
        return false
    }

    func open(url: URL) {
        stopLivePreview()
        state.beginOpening(url: url)
        updateWindowTitle()

        do {
            let markdownDocument = try MarkdownDocumentLoader.load(url: url)
            let document = OpenedDocument(markdownDocument: markdownDocument)
            state.finishOpening(document: document)
            if let restoredState = stateStore.restore(forDocumentID: markdownDocument.id) {
                state.applyRestoredLayout(restoredState.layout)
            }
            render(markdownDocument)
            startSourceWatcher(for: markdownDocument)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            persistCurrentWindowState()
        } catch let error as DocumentOpenError {
            state.failOpening(error)
        } catch {
            state.failOpening(
                DocumentOpenError(
                    kind: .unreadable,
                    url: url,
                    message: "\(url.lastPathComponent) could not be opened."
                )
            )
        }

        updateWindowTitle()
    }

    func close() {
        persistCurrentWindowState()
        stopLivePreview()
    }

    func showNoSupportedFilesError() {
        stopLivePreview()
        state.failOpening(
            DocumentOpenError(
                kind: .noSupportedFiles,
                message: "No supported Markdown or text files were selected."
            )
        )
        updateWindowTitle()
    }

    func reloadPreview() {
        guard let markdownDocument = state.currentMarkdownDocument else {
            return
        }

        do {
            let reloadedDocument = try MarkdownDocumentLoader.load(url: markdownDocument.sourceURL)
            let openedDocument = OpenedDocument(markdownDocument: reloadedDocument)
            state.finishOpening(document: openedDocument)
            render(reloadedDocument)
            startSourceWatcher(for: reloadedDocument)
            persistCurrentWindowState()
        } catch let error as DocumentOpenError {
            stopLivePreview()
            state.failOpening(error)
        } catch {
            state.failRendering(error)
        }
    }

    func toggleOutline() {
        state.toggleOutline()
        persistCurrentWindowState()
    }

    func setTheme(id: String) {
        let theme = PreviewThemeStore.theme(id: id)
        state.setTheme(id: theme.id)
        if let markdownDocument = state.currentMarkdownDocument {
            render(markdownDocument)
        }
        persistCurrentWindowState()
    }

    func zoomIn() {
        state.zoomIn()
        if let markdownDocument = state.currentMarkdownDocument {
            render(markdownDocument)
        }
        persistCurrentWindowState()
    }

    func zoomOut() {
        state.zoomOut()
        if let markdownDocument = state.currentMarkdownDocument {
            render(markdownDocument)
        }
        persistCurrentWindowState()
    }

    func resetZoom() {
        state.resetZoom()
        if let markdownDocument = state.currentMarkdownDocument {
            render(markdownDocument)
        }
        persistCurrentWindowState()
    }

    func exportHTMLPlaceholder() {
        guard state.canExport else {
            return
        }
        state.notePlaceholderAction("HTML export lands in Phase 8")
    }

    func exportPDFPlaceholder() {
        guard state.canExport else {
            return
        }
        state.notePlaceholderAction("PDF export lands in Phase 8")
    }

    func printPlaceholder() {
        guard state.canExport else {
            return
        }
        state.notePlaceholderAction("Print support lands in Phase 8")
    }

    func searchPlaceholder() {
        guard state.hasDocument else {
            return
        }
        state.notePlaceholderAction("Search lands in Phase 7")
    }

    func helpPlaceholder() {
        state.notePlaceholderAction("Help documentation lands after the core MVP")
    }

    func updateWindowTitle() {
        window?.title = state.windowTitle
    }

    func scrollToOutlineItem(_ item: OutlineItem) {
        previewNavigationRequest = PreviewNavigationRequest(elementID: item.id)
        state.notePlaceholderAction("Jumped to \(item.title)")
    }

    func updatePreviewStatus(_ message: String) {
        state.notePlaceholderAction(message)
    }

    func persistCurrentWindowState() {
        guard let markdownDocument = state.currentMarkdownDocument else {
            return
        }

        stateStore.save(
            document: markdownDocument,
            layout: state.layout,
            frame: window.map {
                DocumentWindowFrame(
                    x: Double($0.frame.origin.x),
                    y: Double($0.frame.origin.y),
                    width: Double($0.frame.size.width),
                    height: Double($0.frame.size.height)
                )
            }
        )
    }

    private func render(_ markdownDocument: MarkdownDocument) {
        state.beginRendering(documentName: markdownDocument.displayName)

        do {
            let result = try renderer.render(
                RenderRequest(
                    document: markdownDocument,
                    theme: PreviewThemeStore.theme(id: state.layout.selectedThemeID),
                    fontScale: state.layout.fontScale
                )
            )
            state.finishRendering(result)
            updateAssetWatchers(from: result, document: markdownDocument)
        } catch {
            state.failRendering(error)
        }
    }

    private func startSourceWatcher(for markdownDocument: MarkdownDocument, markWatching: Bool = true) {
        sourceWatcher?.stop()
        let watcher = FileSystemWatcher(url: markdownDocument.sourceURL) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleSourceFileEvent(event)
            }
        }
        watcher.start()
        sourceWatcher = watcher
        if markWatching {
            state.noteLivePreviewWatching()
        }
    }

    private func updateAssetWatchers(from renderResult: RenderResult, document: MarkdownDocument) {
        let sourcePath = document.sourceURL.standardizedFileURL.path
        let assetURLs = Set(
            LocalAssetReferenceExtractor
                .imageURLs(from: renderResult.bodyHTML, document: document)
                .map(\.standardizedFileURL)
                .filter { $0.path != sourcePath }
        )

        for watchedURL in Set(assetWatchers.keys).subtracting(assetURLs) {
            assetWatchers[watchedURL]?.stop()
            assetWatchers.removeValue(forKey: watchedURL)
        }

        for assetURL in assetURLs.subtracting(Set(assetWatchers.keys)) {
            let watcher = FileSystemWatcher(url: assetURL) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleAssetFileEvent(event)
                }
            }
            watcher.start()
            assetWatchers[assetURL] = watcher
        }
    }

    private func stopLivePreview() {
        sourceWatcher?.stop()
        sourceWatcher = nil

        for watcher in assetWatchers.values {
            watcher.stop()
        }
        assetWatchers.removeAll()
    }

    private func handleSourceFileEvent(_ event: FileWatchEvent) {
        guard let markdownDocument = state.currentMarkdownDocument,
              markdownDocument.sourceURL.standardizedFileURL.path == event.url.standardizedFileURL.path else {
            return
        }

        reloadForLivePreview(forceRender: false)
    }

    private func handleAssetFileEvent(_ event: FileWatchEvent) {
        guard assetWatchers[event.url.standardizedFileURL] != nil else {
            return
        }

        reloadForLivePreview(forceRender: true)
    }

    private func reloadForLivePreview(forceRender: Bool) {
        guard let currentDocument = state.currentDocument,
              let currentMarkdownDocument = currentDocument.markdownDocument else {
            return
        }

        state.beginLivePreviewUpdate()

        do {
            let reloadedDocument = try MarkdownDocumentLoader.load(url: currentMarkdownDocument.sourceURL)
            let sourceTextChanged = reloadedDocument.sourceText != currentMarkdownDocument.sourceText
            guard forceRender || sourceTextChanged else {
                state.noteLivePreviewWatching()
                return
            }

            state.finishOpening(document: OpenedDocument(markdownDocument: reloadedDocument, openedAt: currentDocument.openedAt))
            render(reloadedDocument)
            state.finishLivePreviewUpdate()
            startSourceWatcher(for: reloadedDocument, markWatching: false)
            persistCurrentWindowState()
        } catch let error as DocumentOpenError {
            state.failLivePreviewUpdate(error)
        } catch {
            state.failLivePreviewUpdate(error)
        }
    }
}
