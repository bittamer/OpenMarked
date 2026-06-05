import Foundation
import Dispatch
import OpenMarkedCore

func verify(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("Verification failed: \(message)\n".utf8))
        exit(1)
    }
}

final class WatchEventBox: @unchecked Sendable {
    private let lock = NSLock()
    private var event: FileWatchEvent?

    func store(_ event: FileWatchEvent) {
        lock.lock()
        self.event = event
        lock.unlock()
    }

    func load() -> FileWatchEvent? {
        lock.lock()
        let event = self.event
        lock.unlock()
        return event
    }
}

@discardableResult
func measureSeconds(_ body: () throws -> Void) rethrows -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    try body()
    let end = DispatchTime.now().uptimeNanoseconds
    return Double(end - start) / 1_000_000_000
}

func runPerformanceSmoke(renderer: CMarkGFMRenderer) throws {
    let fixtures = [
        "Fixtures/Markdown/readme.md",
        "Fixtures/Markdown/gfm.md",
        "Fixtures/Markdown/long-document.md"
    ]

    for path in fixtures {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var document: MarkdownDocument?
        let loadSeconds = try measureSeconds {
            document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        }

        guard let document else {
            verify(false, "performance fixture should load: \(path)")
            continue
        }

        var result: RenderResult?
        let renderSeconds = try measureSeconds {
            result = try renderer.render(RenderRequest(document: document))
        }

        verify(result?.fullHTML.isEmpty == false, "performance fixture should render: \(path)")
        verify(loadSeconds < 2.0, "\(path) should load within 2 seconds")
        verify(renderSeconds < 2.0, "\(path) should render within 2 seconds")
        print(String(format: "Performance smoke: %@ load=%.4fs render=%.4fs words=%d", path, loadSeconds, renderSeconds, document.statistics.wordCount))
    }
}

verify(AppInfo.supportsFileExtension("md"), "md should be supported")
verify(AppInfo.supportsFileExtension("MARKDOWN"), "MARKDOWN should be supported case-insensitively")
verify(AppInfo.supportsFileExtension("mkdn"), "mkdn should be supported")
verify(AppInfo.supportsFileExtension("txt"), "txt should be supported")
verify(!AppInfo.supportsFileExtension("pdf"), "pdf should not be supported in the MVP skeleton")
verify(!AppInfo.supportsFileExtension("docx"), "docx should not be supported in the MVP skeleton")
verify(AppInfo.version == "0.2.0", "version should be 0.2.0")
verify(AppInfo.build == "2", "build should be 2")

var state = DocumentWindowState()
verify(!state.hasDocument, "new window state should not have a document")
verify(state.windowTitle == AppInfo.name, "empty window should use app title")

let fixtureURL = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
state.beginOpening(url: fixtureURL)
verify(state.preview == .loading, "beginOpening should put preview into loading state")

let markdownDocument = try MarkdownDocumentLoader.load(url: fixtureURL, loadedAt: Date(timeIntervalSince1970: 0), createBookmark: false)
let document = OpenedDocument(markdownDocument: markdownDocument, openedAt: Date(timeIntervalSince1970: 0))
state.finishOpening(document: document)
verify(state.hasDocument, "loaded window state should have a document")
verify(state.windowTitle == "readme.md", "loaded window should use document title")
verify(state.canReloadPreview, "loaded window should be reloadable")
verify(state.canExport, "loaded window should be exportable")
verify(markdownDocument.sourceText.contains("# OpenMarked Fixture README"), "document source text should be loaded")
verify(markdownDocument.bodyText == markdownDocument.sourceText, "readme fixture should not have front matter")
verify(markdownDocument.statistics.wordCount > 0, "document stats should count words")

state.toggleOutline()
verify(!state.layout.isOutlineVisible, "toggleOutline should hide the outline")
state.zoomIn()
verify(state.layout.fontScale > 1.0, "zoomIn should increase font scale")
state.resetZoom()
verify(state.layout.fontScale == 1.0, "resetZoom should restore default font scale")
state.noteLivePreviewWatching()
verify(state.livePreview == .watching, "live preview should enter watching state")
state.beginLivePreviewUpdate()
verify(state.livePreview == .updating, "live preview should enter updating state")
state.finishLivePreviewUpdate(updatedAt: Date(timeIntervalSince1970: 1))
verify(state.livePreview == .updated(Date(timeIntervalSince1970: 1)), "live preview should record update feedback")
state.showPreviewSearch()
verify(state.search.isVisible, "search should become visible")
state.updatePreviewSearchQuery("preview")
verify(state.search.query == "preview", "search query should update")
state.updatePreviewSearchResult(matchCount: 3, selectedMatchIndex: 2)
verify(state.search.resultSummary == "2 of 3", "search result summary should show selected match")
state.hidePreviewSearch()
verify(!state.search.isVisible && state.search.query.isEmpty, "search should clear when hidden")

do {
    _ = try DocumentOpenValidator.validate(url: URL(fileURLWithPath: "Package.swift"))
    verify(false, "Package.swift should not be accepted as a Markdown file")
} catch let error as DocumentOpenError {
    verify(error.kind == .unsupportedFileType, "unsupported files should produce unsupportedFileType")
}

let frontMatterURL = URL(fileURLWithPath: "Fixtures/Markdown/front-matter.md").standardizedFileURL
let frontMatterDocument = try MarkdownDocumentLoader.load(url: frontMatterURL, createBookmark: false)
verify(frontMatterDocument.frontMatter?.title == "Fixture With Front Matter", "front matter title should parse")
verify(!frontMatterDocument.bodyText.contains("description: Metadata"), "body text should exclude front matter")
verify(frontMatterDocument.displayTitle == "Fixture With Front Matter", "front matter title should become display title")

let suiteName = "OpenMarkedVerifier-\(UUID().uuidString)"
guard let userDefaults = UserDefaults(suiteName: suiteName) else {
    verify(false, "test user defaults suite should be available")
    exit(1)
}
defer { userDefaults.removePersistentDomain(forName: suiteName) }
let store = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: "VerifierWindowState")
let savedLayout = WindowLayoutState(isOutlineVisible: false, selectedThemeID: "default", fontScale: 1.2)
store.save(document: markdownDocument, layout: savedLayout, frame: DocumentWindowFrame(x: 1, y: 2, width: 900, height: 600))
let restored = store.restore(forDocumentID: markdownDocument.id)
verify(restored?.layout == savedLayout, "window layout should persist")
verify(restored?.frame?.width == 900, "window frame should persist")

let settingsStore = ApplicationSettingsStore(userDefaults: userDefaults, settingsKey: "VerifierSettings", lastDocumentPathsKey: "VerifierLastPaths")
let savedSettings = ApplicationSettings(defaultThemeID: "missing", defaultFontScale: 4.0, isLivePreviewEnabled: false)
settingsStore.save(savedSettings)
let restoredSettings = settingsStore.load()
verify(restoredSettings.defaultThemeID == "default", "settings should normalize unknown theme ids")
verify(restoredSettings.defaultFontScale == 2.0, "settings should clamp default font scale")
verify(!restoredSettings.isLivePreviewEnabled, "settings should persist live preview preference")
settingsStore.saveLastDocumentURLs([markdownDocument.sourceURL])
verify(settingsStore.loadLastDocumentURLs().first?.path == markdownDocument.sourceURL.path, "settings store should persist last document paths")

let renderer = CMarkGFMRenderer()
let renderResult = try renderer.render(RenderRequest(document: markdownDocument))
verify(renderResult.rendererName == "cmark-gfm", "renderer name should identify cmark-gfm")
verify(renderResult.bodyHTML.contains("<h1 id=\"openmarked-fixture-readme\">"), "headings should receive stable ids")
verify(renderResult.bodyHTML.contains("<table>"), "GFM tables should render")
verify(renderResult.outline.first?.title == "OpenMarked Fixture README", "outline should include h1")
let filteredOutline = OutlineFilter.filter(renderResult.outline, query: "goals")
verify(filteredOutline.count == 1 && filteredOutline.first?.title == "Goals", "outline filtering should match headings case-insensitively")
verify(OutlineFilter.filter(renderResult.outline, query: "").count == renderResult.outline.count, "empty outline filter should return all headings")
verify(renderResult.fullHTML.contains("<!doctype html>"), "full HTML document should be assembled")
verify(renderResult.fullHTML.contains("--om-font-scale: 1.000"), "default font scale should be injected")
verify(renderResult.fullHTML.contains("New York"), "default theme CSS should be injected")
verify(renderResult.bodyHTML.contains("om-code-keyword"), "code highlighting should be applied")

let githubTheme = PreviewThemeStore.theme(id: "github")
let githubThemeResult = try renderer.render(RenderRequest(document: markdownDocument, theme: githubTheme, fontScale: 1.3))
verify(githubThemeResult.fullHTML.contains("--om-font-scale: 1.300"), "custom font scale should be injected")
verify(githubThemeResult.fullHTML.contains("Segoe UI"), "GitHub theme CSS should be injected")
verify(PreviewThemeStore.theme(id: "missing").id == "default", "unknown themes should fall back to default")

let gfmURL = URL(fileURLWithPath: "Fixtures/Markdown/gfm.md").standardizedFileURL
let gfmDocument = try MarkdownDocumentLoader.load(url: gfmURL, createBookmark: false)
let gfmResult = try renderer.render(RenderRequest(document: gfmDocument))
verify(gfmResult.bodyHTML.contains("<del>scope creep</del>"), "strikethrough extension should render")
verify(gfmResult.bodyHTML.contains("type=\"checkbox\""), "task list extension should render checkboxes")

let remoteImageURL = FileManager.default.temporaryDirectory.appendingPathComponent("openmarked-remote-image-\(UUID().uuidString).md")
try "# Remote\n\n![Remote](https://example.com/image.png)\n".write(to: remoteImageURL, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: remoteImageURL) }
let remoteImageDocument = try MarkdownDocumentLoader.load(url: remoteImageURL, createBookmark: false)
let remoteBlockedResult = try renderer.render(RenderRequest(document: remoteImageDocument, allowsRemoteImages: false))
verify(remoteBlockedResult.bodyHTML.contains("data-openmarked-blocked-src"), "remote images should be blocked when disabled")

let localImageURL = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
let localImageDocument = try MarkdownDocumentLoader.load(url: localImageURL, createBookmark: false)
let localImageResult = try renderer.render(RenderRequest(document: localImageDocument))
verify(localImageResult.diagnostics.isEmpty, "existing local image fixture should not warn")
let localImageAssetURLs = LocalAssetReferenceExtractor.imageURLs(from: localImageResult.bodyHTML, document: localImageDocument)
verify(localImageAssetURLs.contains { $0.lastPathComponent == "sample-mark.svg" }, "local image assets should be extractable for live watching")
let exportedLocalImageHTML = HTMLExportDocumentBuilder.standaloneHTML(renderResult: localImageResult, document: localImageDocument)
verify(exportedLocalImageHTML.contains("<!doctype html>"), "standalone HTML export should include document structure")
verify(exportedLocalImageHTML.contains("data:image/svg+xml;base64,"), "standalone HTML export should embed local image assets")
let unstyledExportHTML = HTMLExportDocumentBuilder.standaloneHTML(
    renderResult: localImageResult,
    document: localImageDocument,
    options: HTMLExportOptions(embedsLocalImages: false, embedsThemeCSS: false)
)
verify(!unstyledExportHTML.contains("<style>"), "HTML export should be able to omit embedded CSS")

let htmlExportURL = FileManager.default.temporaryDirectory.appendingPathComponent("openmarked-export-\(UUID().uuidString).html")
try HTMLExportWriter.write(html: exportedLocalImageHTML, to: htmlExportURL)
defer { try? FileManager.default.removeItem(at: htmlExportURL) }
let exportedHTMLFromDisk = try String(contentsOf: htmlExportURL, encoding: .utf8)
verify(exportedHTMLFromDisk.contains("data:image/svg+xml;base64,"), "HTML export writer should persist exported HTML")

let missingURL = URL(fileURLWithPath: "Fixtures/Markdown/missing-image-temp.md").standardizedFileURL
try "# Missing\n\n![Nope](missing.png)\n".write(to: missingURL, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: missingURL) }
let missingDocument = try MarkdownDocumentLoader.load(url: missingURL, createBookmark: false)
let missingResult = try renderer.render(RenderRequest(document: missingDocument))
verify(missingResult.diagnostics.contains { $0.kind == .missingLocalImage }, "missing local image should produce diagnostic")

let footnoteURL = URL(fileURLWithPath: "Fixtures/Markdown/footnotes.md").standardizedFileURL
let footnoteDocument = try MarkdownDocumentLoader.load(url: footnoteURL, createBookmark: false)
let footnoteResult = try renderer.render(RenderRequest(document: footnoteDocument))
verify(footnoteResult.bodyHTML.contains("footnote"), "footnotes should render when cmark-gfm footnotes are enabled")

var renderState = DocumentWindowState()
renderState.finishOpening(document: OpenedDocument(markdownDocument: markdownDocument))
renderState.beginRendering(documentName: markdownDocument.displayName)
renderState.finishRendering(renderResult)
verify(renderState.currentRenderResult?.bodyHTML == renderResult.bodyHTML, "window state should retain render result for preview")

let unsafeHTML = #"<h1 onclick="alert(1)">Title</h1><script src="https://example.com/x.js"></script>"#
let sanitizedHTML = PreviewHTMLSecurityPolicy.sanitize(unsafeHTML)
verify(!sanitizedHTML.contains("<script"), "preview sanitizer should remove script tags")
verify(!sanitizedHTML.contains("onclick"), "preview sanitizer should remove event handler attributes")

let watcherDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("OpenMarkedWatcherVerifier-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: watcherDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: watcherDirectory) }

func waitForWatchEvent(
    url: URL,
    debounceInterval: TimeInterval = 0.05,
    timeout: DispatchTimeInterval = .seconds(3),
    change: (URL) throws -> Void
) throws -> FileWatchEvent {
    let semaphore = DispatchSemaphore(value: 0)
    let eventBox = WatchEventBox()
    let watcher = FileSystemWatcher(url: url, debounceInterval: debounceInterval, callbackQueue: .global()) { event in
        eventBox.store(event)
        semaphore.signal()
    }

    watcher.start()
    Thread.sleep(forTimeInterval: 0.12)
    try change(url)
    let result = semaphore.wait(timeout: .now() + timeout)
    watcher.stop()

    verify(result == .success, "watcher should emit an event for \(url.lastPathComponent)")
    return eventBox.load() ?? FileWatchEvent(url: url, kind: .changed)
}

let watchedFileURL = watcherDirectory.appendingPathComponent("live.md")
try "# Live\n".write(to: watchedFileURL, atomically: true, encoding: .utf8)
let writeEvent = try waitForWatchEvent(url: watchedFileURL) { url in
    try "# Live\n\nUpdated.\n".write(to: url, atomically: false, encoding: .utf8)
}
verify(writeEvent.kind == .changed || writeEvent.kind == .replaced, "normal writes should be detected")

let replacementEvent = try waitForWatchEvent(url: watchedFileURL) { url in
    let replacementURL = watcherDirectory.appendingPathComponent("live-replacement.md")
    try "# Live\n\nAtomic replacement.\n".write(to: replacementURL, atomically: true, encoding: .utf8)
    try FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: replacementURL, to: url)
}
verify(replacementEvent.kind == .deleted || replacementEvent.kind == .replaced || replacementEvent.kind == .changed, "atomic replacement should be detected")

let missingWatchedURL = watcherDirectory.appendingPathComponent("later-image.png")
let creationEvent = try waitForWatchEvent(url: missingWatchedURL) { url in
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
}
verify(creationEvent.kind == .replaced || creationEvent.kind == .changed, "creation of a missing watched file should be detected")

if CommandLine.arguments.contains("--performance-smoke") {
    try runPerformanceSmoke(renderer: renderer)
}

print("OpenMarked Phase 10 verifier passed.")
