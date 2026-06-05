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
}
#else
enum AppInfoTestsFallback {
    static let localToolchainMessage = "No Swift test framework is available in this toolchain. Run `swift run OpenMarkedVerifier` for local verification."
}
#endif
