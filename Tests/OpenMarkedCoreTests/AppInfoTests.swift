@testable import OpenMarkedCore

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

    func testCMarkGFMRendererRendersFixtureReadme() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertEqual(result.rendererName, "cmark-gfm")
        XCTAssertTrue(result.bodyHTML.contains(#"<h1 id="openmarked-fixture-readme">"#))
        XCTAssertTrue(result.bodyHTML.contains("<table>"))
        XCTAssertEqual(result.outline.first?.title, "OpenMarked Fixture README")
        XCTAssertTrue(result.fullHTML.contains("<!doctype html>"))
    }

    func testGFMExtensionsRender() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/gfm.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.bodyHTML.contains("<del>scope creep</del>"))
        XCTAssertTrue(result.bodyHTML.contains(#"type="checkbox""#))
        XCTAssertTrue(result.bodyHTML.contains("<table>"))
    }

    func testHeadingSlugsAreDeduplicated() {
        let processed = HeadingPostProcessor.process("<h2>Repeat</h2>\n<h2>Repeat</h2>")

        XCTAssertTrue(processed.html.contains(#"id="repeat""#))
        XCTAssertTrue(processed.html.contains(#"id="repeat-1""#))
        XCTAssertEqual(processed.outline.map(\.id), ["repeat", "repeat-1"])
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

    func testFootnotesRenderWhenEnabled() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/footnotes.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.bodyHTML.contains("footnote"))
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
}
#else
enum AppInfoTestsFallback {
    static let localToolchainMessage = "No Swift test framework is available in this toolchain. Run `swift run OpenMarkedVerifier` for local verification."
}
#endif
