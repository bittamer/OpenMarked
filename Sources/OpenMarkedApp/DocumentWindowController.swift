import AppKit
import Foundation
import OpenMarkedCore
import UniformTypeIdentifiers

@MainActor
final class DocumentWindowController: ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var state = DocumentWindowState()
    @Published private(set) var previewNavigationRequest: PreviewNavigationRequest?
    @Published private(set) var previewSearchRequest: PreviewSearchRequest?

    private let stateStore = DocumentWindowStateStore.shared
    private let renderer: MarkdownRenderer = CMarkGFMRenderer()
    private var sourceWatcher: FileSystemWatcher?
    private var assetWatchers: [URL: FileSystemWatcher] = [:]
    private var activePrintExporter: WebKitPrintExporter?

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
        previewNavigationRequest = nil
        previewSearchRequest = PreviewSearchRequest(action: .clear)
        state.beginOpening(url: url)
        updateWindowTitle()

        do {
            let markdownDocument = try MarkdownDocumentLoader.load(url: url)
            let document = OpenedDocument(markdownDocument: markdownDocument)
            state.finishOpening(document: document)
            if let restoredState = stateStore.restore(forDocumentID: markdownDocument.id) {
                state.applyRestoredLayout(restoredState.layout)
            } else {
                state.applyRestoredLayout(AppController.shared.settings.defaultLayout)
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

    func exportHTML() {
        guard let context = currentExportContext() else {
            presentExportError(.missingRenderedDocument)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export HTML"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = suggestedExportFilename(for: context.document, extension: "html")

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            let html = HTMLExportDocumentBuilder.standaloneHTML(
                renderResult: context.renderResult,
                document: context.document,
                options: HTMLExportOptions(
                    embedsLocalImages: AppController.shared.settings.embedsLocalImagesInHTMLExport,
                    embedsThemeCSS: AppController.shared.settings.embedsCSSInHTMLExport
                )
            )
            try HTMLExportWriter.write(html: html, to: destinationURL)
            state.notePlaceholderAction("Exported HTML to \(destinationURL.lastPathComponent)")
        } catch let error as ExportError {
            presentExportError(error)
        } catch {
            presentExportError(.writeFailed(path: destinationURL.path, reason: error.localizedDescription))
        }
    }

    func copyRenderedHTML() {
        guard let renderResult = state.currentRenderResult else {
            presentExportError(.missingRenderedDocument)
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(renderResult.bodyHTML, forType: .html)
        NSPasteboard.general.setString(renderResult.bodyHTML, forType: .string)
        state.notePlaceholderAction("Copied rendered HTML")
    }

    func exportPDF() {
        guard let context = currentExportContext() else {
            presentExportError(.missingRenderedDocument)
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export PDF"
        panel.prompt = "Export"
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedExportFilename(for: context.document, extension: "pdf")

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        let html = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: context.renderResult,
            document: context.document
        )
        let exporter = WebKitPrintExporter()
        activePrintExporter = exporter
        state.notePlaceholderAction("Exporting PDF")
        exporter.exportPDF(
            html: html,
            baseURL: context.document.sourceURL.deletingLastPathComponent(),
            richMarkdownState: context.renderResult.richMarkdownState,
            destinationURL: destinationURL
        ) { [weak self] result in
            guard let self else {
                return
            }

            self.activePrintExporter = nil
            switch result {
            case .success:
                self.state.notePlaceholderAction("Exported PDF to \(destinationURL.lastPathComponent)")
            case .failure(let error):
                self.presentExportError(error)
            }
        }
    }

    func printDocument() {
        guard let context = currentExportContext() else {
            presentExportError(.missingRenderedDocument)
            return
        }

        let html = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: context.renderResult,
            document: context.document
        )
        let exporter = WebKitPrintExporter()
        activePrintExporter = exporter
        state.notePlaceholderAction("Preparing print")
        exporter.print(
            html: html,
            baseURL: context.document.sourceURL.deletingLastPathComponent(),
            richMarkdownState: context.renderResult.richMarkdownState
        ) { [weak self] result in
            guard let self else {
                return
            }

            self.activePrintExporter = nil
            switch result {
            case .success:
                self.state.notePlaceholderAction("Print complete")
            case .failure:
                self.state.notePlaceholderAction("Print cancelled")
            }
        }
    }

    func showSearch() {
        guard state.hasDocument else {
            return
        }
        state.showPreviewSearch()
        if !state.search.query.isEmpty {
            previewSearchRequest = PreviewSearchRequest(action: .setQuery(state.search.query))
        }
    }

    func hideSearch() {
        state.hidePreviewSearch()
        previewSearchRequest = PreviewSearchRequest(action: .clear)
    }

    func updateSearchQuery(_ query: String) {
        state.updatePreviewSearchQuery(query)
        previewSearchRequest = query.isEmpty
            ? PreviewSearchRequest(action: .clear)
            : PreviewSearchRequest(action: .setQuery(query))
    }

    func findNext() {
        guard state.hasDocument else {
            return
        }

        state.showPreviewSearch()
        guard !state.search.query.isEmpty else {
            return
        }

        previewSearchRequest = PreviewSearchRequest(action: .next(state.search.query))
    }

    func findPrevious() {
        guard state.hasDocument else {
            return
        }

        state.showPreviewSearch()
        guard !state.search.query.isEmpty else {
            return
        }

        previewSearchRequest = PreviewSearchRequest(action: .previous(state.search.query))
    }

    func updateSearchResult(_ result: PreviewSearchResult) {
        guard result.query == state.search.query || result.query.isEmpty else {
            return
        }

        state.updatePreviewSearchResult(matchCount: result.matchCount, selectedMatchIndex: result.selectedMatchIndex)
    }

    func revealSourceInFinder() {
        guard let url = currentSourceURL else {
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            state.notePlaceholderAction("Source file is missing")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
        state.notePlaceholderAction("Revealed \(url.lastPathComponent)")
    }

    func openSourceInDefaultEditor() {
        guard let url = currentSourceURL else {
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            state.notePlaceholderAction("Source file is missing")
            return
        }

        NSWorkspace.shared.open(url)
        state.notePlaceholderAction("Opened \(url.lastPathComponent)")
    }

    func copySourcePath() {
        guard let url = currentSourceURL else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
        state.notePlaceholderAction("Copied source path")
    }

    func applySettings(_ settings: ApplicationSettings, previousSettings: ApplicationSettings? = nil) {
        let shouldApplyDefaultLayoutChanges = shouldApplyDefaultLayout(settings, previousSettings: previousSettings)
        if shouldApplyDefaultLayoutChanges {
            var updatedLayout = state.layout
            updatedLayout.selectedThemeID = settings.defaultLayout.selectedThemeID
            updatedLayout.fontScale = settings.defaultLayout.fontScale
            state.applyRestoredLayout(updatedLayout)
        }

        if let markdownDocument = state.currentMarkdownDocument {
            let shouldRefreshPreview = shouldRefreshPreview(
                settings,
                previousSettings: previousSettings,
                defaultLayoutChanged: shouldApplyDefaultLayoutChanges
            )
            let shouldUpdateLivePreview = shouldUpdateLivePreview(settings, previousSettings: previousSettings)

            if shouldRefreshPreview {
                render(markdownDocument)
            }

            if shouldRefreshPreview || shouldUpdateLivePreview {
                if settings.isLivePreviewEnabled {
                    startSourceWatcher(for: markdownDocument)
                } else {
                    stopLivePreview()
                    state.noteLivePreviewInactive()
                }
                persistCurrentWindowState()
            }
        }
    }

    func helpPlaceholder() {
        state.notePlaceholderAction("Help documentation lands after the core MVP")
    }

    func beginRichContentRendering(features: Set<RichMarkdownFeature>) {
        state.beginRichContentRendering(features: features)
    }

    func finishRichContentRendering(features: Set<RichMarkdownFeature>) {
        state.finishRichContentRendering(features: features)
    }

    func failRichContentRendering(message: String) {
        state.failRichContentRendering(message)
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
        let settings = AppController.shared.settings

        do {
            let result = try renderer.render(
                RenderRequest(
                    document: markdownDocument,
                    options: RenderOptions(
                        allowsRawHTML: settings.allowsRawHTML,
                        renderProfile: settings.renderProfile,
                        richMarkdownOptions: settings.richMarkdownOptions
                    ),
                    theme: PreviewThemeStore.theme(id: state.layout.selectedThemeID),
                    fontScale: state.layout.fontScale,
                    allowsRemoteImages: settings.allowsRemoteImages
                )
            )
            state.finishRendering(result)
            updateAssetWatchers(from: result, document: markdownDocument)
        } catch {
            state.failRendering(error)
        }
    }

    private func shouldApplyDefaultLayout(
        _ settings: ApplicationSettings,
        previousSettings: ApplicationSettings?
    ) -> Bool {
        guard let previousSettings else {
            return true
        }

        return settings.defaultThemeID != previousSettings.defaultThemeID
            || settings.defaultFontScale != previousSettings.defaultFontScale
    }

    private func shouldRefreshPreview(
        _ settings: ApplicationSettings,
        previousSettings: ApplicationSettings?,
        defaultLayoutChanged: Bool
    ) -> Bool {
        guard let previousSettings else {
            return true
        }

        return defaultLayoutChanged
            || settings.allowsRemoteImages != previousSettings.allowsRemoteImages
            || settings.allowsRawHTML != previousSettings.allowsRawHTML
            || settings.renderProfile != previousSettings.renderProfile
            || settings.richMarkdownOptions != previousSettings.richMarkdownOptions
    }

    private func shouldUpdateLivePreview(
        _ settings: ApplicationSettings,
        previousSettings: ApplicationSettings?
    ) -> Bool {
        guard let previousSettings else {
            return true
        }

        return settings.isLivePreviewEnabled != previousSettings.isLivePreviewEnabled
    }

    private func startSourceWatcher(for markdownDocument: MarkdownDocument, markWatching: Bool = true) {
        guard AppController.shared.settings.isLivePreviewEnabled else {
            stopLivePreview()
            state.noteLivePreviewInactive()
            return
        }

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

    private var currentSourceURL: URL? {
        state.currentMarkdownDocument?.sourceURL.standardizedFileURL
    }

    private func currentExportContext() -> (document: MarkdownDocument, renderResult: RenderResult)? {
        guard let document = state.currentMarkdownDocument,
              let renderResult = state.currentRenderResult else {
            return nil
        }

        return (document, renderResult)
    }

    private func suggestedExportFilename(for document: MarkdownDocument, extension fileExtension: String) -> String {
        let baseName = document.displayTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBaseName = baseName.isEmpty ? "OpenMarked Export" : baseName
        return "\(safeBaseName).\(fileExtension)"
    }

    private func presentExportError(_ error: ExportError) {
        state.notePlaceholderAction(error.localizedDescription)

        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
