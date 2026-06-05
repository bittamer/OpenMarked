import Foundation
import OpenMarkedCore

func verify(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("Verification failed: \(message)\n".utf8))
        exit(1)
    }
}

verify(AppInfo.supportsFileExtension("md"), "md should be supported")
verify(AppInfo.supportsFileExtension("MARKDOWN"), "MARKDOWN should be supported case-insensitively")
verify(AppInfo.supportsFileExtension("txt"), "txt should be supported")
verify(!AppInfo.supportsFileExtension("pdf"), "pdf should not be supported in the MVP skeleton")
verify(!AppInfo.supportsFileExtension("docx"), "docx should not be supported in the MVP skeleton")
verify(AppInfo.version == "0.1.0-alpha.1", "version should be 0.1.0-alpha.1")

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

print("OpenMarked Phase 2 verifier passed.")
