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

let renderer = CMarkGFMRenderer()
let renderResult = try renderer.render(RenderRequest(document: markdownDocument))
verify(renderResult.rendererName == "cmark-gfm", "renderer name should identify cmark-gfm")
verify(renderResult.bodyHTML.contains("<h1 id=\"openmarked-fixture-readme\">"), "headings should receive stable ids")
verify(renderResult.bodyHTML.contains("<table>"), "GFM tables should render")
verify(renderResult.outline.first?.title == "OpenMarked Fixture README", "outline should include h1")
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

let localImageURL = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
let localImageDocument = try MarkdownDocumentLoader.load(url: localImageURL, createBookmark: false)
let localImageResult = try renderer.render(RenderRequest(document: localImageDocument))
verify(localImageResult.diagnostics.isEmpty, "existing local image fixture should not warn")

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

print("OpenMarked Phase 5 verifier passed.")
