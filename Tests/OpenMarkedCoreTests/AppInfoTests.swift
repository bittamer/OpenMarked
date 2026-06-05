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

        let document = try DocumentOpenValidator.validate(url: url, openedAt: Date(timeIntervalSince1970: 0))
        state.finishOpening(document: document)

        XCTAssertTrue(state.hasDocument)
        XCTAssertEqual(state.windowTitle, "readme.md")
        XCTAssertTrue(state.canReloadPreview)
        XCTAssertTrue(state.canExport)
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

        let document = try DocumentOpenValidator.validate(url: url, openedAt: Date(timeIntervalSince1970: 0))
        state.finishOpening(document: document)

        #expect(state.hasDocument)
        #expect(state.windowTitle == "readme.md")
        #expect(state.canReloadPreview)
        #expect(state.canExport)
    }
}
#else
enum AppInfoTestsFallback {
    static let localToolchainMessage = "No Swift test framework is available in this toolchain. Run `swift run OpenMarkedVerifier` for local verification."
}
#endif
