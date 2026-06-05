@testable import OpenMarkedCore
import Foundation

#if canImport(XCTest)
import XCTest

final class AppInfoTests: XCTestCase {
    func testSupportedMarkdownExtensions() {
        XCTAssertTrue(AppInfo.supportsFileExtension("md"))
        XCTAssertTrue(AppInfo.supportsFileExtension("MARKDOWN"))
        XCTAssertTrue(AppInfo.supportsFileExtension("txt"))
    }

    func testUnsupportedExtensions() {
        XCTAssertFalse(AppInfo.supportsFileExtension("pdf"))
        XCTAssertFalse(AppInfo.supportsFileExtension("docx"))
        XCTAssertFalse(AppInfo.supportsFileExtension(""))
    }

    func testVersionIsAlphaOneForPhaseZeroSkeleton() {
        XCTAssertEqual(AppInfo.version, "0.1.0-alpha.1")
    }

    func testWindowStateTransitions() throws {
        var state = DocumentWindowState()
        XCTAssertFalse(state.hasDocument)

        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        state.beginOpening(url: url)
        XCTAssertEqual(state.preview, .loading)

        let markdownDocument = try MarkdownDocumentLoader.load(url: url, loadedAt: Date(timeIntervalSince1970: 0), createBookmark: false)
        let document = OpenedDocument(markdownDocument: markdownDocument, openedAt: Date(timeIntervalSince1970: 0))
        state.finishOpening(document: document)

        XCTAssertTrue(state.hasDocument)
        XCTAssertEqual(state.windowTitle, "readme.md")
        XCTAssertTrue(state.canReloadPreview)
        XCTAssertTrue(state.canExport)
    }

    func testLivePreviewStateTransitions() {
        var state = DocumentWindowState()

        XCTAssertEqual(state.livePreview, .inactive)
        state.noteLivePreviewWatching()
        XCTAssertEqual(state.livePreview, .watching)
        state.beginLivePreviewUpdate()
        XCTAssertEqual(state.livePreview, .updating)
        state.finishLivePreviewUpdate(updatedAt: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(state.livePreview, .updated(Date(timeIntervalSince1970: 1)))
    }

    func testPreviewSearchStateTransitions() {
        var state = DocumentWindowState()

        state.showPreviewSearch()
        XCTAssertTrue(state.search.isVisible)
        state.updatePreviewSearchQuery("table")
        XCTAssertEqual(state.search.query, "table")
        state.updatePreviewSearchResult(matchCount: 4, selectedMatchIndex: 3)
        XCTAssertEqual(state.search.resultSummary, "3 of 4")
        state.hidePreviewSearch()
        XCTAssertFalse(state.search.isVisible)
        XCTAssertTrue(state.search.query.isEmpty)
    }

    func testMarkdownDocumentLoadsSourceAndStats() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        XCTAssertTrue(document.sourceText.contains("# OpenMarked Fixture README"))
        XCTAssertNil(document.frontMatter)
        XCTAssertGreaterThan(document.statistics.wordCount, 0)
        XCTAssertGreaterThan(document.metadata.fileSize, 0)
    }

    func testFrontMatterIsParsedAndRemovedFromBody() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/front-matter.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        XCTAssertEqual(document.frontMatter?.format, .yaml)
        XCTAssertEqual(document.frontMatter?.title, "Fixture With Front Matter")
        XCTAssertEqual(document.displayTitle, "Fixture With Front Matter")
        XCTAssertFalse(document.bodyText.contains("description: Metadata"))
    }

    func testUnsupportedFilesAreRejected() {
        XCTAssertThrowsError(try MarkdownDocumentLoader.load(url: URL(fileURLWithPath: "Package.swift"))) { error in
            XCTAssertEqual((error as? DocumentOpenError)?.kind, .unsupportedFileType)
        }
    }

    func testWindowStateStorePersistsLayout() throws {
        let suiteName = "OpenMarkedTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: "DocumentWindowState")
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let layout = WindowLayoutState(isOutlineVisible: false, selectedThemeID: "default", fontScale: 1.2)

        store.save(document: document, layout: layout, frame: DocumentWindowFrame(x: 10, y: 20, width: 900, height: 600))

        let restored = store.restore(forDocumentID: document.id)
        XCTAssertEqual(restored?.layout, layout)
        XCTAssertEqual(restored?.frame?.width, 900)
    }

    func testApplicationSettingsStorePersistsAndNormalizesSettings() throws {
        let suiteName = "OpenMarkedSettingsTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = ApplicationSettingsStore(userDefaults: userDefaults, settingsKey: "Settings", lastDocumentPathsKey: "LastPaths")
        store.save(ApplicationSettings(defaultThemeID: "missing", defaultFontScale: 4.0, isLivePreviewEnabled: false))

        let restored = store.load()
        XCTAssertEqual(restored.defaultThemeID, "default")
        XCTAssertEqual(restored.defaultFontScale, 2.0)
        XCTAssertFalse(restored.isLivePreviewEnabled)

        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        store.saveLastDocumentURLs([url])
        XCTAssertEqual(store.loadLastDocumentURLs().first?.path, url.path)
    }

    func testCMarkGFMRendererRendersFixtureReadme() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertEqual(result.rendererName, "cmark-gfm")
        XCTAssertTrue(result.bodyHTML.contains(#"<h1 id="openmarked-fixture-readme">"#))
        XCTAssertTrue(result.bodyHTML.contains("<table>"))
        XCTAssertEqual(result.outline.first?.title, "OpenMarked Fixture README")
        XCTAssertTrue(result.fullHTML.contains("<!doctype html>"))
        XCTAssertTrue(result.fullHTML.contains("--om-font-scale: 1.000"))
        XCTAssertTrue(result.fullHTML.contains("New York"))
        XCTAssertTrue(result.bodyHTML.contains("om-code-keyword"))
    }

    func testThemeFallbackAndInjection() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let theme = PreviewThemeStore.theme(id: "github")
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document, theme: theme, fontScale: 1.3))

        XCTAssertEqual(PreviewThemeStore.allBuiltInThemes.map(\.id), ["default", "github", "minimal"])
        XCTAssertEqual(PreviewThemeStore.theme(id: "missing").id, "default")
        XCTAssertTrue(result.fullHTML.contains("--om-font-scale: 1.300"))
        XCTAssertTrue(result.fullHTML.contains("Segoe UI"))
    }

    func testCodeHighlighterLeavesUnknownLanguagesPlain() {
        let html = #"<pre><code class="language-ruby">puts &quot;hello&quot;</code></pre>"#
        let highlighted = CodeHighlighter.highlight(html)

        XCTAssertTrue(highlighted.contains("om-code-block"))
        XCTAssertFalse(highlighted.contains("om-code-keyword"))
    }

    func testGFMExtensionsRender() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/gfm.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.bodyHTML.contains("<del>scope creep</del>"))
        XCTAssertTrue(result.bodyHTML.contains(#"type="checkbox""#))
        XCTAssertTrue(result.bodyHTML.contains("<table>"))
    }

    func testRemoteImagesCanBeBlocked() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("openmarked-remote-image-\(UUID().uuidString).md")
        try "# Remote\n\n![Remote](https://example.com/image.png)\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document, allowsRemoteImages: false))

        XCTAssertTrue(result.bodyHTML.contains("data-openmarked-blocked-src"))
    }

    func testHeadingSlugsAreDeduplicated() {
        let processed = HeadingPostProcessor.process("<h2>Repeat</h2>\n<h2>Repeat</h2>")

        XCTAssertTrue(processed.html.contains(#"id="repeat""#))
        XCTAssertTrue(processed.html.contains(#"id="repeat-1""#))
        XCTAssertEqual(processed.outline.map(\.id), ["repeat", "repeat-1"])
    }

    func testOutlineFilterMatchesHeadingTitles() {
        let outline = [
            OutlineItem(id: "intro", level: 1, title: "Introduction"),
            OutlineItem(id: "goals", level: 2, title: "Goals"),
            OutlineItem(id: "details", level: 3, title: "Implementation Details")
        ]

        XCTAssertEqual(OutlineFilter.filter(outline, query: "").map(\.id), ["intro", "goals", "details"])
        XCTAssertEqual(OutlineFilter.filter(outline, query: "GOAL").map(\.id), ["goals"])
        XCTAssertEqual(OutlineFilter.filter(outline, query: "missing"), [])
    }

    func testMissingLocalImageDiagnostic() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("openmarked-missing-image-\(UUID().uuidString).md")
        try "# Missing\n\n![Missing](missing.png)\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingLocalImage })
    }

    func testLocalAssetReferenceExtractorFindsImages() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let imageURLs = LocalAssetReferenceExtractor.imageURLs(from: result.bodyHTML, document: document)

        XCTAssertTrue(imageURLs.contains { $0.lastPathComponent == "sample-mark.svg" })
    }

    func testStandaloneHTMLExportEmbedsLocalImagesAndWritesFile() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let html = HTMLExportDocumentBuilder.standaloneHTML(renderResult: result, document: document)

        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("data:image/svg+xml;base64,"))

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-export-test-\(UUID().uuidString).html")
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        try HTMLExportWriter.write(html: html, to: destinationURL)
        let exportedHTML = try String(contentsOf: destinationURL, encoding: .utf8)

        XCTAssertTrue(exportedHTML.contains("data:image/svg+xml;base64,"))

        let unstyledHTML = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: result,
            document: document,
            options: HTMLExportOptions(embedsLocalImages: false, embedsThemeCSS: false)
        )
        XCTAssertFalse(unstyledHTML.contains("<style>"))
    }

    func testFootnotesRenderWhenEnabled() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/footnotes.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.bodyHTML.contains("footnote"))
    }

    func testPreviewStateCanHoldRenderResult() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        var state = DocumentWindowState()
        state.finishOpening(document: OpenedDocument(markdownDocument: document))
        state.beginRendering(documentName: document.displayName)
        state.finishRendering(result)

        XCTAssertEqual(state.currentRenderResult?.bodyHTML, result.bodyHTML)
    }

    func testPreviewHTMLSecurityPolicyRemovesScriptsAndEventHandlers() {
        let unsafeHTML = #"<h1 onclick="alert(1)">Title</h1><script src="https://example.com/x.js"></script>"#
        let sanitizedHTML = PreviewHTMLSecurityPolicy.sanitize(unsafeHTML)

        XCTAssertFalse(sanitizedHTML.contains("<script"))
        XCTAssertFalse(sanitizedHTML.contains("onclick"))
    }
}
#elseif canImport(Testing)
import Testing

@Suite("AppInfo")
struct AppInfoTests {
    @Test("Supported Markdown extensions are recognized")
    func supportedMarkdownExtensions() {
        #expect(AppInfo.supportsFileExtension("md"))
        #expect(AppInfo.supportsFileExtension("MARKDOWN"))
        #expect(AppInfo.supportsFileExtension("txt"))
    }

    @Test("Unsupported extensions are rejected")
    func unsupportedExtensions() {
        #expect(!AppInfo.supportsFileExtension("pdf"))
        #expect(!AppInfo.supportsFileExtension("docx"))
        #expect(!AppInfo.supportsFileExtension(""))
    }

    @Test("Phase 0 skeleton uses alpha 1 version")
    func versionIsAlphaOneForPhaseZeroSkeleton() {
        #expect(AppInfo.version == "0.1.0-alpha.1")
    }

    @Test("Window state transitions from empty to loaded")
    func windowStateTransitions() throws {
        var state = DocumentWindowState()
        #expect(!state.hasDocument)

        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        state.beginOpening(url: url)
        #expect(state.preview == .loading)

        let markdownDocument = try MarkdownDocumentLoader.load(url: url, loadedAt: Date(timeIntervalSince1970: 0), createBookmark: false)
        let document = OpenedDocument(markdownDocument: markdownDocument, openedAt: Date(timeIntervalSince1970: 0))
        state.finishOpening(document: document)

        #expect(state.hasDocument)
        #expect(state.windowTitle == "readme.md")
        #expect(state.canReloadPreview)
        #expect(state.canExport)
    }

    @Test("Live preview state transitions are tracked separately")
    func livePreviewStateTransitions() {
        var state = DocumentWindowState()

        #expect(state.livePreview == .inactive)
        state.noteLivePreviewWatching()
        #expect(state.livePreview == .watching)
        state.beginLivePreviewUpdate()
        #expect(state.livePreview == .updating)
        state.finishLivePreviewUpdate(updatedAt: Date(timeIntervalSince1970: 1))
        #expect(state.livePreview == .updated(Date(timeIntervalSince1970: 1)))
    }

    @Test("Preview search state tracks query and results")
    func previewSearchStateTransitions() {
        var state = DocumentWindowState()

        state.showPreviewSearch()
        #expect(state.search.isVisible)
        state.updatePreviewSearchQuery("table")
        #expect(state.search.query == "table")
        state.updatePreviewSearchResult(matchCount: 4, selectedMatchIndex: 3)
        #expect(state.search.resultSummary == "3 of 4")
        state.hidePreviewSearch()
        #expect(!state.search.isVisible)
        #expect(state.search.query.isEmpty)
    }

    @Test("Application settings store persists and normalizes settings")
    func applicationSettingsStorePersistsAndNormalizesSettings() throws {
        let suiteName = "OpenMarkedSettingsTests-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            #expect(Bool(false))
            return
        }
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = ApplicationSettingsStore(userDefaults: userDefaults, settingsKey: "Settings", lastDocumentPathsKey: "LastPaths")
        store.save(ApplicationSettings(defaultThemeID: "missing", defaultFontScale: 4.0, isLivePreviewEnabled: false))

        let restored = store.load()
        #expect(restored.defaultThemeID == "default")
        #expect(restored.defaultFontScale == 2.0)
        #expect(!restored.isLivePreviewEnabled)

        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        store.saveLastDocumentURLs([url])
        #expect(store.loadLastDocumentURLs().first?.path == url.path)
    }

    @Test("Markdown document loads source and statistics")
    func markdownDocumentLoadsSourceAndStats() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        #expect(document.sourceText.contains("# OpenMarked Fixture README"))
        #expect(document.frontMatter == nil)
        #expect(document.statistics.wordCount > 0)
        #expect(document.metadata.fileSize > 0)
    }

    @Test("Front matter is parsed and removed from body")
    func frontMatterIsParsedAndRemovedFromBody() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/front-matter.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        #expect(document.frontMatter?.format == .yaml)
        #expect(document.frontMatter?.title == "Fixture With Front Matter")
        #expect(document.displayTitle == "Fixture With Front Matter")
        #expect(!document.bodyText.contains("description: Metadata"))
    }

    @Test("cmark-gfm renderer renders README fixture")
    func cmarkGFMRendererRendersFixtureReadme() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.rendererName == "cmark-gfm")
        #expect(result.bodyHTML.contains(#"<h1 id="openmarked-fixture-readme">"#))
        #expect(result.bodyHTML.contains("<table>"))
        #expect(result.outline.first?.title == "OpenMarked Fixture README")
        #expect(result.fullHTML.contains("<!doctype html>"))
        #expect(result.fullHTML.contains("--om-font-scale: 1.000"))
        #expect(result.fullHTML.contains("New York"))
        #expect(result.bodyHTML.contains("om-code-keyword"))
    }

    @Test("Theme fallback and CSS injection work")
    func themeFallbackAndInjection() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let theme = PreviewThemeStore.theme(id: "github")
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document, theme: theme, fontScale: 1.3))

        #expect(PreviewThemeStore.allBuiltInThemes.map(\.id) == ["default", "github", "minimal"])
        #expect(PreviewThemeStore.theme(id: "missing").id == "default")
        #expect(result.fullHTML.contains("--om-font-scale: 1.300"))
        #expect(result.fullHTML.contains("Segoe UI"))
    }

    @Test("Unknown code languages stay unhighlighted")
    func codeHighlighterLeavesUnknownLanguagesPlain() {
        let html = #"<pre><code class="language-ruby">puts &quot;hello&quot;</code></pre>"#
        let highlighted = CodeHighlighter.highlight(html)

        #expect(highlighted.contains("om-code-block"))
        #expect(!highlighted.contains("om-code-keyword"))
    }

    @Test("GFM extensions render")
    func gfmExtensionsRender() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/gfm.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.bodyHTML.contains("<del>scope creep</del>"))
        #expect(result.bodyHTML.contains(#"type="checkbox""#))
        #expect(result.bodyHTML.contains("<table>"))
    }

    @Test("Remote images can be blocked")
    func remoteImagesCanBeBlocked() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("openmarked-remote-image-\(UUID().uuidString).md")
        try "# Remote\n\n![Remote](https://example.com/image.png)\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document, allowsRemoteImages: false))

        #expect(result.bodyHTML.contains("data-openmarked-blocked-src"))
    }

    @Test("Outline filter matches heading titles")
    func outlineFilterMatchesHeadingTitles() {
        let outline = [
            OutlineItem(id: "intro", level: 1, title: "Introduction"),
            OutlineItem(id: "goals", level: 2, title: "Goals"),
            OutlineItem(id: "details", level: 3, title: "Implementation Details")
        ]

        #expect(OutlineFilter.filter(outline, query: "").map(\.id) == ["intro", "goals", "details"])
        #expect(OutlineFilter.filter(outline, query: "GOAL").map(\.id) == ["goals"])
        #expect(OutlineFilter.filter(outline, query: "missing").isEmpty)
    }

    @Test("Local asset extractor finds image references")
    func localAssetReferenceExtractorFindsImages() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let imageURLs = LocalAssetReferenceExtractor.imageURLs(from: result.bodyHTML, document: document)

        #expect(imageURLs.contains { $0.lastPathComponent == "sample-mark.svg" })
    }

    @Test("Standalone HTML export embeds local images and writes files")
    func standaloneHTMLExportEmbedsLocalImagesAndWritesFile() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let html = HTMLExportDocumentBuilder.standaloneHTML(renderResult: result, document: document)

        #expect(html.contains("<!doctype html>"))
        #expect(html.contains("data:image/svg+xml;base64,"))

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-export-test-\(UUID().uuidString).html")
        defer { try? FileManager.default.removeItem(at: destinationURL) }

        try HTMLExportWriter.write(html: html, to: destinationURL)
        let exportedHTML = try String(contentsOf: destinationURL, encoding: .utf8)

        #expect(exportedHTML.contains("data:image/svg+xml;base64,"))

        let unstyledHTML = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: result,
            document: document,
            options: HTMLExportOptions(embedsLocalImages: false, embedsThemeCSS: false)
        )
        #expect(!unstyledHTML.contains("<style>"))
    }

    @Test("Preview state can hold render result")
    func previewStateCanHoldRenderResult() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        var state = DocumentWindowState()
        state.finishOpening(document: OpenedDocument(markdownDocument: document))
        state.beginRendering(documentName: document.displayName)
        state.finishRendering(result)

        #expect(state.currentRenderResult?.bodyHTML == result.bodyHTML)
    }
}
#else
enum AppInfoTestsFallback {
    static let localToolchainMessage = "No Swift test framework is available in this toolchain. Run `swift run OpenMarkedVerifier` for local verification."
}
#endif
