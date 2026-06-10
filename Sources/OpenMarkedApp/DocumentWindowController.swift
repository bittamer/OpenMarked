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
    private var sourceWatcher: FileSystemWatcher?
    private var assetWatchers: [URL: FileSystemWatcher] = [:]
    private var activeAssetWatchStrategy: AssetWatchStrategy?
    private var watchedAssetURLs: Set<URL> = []
    private var assetReloadTask: Task<Void, Never>?
    private var documentLoadTask: Task<Void, Never>?
    private var renderTask: Task<Void, Never>?
    private var documentLoadGeneration: UInt64 = 0
    private var renderGeneration: UInt64 = 0
    private var activePrintExporter: WebKitPrintExporter?
    private var exportDestinations = DocumentExportDestinations.empty
    private var statisticsCache: [DocumentStatisticsCacheKey: DocumentStatistics] = [:]
    private var currentSectionUpdateTask: Task<Void, Never>?

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

    var canRepeatHTMLExport: Bool {
        state.canExport && exportDestinations.html != nil
    }

    var canRepeatPDFExport: Bool {
        state.canExport && exportDestinations.pdf != nil
    }

    func open(url: URL) {
        documentLoadTask?.cancel()
        renderTask?.cancel()
        documentLoadGeneration &+= 1
        resetDocumentDerivedCaches()
        stopLivePreview()
        previewNavigationRequest = nil
        previewSearchRequest = PreviewSearchRequest(action: .clear)
        exportDestinations = .empty
        state.beginOpening(url: url)
        updateWindowTitle()

        let loadGeneration = documentLoadGeneration
        let openedAt = Date()
        documentLoadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let markdownDocument = try await Self.loadMarkdownDocument(url: url)
                guard !Task.isCancelled, self.documentLoadGeneration == loadGeneration else {
                    return
                }

                let document = OpenedDocument(markdownDocument: markdownDocument, openedAt: openedAt)
                self.state.finishOpening(document: document)
                if let restoredState = self.stateStore.restore(forDocumentID: markdownDocument.id) {
                    self.state.applyRestoredLayout(restoredState.layout)
                    self.exportDestinations = restoredState.exportDestinations
                } else {
                    self.state.applyRestoredLayout(AppController.shared.settings.defaultLayout)
                }
                self.render(markdownDocument)
                self.startSourceWatcher(for: markdownDocument)
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
                AppController.shared.noteDocumentWindowFinishedOpening(self)
                self.persistCurrentWindowState()
            } catch is CancellationError {
                return
            } catch let error as DocumentOpenError {
                guard self.documentLoadGeneration == loadGeneration else {
                    return
                }
                self.state.failOpening(error)
            } catch {
                guard self.documentLoadGeneration == loadGeneration else {
                    return
                }
                self.state.failOpening(
                    DocumentOpenError(
                        kind: .unreadable,
                        url: url,
                        message: "\(url.lastPathComponent) could not be opened."
                    )
                )
            }

            self.updateWindowTitle()
        }
    }

    func close() {
        documentLoadTask?.cancel()
        renderTask?.cancel()
        currentSectionUpdateTask?.cancel()
        assetReloadTask?.cancel()
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
        guard let currentDocument = state.currentDocument,
              let markdownDocument = currentDocument.markdownDocument else {
            return
        }

        reloadDocumentFromDisk(
            url: markdownDocument.sourceURL,
            openedAt: currentDocument.openedAt,
            forceRender: true,
            isLivePreviewUpdate: false
        )
    }

    func toggleOutline() {
        state.toggleOutline()
        persistCurrentWindowState()
    }

    func toggleInspector() {
        state.toggleInspector()
        persistCurrentWindowState()
    }

    func setInspectorVisible(_ isVisible: Bool) {
        state.setInspectorVisible(isVisible)
        persistCurrentWindowState()
    }

    func selectInspectorSection(_ section: DocumentInspectorSection) {
        state.selectInspectorSection(section)
        persistCurrentWindowState()
    }

    func showInspector(section: DocumentInspectorSection) {
        state.showInspector(section: section)
        persistCurrentWindowState()
    }

    func setTheme(id: String) {
        let theme = AppController.shared.previewTheme(id: id)
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

        exportHTML(context: context, to: destinationURL)
    }

    func repeatHTMLExport() {
        guard let destinationURL = exportDestinations.html else {
            state.notePlaceholderAction("No previous HTML export")
            return
        }

        guard let context = currentExportContext() else {
            presentExportError(.missingRenderedDocument)
            return
        }

        guard confirmRepeatExport(kind: "HTML", destinationURL: destinationURL) else {
            return
        }

        exportHTML(context: context, to: destinationURL)
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
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.message = "Choose where to save the PDF."
        panel.nameFieldStringValue = suggestedExportFilename(for: context.document, extension: "pdf")

        guard panel.runModal() == .OK, let panelURL = panel.url else {
            return
        }

        let destinationURL = normalizedExportURL(panelURL, extension: "pdf")
        exportPDF(context: context, to: destinationURL)
    }

    func repeatPDFExport() {
        guard let destinationURL = exportDestinations.pdf else {
            state.notePlaceholderAction("No previous PDF export")
            return
        }

        guard let context = currentExportContext() else {
            presentExportError(.missingRenderedDocument)
            return
        }

        guard confirmRepeatExport(kind: "PDF", destinationURL: destinationURL) else {
            return
        }

        exportPDF(context: context, to: destinationURL)
    }

    func printDocument() {
        guard let context = currentExportContext() else {
            presentExportError(.missingRenderedDocument)
            return
        }

        let html = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: context.renderResult,
            document: context.document,
            options: HTMLExportOptions(
                embedsRichContentRuntime: false,
                printConfiguration: AppController.shared.settings.printConfiguration
            )
        )
        let exporter = WebKitPrintExporter()
        activePrintExporter = exporter
        state.notePlaceholderAction("Preparing print")
        exporter.print(
            html: html,
            baseURL: context.document.sourceURL.deletingLastPathComponent(),
            richMarkdownState: context.renderResult.richMarkdownState,
            printConfiguration: AppController.shared.settings.printConfiguration
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
            let shouldRefreshAssetWatchers = shouldRefreshAssetWatchers(settings, previousSettings: previousSettings)

            if shouldRefreshPreview {
                render(markdownDocument)
            } else if shouldRefreshInspectionReport(settings, previousSettings: previousSettings) {
                refreshInspectionReport(document: markdownDocument, settings: settings)
            }

            if !shouldRefreshPreview,
               shouldRefreshAssetWatchers,
               let renderResult = state.currentRenderResult {
                updateAssetWatchers(from: renderResult, document: markdownDocument)
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
        window?.representedURL = currentSourceURL
    }

    func scrollToOutlineItem(_ item: OutlineItem) {
        previewNavigationRequest = PreviewNavigationRequest(elementID: item.id)
        state.updateCurrentSection(id: item.id)
        state.notePlaceholderAction("Jumped to \(item.title)")
    }

    func updateCurrentPreviewSection(id: String?) {
        guard state.currentSectionID != id else {
            return
        }

        currentSectionUpdateTask?.cancel()
        currentSectionUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.state.updateCurrentSection(id: id)
        }
    }

    func setOutlineDisplayOptions(_ options: OutlineDisplayOptions) {
        state.setOutlineDisplayOptions(options)
        persistCurrentWindowState()
    }

    func updatePreviewStatus(_ message: String) {
        state.notePlaceholderAction(message)
    }

    func displayStatistics(options: DocumentStatisticsOptions) -> DocumentStatistics? {
        guard let document = state.currentMarkdownDocument else {
            return nil
        }

        let normalizedOptions = options.normalized()
        let key = DocumentStatisticsCacheKey(document: document, options: normalizedOptions)
        if let cached = statisticsCache[key] {
            return cached
        }

        let statistics: DocumentStatistics
        if !normalizedOptions.includesFrontMatter,
           normalizedOptions.wordsPerMinute == DocumentStatisticsOptions.defaultWordsPerMinute {
            statistics = document.statistics
        } else {
            statistics = DocumentStatisticsCalculator.calculate(document: document, options: normalizedOptions)
        }

        statisticsCache[key] = statistics
        return statistics
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
            },
            exportDestinations: exportDestinations
        )
    }

    private func render(_ markdownDocument: MarkdownDocument, isLivePreviewUpdate: Bool = false) {
        renderTask?.cancel()
        renderGeneration &+= 1
        state.beginRendering(documentName: markdownDocument.displayName)
        let settings = AppController.shared.settings
        let theme = AppController.shared.previewTheme(id: state.layout.selectedThemeID)
        let fontScale = state.layout.fontScale
        let documentID = markdownDocument.id
        let currentRenderGeneration = renderGeneration

        renderTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let output = try await Self.renderMarkdownDocument(
                    markdownDocument,
                    settings: settings,
                    theme: theme,
                    fontScale: fontScale
                )
                guard !Task.isCancelled,
                      self.renderGeneration == currentRenderGeneration,
                      self.state.currentMarkdownDocument?.id == documentID else {
                    return
                }

                self.state.finishRendering(output.renderResult, inspectionReport: output.inspectionReport)
                if isLivePreviewUpdate {
                    self.state.finishLivePreviewUpdate()
                }
                self.updateAssetWatchers(from: output.renderResult, document: markdownDocument)
            } catch is CancellationError {
                return
            } catch {
                guard self.renderGeneration == currentRenderGeneration,
                      self.state.currentMarkdownDocument?.id == documentID else {
                    return
                }

                if isLivePreviewUpdate {
                    self.state.failLivePreviewUpdate(error)
                } else {
                    self.state.failRendering(error)
                }
            }
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

    private func shouldRefreshAssetWatchers(
        _ settings: ApplicationSettings,
        previousSettings: ApplicationSettings?
    ) -> Bool {
        guard let previousSettings else {
            return true
        }

        return settings.performanceMode != previousSettings.performanceMode
            || settings.referencedImageReloadMode != previousSettings.referencedImageReloadMode
            || settings.isLivePreviewEnabled != previousSettings.isLivePreviewEnabled
    }

    private func shouldRefreshInspectionReport(
        _ settings: ApplicationSettings,
        previousSettings: ApplicationSettings?
    ) -> Bool {
        guard let previousSettings else {
            return true
        }

        return settings.statisticsWordsPerMinute != previousSettings.statisticsWordsPerMinute
            || settings.includesFrontMatterInStatistics != previousSettings.includesFrontMatterInStatistics
    }

    private func refreshInspectionReport(document: MarkdownDocument, settings: ApplicationSettings) {
        let report = DocumentInspectionBuilder.build(
            document: document,
            renderResult: state.currentRenderResult,
            statisticsOptions: settings.documentStatisticsOptions
        )
        state.updateInspectionReport(report)
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
        guard AppController.shared.settings.isLivePreviewEnabled else {
            stopAssetWatchers()
            state.noteReferencedAssetReloadStatus(.inactive)
            return
        }

        let sourcePath = document.sourceURL.standardizedFileURL.path
        let htmlIndex = renderResult.htmlIndex ?? RenderedHTMLIndex.build(from: renderResult.bodyHTML, document: document)
        let assetURLs = Set(
            htmlIndex
                .localImageURLs
                .map(\.standardizedFileURL)
                .filter { $0.path != sourcePath }
        )
        watchedAssetURLs = assetURLs

        guard !assetURLs.isEmpty else {
            stopAssetWatchers()
            state.noteReferencedAssetReloadStatus(.inactive)
            return
        }

        let directoryURLs = Set(assetURLs.map { $0.deletingLastPathComponent().standardizedFileURL })
        let profile = DocumentPerformanceProfile(
            sourceByteCount: renderResult.performanceProfile?.sourceByteCount ?? document.sourceText.utf8.count,
            headingCount: renderResult.performanceProfile?.headingCount ?? renderResult.outline.count,
            imageCount: assetURLs.count,
            linkCount: renderResult.performanceProfile?.linkCount ?? 0
        )
        let strategy = AppController.shared.settings.assetWatchStrategy(
            for: profile,
            directoryCount: directoryURLs.count
        )

        if activeAssetWatchStrategy != strategy {
            stopAssetWatchers()
            activeAssetWatchStrategy = strategy
        }

        switch strategy {
        case .perFile:
            reconcileAssetWatchers(targetURLs: assetURLs) { [weak self] event in
                self?.handleAssetFileEvent(event)
            }
            state.noteReferencedAssetReloadStatus(.watchingFiles(assetURLs.count))
        case .directoryFiltered:
            reconcileAssetWatchers(targetURLs: directoryURLs) { [weak self] event in
                self?.handleAssetDirectoryEvent(event)
            }
            state.noteReferencedAssetReloadStatus(
                .watchingDirectories(directoryCount: directoryURLs.count, assetCount: assetURLs.count)
            )
        case .manualReload:
            stopAssetWatchers()
            state.noteReferencedAssetReloadStatus(.manualReload(assetCount: assetURLs.count))
        }
    }

    private func reconcileAssetWatchers(
        targetURLs: Set<URL>,
        handler: @escaping @MainActor (FileWatchEvent) -> Void
    ) {
        for watchedURL in Set(assetWatchers.keys).subtracting(targetURLs) {
            assetWatchers[watchedURL]?.stop()
            assetWatchers.removeValue(forKey: watchedURL)
        }

        for targetURL in targetURLs.subtracting(Set(assetWatchers.keys)) {
            let watcher = FileSystemWatcher(url: targetURL) { event in
                Task { @MainActor in
                    handler(event)
                }
            }
            watcher.start()
            assetWatchers[targetURL] = watcher
        }
    }

    private func stopLivePreview() {
        sourceWatcher?.stop()
        sourceWatcher = nil

        stopAssetWatchers()
        state.noteReferencedAssetReloadStatus(.inactive)
    }

    private func stopAssetWatchers() {
        assetReloadTask?.cancel()
        assetReloadTask = nil
        for watcher in assetWatchers.values {
            watcher.stop()
        }
        assetWatchers.removeAll()
        watchedAssetURLs.removeAll()
        activeAssetWatchStrategy = nil
    }

    private func resetDocumentDerivedCaches() {
        statisticsCache.removeAll()
        currentSectionUpdateTask?.cancel()
        currentSectionUpdateTask = nil
    }

    private func handleSourceFileEvent(_ event: FileWatchEvent) {
        guard let markdownDocument = state.currentMarkdownDocument,
              markdownDocument.sourceURL.standardizedFileURL.path == event.url.standardizedFileURL.path else {
            return
        }

        reloadForLivePreview(forceRender: false)
    }

    private func handleAssetFileEvent(_ event: FileWatchEvent) {
        guard watchedAssetURLs.contains(event.url.standardizedFileURL) else {
            return
        }

        scheduleAssetReload()
    }

    private func handleAssetDirectoryEvent(_ event: FileWatchEvent) {
        guard assetWatchers[event.url.standardizedFileURL] != nil else {
            return
        }

        scheduleAssetReload()
    }

    private func scheduleAssetReload() {
        assetReloadTask?.cancel()
        assetReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else {
                return
            }
            self?.reloadForLivePreview(forceRender: true)
        }
    }

    private func reloadForLivePreview(forceRender: Bool) {
        guard let currentDocument = state.currentDocument,
              let currentMarkdownDocument = currentDocument.markdownDocument else {
            return
        }

        reloadDocumentFromDisk(
            url: currentMarkdownDocument.sourceURL,
            openedAt: currentDocument.openedAt,
            forceRender: forceRender,
            isLivePreviewUpdate: true
        )
    }

    private func reloadDocumentFromDisk(
        url: URL,
        openedAt: Date,
        forceRender: Bool,
        isLivePreviewUpdate: Bool
    ) {
        documentLoadTask?.cancel()
        documentLoadGeneration &+= 1
        let loadGeneration = documentLoadGeneration
        let previousSourceText = state.currentMarkdownDocument?.sourceText

        if isLivePreviewUpdate {
            assetReloadTask?.cancel()
            state.beginLivePreviewUpdate()
        } else {
            state.notePlaceholderAction("Reloading \(url.lastPathComponent)")
        }

        documentLoadTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                let reloadedDocument = try await Self.loadMarkdownDocument(url: url)
                guard !Task.isCancelled, self.documentLoadGeneration == loadGeneration else {
                    return
                }

                let sourceTextChanged = reloadedDocument.sourceText != previousSourceText
                guard forceRender || sourceTextChanged else {
                    if isLivePreviewUpdate {
                        self.state.noteLivePreviewWatching()
                    } else {
                        self.state.notePlaceholderAction("Preview is up to date")
                    }
                    return
                }

                self.resetDocumentDerivedCaches()
                self.state.finishOpening(
                    document: OpenedDocument(markdownDocument: reloadedDocument, openedAt: openedAt)
                )
                self.render(reloadedDocument, isLivePreviewUpdate: isLivePreviewUpdate)
                self.startSourceWatcher(for: reloadedDocument, markWatching: !isLivePreviewUpdate)
                AppController.shared.noteDocumentWindowFinishedOpening(self)
                self.persistCurrentWindowState()
                self.updateWindowTitle()
            } catch is CancellationError {
                return
            } catch let error as DocumentOpenError {
                guard self.documentLoadGeneration == loadGeneration else {
                    return
                }
                if isLivePreviewUpdate {
                    self.state.failLivePreviewUpdate(error)
                } else {
                    self.stopLivePreview()
                    self.state.failOpening(error)
                }
            } catch {
                guard self.documentLoadGeneration == loadGeneration else {
                    return
                }
                if isLivePreviewUpdate {
                    self.state.failLivePreviewUpdate(error)
                } else {
                    self.state.failRendering(error)
                }
            }
        }
    }

    private var currentSourceURL: URL? {
        state.currentMarkdownDocument?.sourceURL.standardizedFileURL
    }

    nonisolated private static func loadMarkdownDocument(url: URL) async throws -> MarkdownDocument {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let document = try MarkdownDocumentLoader.load(url: url)
            try Task.checkCancellation()
            return document
        }.value
    }

    nonisolated private static func renderMarkdownDocument(
        _ markdownDocument: MarkdownDocument,
        settings: ApplicationSettings,
        theme: PreviewTheme,
        fontScale: Double
    ) async throws -> RenderPipelineOutput {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let result = try CMarkGFMRenderer().render(
                RenderRequest(
                    document: markdownDocument,
                    options: RenderOptions(
                        allowsRawHTML: settings.allowsRawHTML,
                        renderProfile: settings.renderProfile,
                        richMarkdownOptions: settings.richMarkdownOptions
                    ),
                    theme: theme,
                    fontScale: fontScale,
                    allowsRemoteImages: settings.allowsRemoteImages
                )
            )
            try Task.checkCancellation()
            let optimizedPreviewHTML = PreviewImageCache.shared.optimizedHTMLForPreview(
                result.fullHTML,
                baseURL: markdownDocument.sourceURL.deletingLastPathComponent()
            )
            try Task.checkCancellation()
            let previewHTML = PreviewHTMLSecurityPolicy.sanitize(optimizedPreviewHTML)
            try Task.checkCancellation()
            let performanceProfile = DocumentPerformanceProfile(
                sourceByteCount: markdownDocument.sourceText.utf8.count,
                headingCount: result.outline.count,
                imageCount: result.htmlIndex?.imageCount ?? 0,
                linkCount: result.htmlIndex?.linkCount ?? 0
            )
            try Task.checkCancellation()
            let previewResult = result.withPreviewData(
                previewHTML: previewHTML,
                performanceProfile: performanceProfile
            )
            try Task.checkCancellation()
            let inspectionReport = DocumentInspectionBuilder.build(
                document: markdownDocument,
                renderResult: previewResult,
                statisticsOptions: settings.documentStatisticsOptions
            )
            try Task.checkCancellation()
            return RenderPipelineOutput(renderResult: previewResult, inspectionReport: inspectionReport)
        }.value
    }

    private func exportHTML(
        context: (document: MarkdownDocument, renderResult: RenderResult),
        to destinationURL: URL
    ) {
        do {
            let settings = AppController.shared.settings
            let html = HTMLExportDocumentBuilder.standaloneHTML(
                renderResult: context.renderResult,
                document: context.document,
                options: HTMLExportOptions(
                    embedsLocalImages: settings.embedsLocalImagesInHTMLExport,
                    embedsThemeCSS: settings.embedsCSSInHTMLExport,
                    printConfiguration: settings.printConfiguration
                )
            )
            try HTMLExportWriter.write(html: html, to: destinationURL)
            exportDestinations.html = destinationURL.standardizedFileURL
            persistCurrentWindowState()
            state.notePlaceholderAction("Exported HTML to \(destinationURL.lastPathComponent)")
        } catch let error as ExportError {
            presentExportError(error)
        } catch {
            presentExportError(.writeFailed(path: destinationURL.path, reason: error.localizedDescription))
        }
    }

    private func exportPDF(
        context: (document: MarkdownDocument, renderResult: RenderResult),
        to destinationURL: URL
    ) {
        let html = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: context.renderResult,
            document: context.document,
            options: HTMLExportOptions(
                embedsRichContentRuntime: false,
                printConfiguration: AppController.shared.settings.printConfiguration
            )
        )
        let exporter = WebKitPrintExporter()
        activePrintExporter = exporter
        state.notePlaceholderAction("Exporting PDF")
        exporter.exportPDF(
            html: html,
            baseURL: context.document.sourceURL.deletingLastPathComponent(),
            richMarkdownState: context.renderResult.richMarkdownState,
            printConfiguration: AppController.shared.settings.printConfiguration,
            destinationURL: destinationURL
        ) { [weak self] result in
            guard let self else {
                return
            }

            self.activePrintExporter = nil
            switch result {
            case .success:
                self.exportDestinations.pdf = destinationURL.standardizedFileURL
                self.persistCurrentWindowState()
                self.state.notePlaceholderAction("Exported PDF to \(destinationURL.lastPathComponent)")
            case .failure(let error):
                self.presentExportError(error)
            }
        }
    }

    private func confirmRepeatExport(kind: String, destinationURL: URL) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Replace Previous \(kind) Export?"
        alert.informativeText = "OpenMarked will write \(destinationURL.path)."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func currentExportContext() -> (document: MarkdownDocument, renderResult: RenderResult)? {
        guard let document = state.currentMarkdownDocument,
              let renderResult = state.currentRenderResult else {
            return nil
        }

        return (document, renderResult)
    }

    private func suggestedExportFilename(for document: MarkdownDocument, extension fileExtension: String) -> String {
        let baseName = document.resolvedTitle
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBaseName = baseName.isEmpty ? "OpenMarked Export" : baseName
        return "\(safeBaseName).\(fileExtension)"
    }

    private func normalizedExportURL(_ url: URL, extension fileExtension: String) -> URL {
        guard url.pathExtension.lowercased() != fileExtension.lowercased() else {
            return url
        }

        return url.deletingPathExtension().appendingPathExtension(fileExtension)
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

private struct RenderPipelineOutput: Sendable {
    let renderResult: RenderResult
    let inspectionReport: DocumentInspectionReport
}

private struct DocumentStatisticsCacheKey: Hashable {
    let documentID: String
    let loadedAt: TimeInterval
    let wordsPerMinute: Int
    let includesFrontMatter: Bool

    init(document: MarkdownDocument, options: DocumentStatisticsOptions) {
        let normalizedOptions = options.normalized()
        self.documentID = document.id
        self.loadedAt = document.loadedAt.timeIntervalSince1970
        self.wordsPerMinute = normalizedOptions.wordsPerMinute
        self.includesFrontMatter = normalizedOptions.includesFrontMatter
    }
}
