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
verify(AppInfo.version == "0.3.0", "version should be 0.3.0")
verify(AppInfo.build == "3", "build should be 3")

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
verify(!state.layout.isInspectorVisible, "inspector should default hidden")
verify(state.layout.selectedInspectorSection == .summary, "inspector should default to summary")
state.toggleInspector()
verify(state.layout.isInspectorVisible, "toggleInspector should show the inspector")
state.selectInspectorSection(.links)
verify(state.layout.selectedInspectorSection == .links, "selectInspectorSection should update the current inspector section")
state.showInspector(section: .export)
verify(state.layout.isInspectorVisible && state.layout.selectedInspectorSection == .export, "showInspector should reveal and select a section")
state.setInspectorVisible(false)
verify(!state.layout.isInspectorVisible && state.layout.selectedInspectorSection == .export, "hiding inspector should preserve the selected section")

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
verify(frontMatterDocument.resolvedTitle == "Fixture With Front Matter", "front matter title should become resolved title")
verify(frontMatterDocument.resolvedTitleSource == .frontMatter, "front matter should be the resolved title source")

let suiteName = "OpenMarkedVerifier-\(UUID().uuidString)"
guard let userDefaults = UserDefaults(suiteName: suiteName) else {
    verify(false, "test user defaults suite should be available")
    exit(1)
}
defer { userDefaults.removePersistentDomain(forName: suiteName) }
let store = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: "VerifierWindowState")
let savedLayout = WindowLayoutState(
    isOutlineVisible: false,
    isInspectorVisible: true,
    selectedInspectorSection: .metadata,
    selectedThemeID: "default",
    fontScale: 1.2
)
store.save(document: markdownDocument, layout: savedLayout, frame: DocumentWindowFrame(x: 1, y: 2, width: 900, height: 600))
let restored = store.restore(forDocumentID: markdownDocument.id)
verify(restored?.layout == savedLayout, "window layout should persist")
verify(restored?.frame?.width == 900, "window frame should persist")
let oldLayoutPayload = Data(
    """
    {
      "isOutlineVisible": false,
      "selectedThemeID": "github",
      "fontScale": 1.2
    }
    """.utf8
)
let decodedOldLayout = try JSONDecoder().decode(WindowLayoutState.self, from: oldLayoutPayload)
verify(!decodedOldLayout.isOutlineVisible, "old layout payload should preserve outline visibility")
verify(!decodedOldLayout.isInspectorVisible, "old layout payload should default inspector hidden")
verify(decodedOldLayout.selectedInspectorSection == .summary, "old layout payload should default inspector to summary")
let unknownInspectorSectionPayload = Data(
    """
    {
      "isInspectorVisible": true,
      "selectedInspectorSection": "futureSection"
    }
    """.utf8
)
let decodedUnknownInspectorSectionLayout = try JSONDecoder().decode(WindowLayoutState.self, from: unknownInspectorSectionPayload)
verify(decodedUnknownInspectorSectionLayout.isInspectorVisible, "unknown inspector section layout should preserve visibility")
verify(decodedUnknownInspectorSectionLayout.selectedInspectorSection == .summary, "unknown inspector section layout should fall back to summary")

let settingsStore = ApplicationSettingsStore(userDefaults: userDefaults, settingsKey: "VerifierSettings", lastDocumentPathsKey: "VerifierLastPaths")
let savedSettings = ApplicationSettings(
    defaultThemeID: "missing",
    appChromeThemeID: "tokyo-night",
    defaultFontScale: 4.0,
    isLivePreviewEnabled: false,
    renderProfile: .gitHubReadme
)
settingsStore.save(savedSettings)
let restoredSettings = settingsStore.load()
verify(restoredSettings.defaultThemeID == "default", "settings should normalize unknown theme ids")
verify(restoredSettings.appChromeThemeID == "tokyo-night", "settings should persist app chrome theme ids")
verify(restoredSettings.defaultFontScale == 2.0, "settings should clamp default font scale")
verify(!restoredSettings.isLivePreviewEnabled, "settings should persist live preview preference")
verify(restoredSettings.renderProfile == .gitHubReadme, "settings should persist render profile")
verify(restoredSettings.richMarkdownOptions == .default, "settings should default rich Markdown options")
verify(!restoredSettings.richMarkdownOptions.validatesRemoteLinks, "remote link validation should default off")
settingsStore.saveLastDocumentURLs([markdownDocument.sourceURL])
verify(settingsStore.loadLastDocumentURLs().first?.path == markdownDocument.sourceURL.path, "settings store should persist last document paths")

let oldSettingsPayload = Data(
    """
    {
      "defaultThemeID": "missing",
      "defaultFontScale": 4.0,
      "isLivePreviewEnabled": false
    }
    """.utf8
)
let decodedOldSettings = try JSONDecoder().decode(ApplicationSettings.self, from: oldSettingsPayload).normalized()
verify(decodedOldSettings.appChromeThemeID == "default", "old settings payloads should decode with the default app chrome theme")
verify(decodedOldSettings.richMarkdownOptions == .default, "old settings payloads should decode with rich Markdown defaults")
verify(decodedOldSettings.renderProfile == .openMarked, "old settings payloads should decode with the OpenMarked render profile")

verify(
    AppChromeThemeStore.allBuiltInThemes.map(\.id) == ["default", "catppuccin", "tokyo-night", "everforest", "nord", "rose-pine", "dracula", "gruvbox"],
    "app chrome theme ids should include the palette themes"
)
verify(AppChromeThemeStore.theme(id: "missing").id == "default", "unknown app chrome themes should fall back to default")
verify(MarkdownRenderProfile.openMarked.displayName == "OpenMarked", "OpenMarked render profile should be available")
verify(MarkdownRenderProfile.gitHubReadme.headingSlugStyle == .gitHub, "GitHub README profile should select GitHub heading slugs")
verify(MarkdownRenderProfile.gitHubReadme.supportsGitHubCallouts, "GitHub README profile should advertise callout support")
verify(HeadingPostProcessor.slug(for: "API_v2", style: .openMarked) == "api-v2", "OpenMarked slug style should preserve current underscore behavior")
verify(HeadingPostProcessor.slug(for: "API_v2", style: .gitHub) == "api_v2", "GitHub slug style should preserve underscores")

let richMarkdownSample = """
> [!NOTE]
> Fixture callout.

```mermaid
flowchart LR
    A --> B
```

Inline math uses $x + 1$.

[Local](README.md)
[Heading](#target)
[Remote](https://example.com)
"""
let richMarkdownFeatures = RichMarkdownDocumentFeatures.detect(in: richMarkdownSample)
verify(richMarkdownFeatures.containsMermaid, "rich feature detection should find Mermaid")
verify(richMarkdownFeatures.containsMath, "rich feature detection should find math")
verify(richMarkdownFeatures.containsGitHubCallouts, "rich feature detection should find GitHub callouts")
verify(richMarkdownFeatures.containsLocalLinks, "rich feature detection should find local links")
verify(richMarkdownFeatures.containsHeadingLinks, "rich feature detection should find heading links")
verify(richMarkdownFeatures.containsRemoteLinks, "rich feature detection should find remote links")
verify(
    Set(RenderDiagnosticKind.allCases).isSuperset(of: [.missingLocalLink, .missingHeadingFragment, .malformedLink, .malformedFrontMatter, .unsupportedLinkScheme, .mermaidRenderFailure, .mathRenderFailure, .richContentDisabled, .malformedGitHubCallout, .linkValidationSkipped]),
    "diagnostic kinds should include rich Markdown foundation cases"
)

let richContentManifest = RichContentAssetStore.manifest()
verify(richContentManifest.mermaid.version == "11.15.0", "Mermaid asset manifest should expose pinned version")
verify(richContentManifest.katex.version == "0.17.0", "KaTeX asset manifest should expose pinned version")
verify(richContentManifest.hasMermaidRuntime, "Mermaid runtime should be bundled")
verify(richContentManifest.hasKaTeXRuntime, "KaTeX runtime should be bundled")
verify(richContentManifest.hasKaTeXCSS, "KaTeX CSS should be bundled")
verify(richContentManifest.hasOpenMarkedRuntime, "OpenMarked rich runtime should be bundled")
verify(richContentManifest.hasOpenMarkedCSS, "OpenMarked rich CSS should be bundled")
verify(richContentManifest.katexFontCount > 0, "KaTeX fonts should be bundled")
let mermaidRuntimeJavaScript = try RichContentAssetStore.mermaidRuntimeJavaScript()
let katexRuntimeJavaScript = try RichContentAssetStore.katexRuntimeJavaScript()
let openMarkedRuntimeJavaScript = try RichContentAssetStore.openMarkedRuntimeJavaScript()
let katexHTMLCSS = try RichContentAssetStore.katexCSSForHTML()
let mermaidLicenseURL = try RichContentAssetStore.requiredResourceURL("RichContent/Mermaid/Mermaid-LICENSE")
let katexLicenseURL = try RichContentAssetStore.requiredResourceURL("RichContent/KaTeX/KaTeX-LICENSE")
let katexMainFontURL = try RichContentAssetStore.requiredResourceURL("RichContent/KaTeX/fonts/KaTeX_Main-Regular.woff2")
verify(mermaidRuntimeJavaScript.contains("mermaid"), "Mermaid runtime should load as JavaScript text")
verify(katexRuntimeJavaScript.contains("katex"), "KaTeX runtime should load as JavaScript text")
verify(openMarkedRuntimeJavaScript.contains("openMarkedRichContent"), "OpenMarked rich runtime should load as JavaScript text")
verify(katexHTMLCSS.contains("KaTeX_Main-Regular.woff2"), "KaTeX CSS should resolve bundled font URLs")
verify(FileManager.default.fileExists(atPath: mermaidLicenseURL.path), "Mermaid license metadata should be bundled")
verify(FileManager.default.fileExists(atPath: katexLicenseURL.path), "KaTeX license metadata should be bundled")
verify(FileManager.default.fileExists(atPath: katexMainFontURL.path), "KaTeX font resources should resolve through asset store")

let richRuntimeState = RichMarkdownRenderState(
    documentFeatures: RichMarkdownDocumentFeatures(features: [.mermaid, .math])
)
let plainAssembledHTML = HTMLDocumentAssembler.assemble(title: "Plain", bodyHTML: "<p>Plain</p>")
let richAssembledHTML = HTMLDocumentAssembler.assemble(
    title: "Rich",
    bodyHTML: "<p>Rich</p>",
    richMarkdownState: richRuntimeState
)
verify(!plainAssembledHTML.contains("om-rich-content-assets"), "plain HTML should not include rich content assets")
verify(richAssembledHTML.contains("om-rich-content-assets"), "rich HTML should include the rich content style block")
verify(richAssembledHTML.contains("katex-version"), "math HTML should include KaTeX CSS")
let richRuntimeScripts = try RichContentRuntimeAssembler.runtimeScripts(for: richRuntimeState)
verify(richRuntimeScripts.count == 3, "rich runtime should include OpenMarked, Mermaid, and KaTeX scripts")
let runtimeStatus = RichContentWebViewRuntime.status(
    from: ["ready": false, "timedOut": true, "errors": ["Timed out"]],
    requestedFeatures: [.mermaid]
)
verify(runtimeStatus.hasFailure, "rich runtime status should report timeout failures")

var richStatusState = DocumentWindowState()
let richStatusRenderState = RichMarkdownRenderState(
    documentFeatures: RichMarkdownDocumentFeatures(features: [.mermaid, .math])
)
let richStatusResult = RenderResult(
    bodyHTML: "<p>Rich</p>",
    fullHTML: "<!doctype html><p>Rich</p>",
    outline: [],
    diagnostics: [],
    statistics: .empty,
    rendererName: "test",
    rendererVersion: nil,
    richMarkdownState: richStatusRenderState
)
richStatusState.finishRendering(richStatusResult)
verify(richStatusState.richContentPreview == .pending([.mermaid, .math]), "rich status should become pending after rendering rich placeholders")
richStatusState.beginRichContentRendering(features: [.mermaid, .math])
verify(richStatusState.richContentPreview == .rendering([.mermaid, .math]), "rich status should report active rendering")
richStatusState.finishRichContentRendering(features: [.mermaid, .math])
verify(richStatusState.richContentPreview == .ready([.mermaid, .math]), "rich status should report ready after WebKit completion")
richStatusState.failRichContentRendering("Rich content rendering failed")
verify(richStatusState.richContentPreview == .failed("Rich content rendering failed"), "rich status should preserve concise failure messages")

let renderer = CMarkGFMRenderer()
let renderResult = try renderer.render(RenderRequest(document: markdownDocument))
verify(renderResult.rendererName == "cmark-gfm", "renderer name should identify cmark-gfm")
verify(markdownDocument.displayTitle == "readme.md", "display title should remain file-oriented without front matter")
verify(markdownDocument.resolvedTitle == "OpenMarked Fixture README", "resolved title should fall back to the first heading")
verify(markdownDocument.resolvedTitleSource == .firstHeading, "first heading should be the resolved title source")
verify(renderResult.bodyHTML.contains("<h1 id=\"openmarked-fixture-readme\">"), "headings should receive stable ids")
verify(renderResult.bodyHTML.contains("<table>"), "GFM tables should render")
verify(renderResult.outline.first?.title == "OpenMarked Fixture README", "outline should include h1")
let filteredOutline = OutlineFilter.filter(renderResult.outline, query: "goals")
verify(filteredOutline.count == 1 && filteredOutline.first?.title == "Goals", "outline filtering should match headings case-insensitively")
verify(OutlineFilter.filter(renderResult.outline, query: "").count == renderResult.outline.count, "empty outline filter should return all headings")
verify(renderResult.fullHTML.contains("<!doctype html>"), "full HTML document should be assembled")
verify(renderResult.fullHTML.contains("<title>OpenMarked Fixture README</title>"), "preview HTML title should use resolved title")
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
verify(exportedLocalImageHTML.contains("<title>Local Images</title>"), "standalone HTML export should use resolved title precedence")
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

let richFixturePaths = [
    "Fixtures/Markdown/rich-markdown.md",
    "Fixtures/Markdown/mermaid.md",
    "Fixtures/Markdown/math.md",
    "Fixtures/Markdown/callouts.md",
    "Fixtures/Markdown/links.md",
    "Fixtures/Markdown/broken-links.md",
    "Fixtures/Markdown/github-readme-compat.md",
    "Fixtures/Markdown/metadata-rich.md",
    "Fixtures/Markdown/malformed-front-matter.md",
    "Fixtures/Markdown/json-front-matter.md",
    "Fixtures/Markdown/inspection-links-assets.md",
    "Fixtures/Markdown/statistics-rich.md",
    "Fixtures/Markdown/print-readiness.md",
    "Fixtures/Markdown/heading-depth.md",
    "Fixtures/Markdown/wide-table.md"
]

for path in richFixturePaths {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
    let result = try renderer.render(RenderRequest(document: document))
    verify(!document.bodyText.isEmpty, "\(path) should load source text")
    verify(!result.fullHTML.isEmpty, "\(path) should render full HTML")
}

let emptyInspectionDocument = MarkdownDocument(
    sourceURL: URL(fileURLWithPath: "/tmp/empty.md"),
    sourceText: "",
    bodyText: "",
    frontMatter: nil,
    metadata: DocumentFileMetadata(fileSize: 0, createdAt: nil, modifiedAt: nil),
    statistics: .empty,
    loadedAt: Date(timeIntervalSince1970: 0),
    securityScopedBookmark: nil
)
let emptyInspectionReport = DocumentInspectionBuilder.build(document: emptyInspectionDocument)
verify(emptyInspectionReport.statistics == .empty, "empty inspection report should keep zero statistics")
verify(emptyInspectionReport.exportReadiness.isReady, "empty inspection report should be export-ready")

let metadataInspectionURL = URL(fileURLWithPath: "Fixtures/Markdown/metadata-rich.md").standardizedFileURL
let metadataInspectionDocument = try MarkdownDocumentLoader.load(
    url: metadataInspectionURL,
    loadedAt: Date(timeIntervalSince1970: 0),
    createBookmark: false
)
let metadataInspectionReport = DocumentInspectionBuilder.build(document: metadataInspectionDocument)
verify(metadataInspectionReport.metadata.displayTitle == "Workbench Metadata Fixture", "inspection metadata should use front matter title")
verify(metadataInspectionReport.metadata.titleSource == .frontMatter, "inspection metadata should record front matter title source")
verify(metadataInspectionReport.metadata.frontMatterFormat == .yaml, "inspection metadata should record YAML front matter")
verify(metadataInspectionReport.metadata.fields.contains { $0.key == "tags" && $0.valueKind == .list && $0.tokens == ["inspection", "metadata", "release"] }, "inspection metadata should normalize list fields")
verify(metadataInspectionReport.metadata.fields.contains { $0.key == "draft" && $0.valueKind == .boolean && $0.value == "false" }, "inspection metadata should normalize booleans")
verify(metadataInspectionReport.metadata.fields.contains { $0.key == "date" && $0.valueKind == .date }, "inspection metadata should normalize date-like values")
verify(metadataInspectionReport.metadata.fields.contains { $0.key == "priority" && $0.valueKind == .number && $0.value == "3" }, "inspection metadata should normalize numbers")
verify(metadataInspectionReport.metadata.fields.contains { $0.key == "aliases" && $0.valueKind == .list && $0.tokens == ["Workbench", "Document Inspector"] }, "inspection metadata should normalize nested YAML lists")
verify(metadataInspectionReport.metadata.fields.contains { $0.key == "options" && $0.valueKind == .object && $0.value.contains("mode: compact") }, "inspection metadata should keep nested YAML readable")
verify(metadataInspectionReport.metadata.fields.contains { $0.key == "custom-field" && !$0.isStandard }, "inspection metadata should include custom fields")
verify(metadataInspectionReport.metadata.fileFacts.contains { $0.key == "titleSource" && $0.value == "Front matter" }, "inspection metadata should include title source file fact")
verify(metadataInspectionReport.metadata.fileFacts.contains { $0.key == "path" && $0.value.hasSuffix("metadata-rich.md") }, "inspection metadata should include file facts")

let jsonMetadataURL = URL(fileURLWithPath: "Fixtures/Markdown/json-front-matter.md").standardizedFileURL
let jsonMetadataDocument = try MarkdownDocumentLoader.load(url: jsonMetadataURL, createBookmark: false)
let jsonMetadataReport = DocumentInspectionBuilder.build(document: jsonMetadataDocument)
verify(jsonMetadataDocument.frontMatter?.format == .json, "JSON front matter should parse")
verify(jsonMetadataReport.metadata.fields.contains { $0.key == "tags" && $0.valueKind == .list && $0.tokens == ["json", "metadata"] }, "JSON metadata lists should normalize")
verify(jsonMetadataReport.metadata.fields.contains { $0.key == "draft" && $0.valueKind == .boolean && $0.value == "false" }, "JSON metadata booleans should normalize")

let malformedMetadataURL = URL(fileURLWithPath: "Fixtures/Markdown/malformed-front-matter.md").standardizedFileURL
let malformedMetadataDocument = try MarkdownDocumentLoader.load(url: malformedMetadataURL, createBookmark: false)
let malformedMetadataResult = try renderer.render(RenderRequest(document: malformedMetadataDocument))
let malformedMetadataReport = DocumentInspectionBuilder.build(document: malformedMetadataDocument, renderResult: malformedMetadataResult)
verify(malformedMetadataDocument.frontMatter?.title == "Malformed Metadata Fixture", "malformed front matter should preserve readable fields")
verify(!malformedMetadataDocument.bodyText.contains("broken field without separator"), "malformed front matter should stay out of body text")
verify(malformedMetadataResult.diagnostics.contains { $0.kind == .malformedFrontMatter && $0.source == "broken field without separator" }, "malformed front matter should produce render diagnostics")
verify(malformedMetadataReport.exportReadiness.issues.contains { $0.title == "Malformed front matter" }, "malformed front matter should affect export readiness")

let statisticsInspectionURL = URL(fileURLWithPath: "Fixtures/Markdown/statistics-rich.md").standardizedFileURL
let statisticsInspectionDocument = try MarkdownDocumentLoader.load(url: statisticsInspectionURL, createBookmark: false)
let statisticsInspectionResult = try renderer.render(RenderRequest(document: statisticsInspectionDocument))
let statisticsInspectionReport = DocumentInspectionBuilder.build(
    document: statisticsInspectionDocument,
    renderResult: statisticsInspectionResult
)
verify(statisticsInspectionReport.statistics.headingLevels[2] == 6, "inspection statistics should count heading levels")
verify(statisticsInspectionReport.statistics.linkCount == 1, "inspection statistics should count rendered links")
verify(statisticsInspectionReport.statistics.imageCount == 1, "inspection statistics should count rendered images")
verify(statisticsInspectionReport.statistics.codeBlockCount == 2, "inspection statistics should count fenced code blocks")
verify(statisticsInspectionReport.statistics.tableCount == 1, "inspection statistics should count tables")
verify(statisticsInspectionReport.statistics.calloutCount == 1, "inspection statistics should count GitHub callouts")
verify(statisticsInspectionReport.statistics.mermaidDiagramCount == 1, "inspection statistics should count Mermaid diagrams")
verify(statisticsInspectionReport.statistics.mathExpressionCount == 2, "inspection statistics should count math expressions")
verify(statisticsInspectionReport.exportReadiness.isReady, "rich statistics fixture should be export-ready")

let referenceInspectionURL = URL(fileURLWithPath: "Fixtures/Markdown/inspection-links-assets.md").standardizedFileURL
let referenceInspectionDocument = try MarkdownDocumentLoader.load(url: referenceInspectionURL, createBookmark: false)
let referenceInspectionResult = try renderer.render(RenderRequest(document: referenceInspectionDocument))
let referenceInspectionReport = DocumentInspectionBuilder.build(
    document: referenceInspectionDocument,
    renderResult: referenceInspectionResult
)
verify(referenceInspectionReport.metadata.frontMatterFormat == .toml, "inspection should support TOML front matter")
verify(referenceInspectionReport.links.contains { $0.target == "README.md" && $0.status == .valid }, "inspection should mark existing local links valid")
verify(referenceInspectionReport.links.contains { $0.target == "#asset-section" && $0.status == .valid }, "inspection should mark existing heading links valid")
verify(referenceInspectionReport.links.contains { $0.target == "missing-guide.md" && $0.status == .missing }, "inspection should mark missing local links")
verify(referenceInspectionReport.links.contains { $0.target == "https://example.com/openmarked" && $0.status == .skipped }, "inspection should mark remote links as skipped")
verify(referenceInspectionReport.links.contains { $0.target == "https://" && $0.status == .malformed }, "inspection should mark malformed links")
verify(referenceInspectionReport.links.contains { $0.target == "javascript:alert" && $0.status == .unsupported }, "inspection should mark unsupported schemes")
verify(referenceInspectionReport.assets.contains { $0.source == "../Assets/sample-mark.svg" && $0.status == .valid }, "inspection should mark existing local images valid")
verify(referenceInspectionReport.assets.contains { $0.source == "../Assets/missing-image.png" && $0.status == .missing }, "inspection should mark missing local images")
verify(referenceInspectionReport.assets.contains { $0.source == "https://example.com/openmarked.png" && $0.kind == .remoteImage && $0.status == .skipped }, "inspection should mark remote images as skipped")
verify(!referenceInspectionReport.exportReadiness.isReady, "inspection should block readiness for missing references")
verify(referenceInspectionReport.exportReadiness.issues.contains { $0.title == "Missing local link" && $0.source == "missing-guide.md" }, "readiness should include missing local links")
verify(referenceInspectionReport.exportReadiness.issues.contains { $0.title == "Missing image" && $0.source == "../Assets/missing-image.png" }, "readiness should include missing images")
verify(referenceInspectionReport.exportReadiness.issues.contains { $0.title == "Remote image" && $0.source == "https://example.com/openmarked.png" }, "readiness should include remote images as informational")

let mermaidURL = URL(fileURLWithPath: "Fixtures/Markdown/mermaid.md").standardizedFileURL
let mermaidDocument = try MarkdownDocumentLoader.load(url: mermaidURL, createBookmark: false)
let mermaidResult = try renderer.render(RenderRequest(document: mermaidDocument))
verify(mermaidResult.richMarkdownState.requiresMermaidRuntime, "Mermaid fixture should require the Mermaid runtime")
verify(mermaidResult.bodyHTML.contains(#"id="om-mermaid-1""#), "Mermaid fixture should include the first placeholder")
verify(mermaidResult.bodyHTML.contains(#"id="om-mermaid-6""#), "Mermaid fixture should include all Mermaid placeholders")
verify(mermaidResult.bodyHTML.contains(#"class="om-code-block om-code-swift""#), "ordinary code in Mermaid fixture should still highlight")
verify(!mermaidResult.bodyHTML.contains("language-mermaid"), "Mermaid code fences should be consumed before code highlighting")
verify(mermaidResult.diagnostics.contains { $0.kind == .mermaidRenderFailure && $0.source == "om-mermaid-6" }, "broken Mermaid fixture diagram should produce a preflight diagnostic")
let mermaidExportHTML = HTMLExportDocumentBuilder.standaloneHTML(renderResult: mermaidResult, document: mermaidDocument)
verify(mermaidExportHTML.contains("data-openmarked-rich-content-runtime"), "Mermaid HTML export should embed the trusted runtime")
verify(mermaidExportHTML.contains(#"globalThis["mermaid"]"#), "Mermaid HTML export should embed the bundled Mermaid runtime")

let mathDetectionSamples = [
    "Inline math uses $E = mc^2$.",
    """
    $$
    \\sum_{n=1}^{10} n = 55
    $$
    """
]
let nonMathDetectionSamples = [
    #"Escaped dollars should stay literal: \$12.00."#,
    "Currency should stay literal: $12.00 and $13.50.",
    "Unmatched delimiters should stay literal: $x + 1.",
    "Code spans should stay literal: `$not_math$`.",
    "[Link text with $x$](https://example.com)",
    """
    ```swift
    let value = "$not_math$"
    ```
    """
]
verify(mathDetectionSamples.allSatisfy { MathDelimiterRules.containsMath(in: $0) }, "math delimiter rules should find inline and display math")
verify(nonMathDetectionSamples.allSatisfy { !MathDelimiterRules.containsMath(in: $0) }, "math delimiter rules should avoid common false positives")

let mathProcessorHTML = #"""
<p>Inline $E = mc^2$ and price $12.00.</p>
<p>Code <code>$not_math$</code> link <a href="/">$x$</a>.</p>
<p>$$
\sum_{n=1}^{10} n = 55
$$</p>
<p>Broken $\frac{1}{$.</p>
"""#
let mathProcessorResult = MathPostProcessor.process(mathProcessorHTML)
let disabledMathProcessorResult = MathPostProcessor.process("<p>$x$</p>", isEnabled: false)
verify(mathProcessorResult.expressionCount == 3, "math processor should build placeholders for inline, display, and invalid TeX expressions")
verify(mathProcessorResult.html.contains(#"class="om-math-inline""#), "math processor should build inline placeholders")
verify(mathProcessorResult.html.contains(#"class="om-math-display""#), "math processor should build display placeholders")
verify(mathProcessorResult.html.contains("price $12.00"), "math processor should preserve common currency text")
verify(mathProcessorResult.html.contains("<code>$not_math$</code>"), "math processor should skip code spans")
verify(mathProcessorResult.html.contains(#"<a href="/">$x$</a>"#), "math processor should skip links")
verify(mathProcessorResult.diagnostics.contains { $0.kind == .mathRenderFailure && $0.source == "om-math-3" }, "math processor should preflight obvious invalid TeX")
verify(disabledMathProcessorResult.html == "<p>$x$</p>", "math processor should be disableable")

let mathURL = URL(fileURLWithPath: "Fixtures/Markdown/math.md").standardizedFileURL
let mathDocument = try MarkdownDocumentLoader.load(url: mathURL, createBookmark: false)
let mathResult = try renderer.render(RenderRequest(document: mathDocument))
verify(mathResult.richMarkdownState.requiresMathRuntime, "math fixture should require the KaTeX runtime")
verify(mathResult.bodyHTML.contains(#"id="om-math-1""#), "math fixture should include the first placeholder")
verify(mathResult.bodyHTML.contains(#"id="om-math-2""#), "math fixture should include the display placeholder")
verify(mathResult.bodyHTML.contains(#"class="om-math-inline""#), "math fixture should include inline math markup")
verify(mathResult.bodyHTML.contains(#"class="om-math-display""#), "math fixture should include display math markup")
verify(mathResult.bodyHTML.contains("$12.00"), "math fixture should preserve escaped dollar text")
verify(mathResult.bodyHTML.contains("$not_math$"), "math fixture should preserve code-span dollars")
verify(mathResult.bodyHTML.contains("$x + 1"), "math fixture should preserve unmatched delimiters")
verify(!mathResult.diagnostics.contains { $0.kind == .mathRenderFailure }, "math fixture should avoid false math diagnostics")
let mathExportHTML = HTMLExportDocumentBuilder.standaloneHTML(renderResult: mathResult, document: mathDocument)
verify(mathExportHTML.contains("data-openmarked-rich-content-runtime"), "math HTML export should embed the trusted runtime")
verify(mathExportHTML.contains("katex-version"), "math HTML export should include KaTeX CSS")
verify(mathExportHTML.contains("KaTeX parse error"), "math HTML export should embed the bundled KaTeX runtime")

let linkExtractorHTML = ##"<p><a href="guide.md">Guide</a><code>&lt;a href=&quot;ignored.md&quot;&gt;</code><a href="#existing-heading">Heading</a><a href="">Empty</a></p>"##
let extractedLinks = LinkReferenceExtractor.linkReferences(from: linkExtractorHTML)
verify(extractedLinks.map(\.source) == ["guide.md", "#existing-heading"], "link extractor should read rendered anchors and ignore empty links")

let linksURL = URL(fileURLWithPath: "Fixtures/Markdown/links.md").standardizedFileURL
let linksDocument = try MarkdownDocumentLoader.load(url: linksURL, createBookmark: false)
let linksResult = try renderer.render(RenderRequest(document: linksDocument))
let linkDiagnosticKinds: Set<RenderDiagnosticKind> = [.missingLocalLink, .missingHeadingFragment, .malformedLink, .unsupportedLinkScheme, .linkValidationSkipped]
verify(!linksResult.diagnostics.contains { linkDiagnosticKinds.contains($0.kind) }, "valid links fixture should not produce link diagnostics")

let brokenLinksURL = URL(fileURLWithPath: "Fixtures/Markdown/broken-links.md").standardizedFileURL
let brokenLinksDocument = try MarkdownDocumentLoader.load(url: brokenLinksURL, createBookmark: false)
let brokenLinksResult = try renderer.render(RenderRequest(document: brokenLinksDocument))
verify(brokenLinksResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "#missing-heading" }, "broken links fixture should report missing same-document heading")
verify(brokenLinksResult.diagnostics.contains { $0.kind == .missingLocalLink && $0.source == "missing-guide.md" }, "broken links fixture should report missing local file")
verify(brokenLinksResult.diagnostics.contains { $0.kind == .missingLocalLink && $0.source == "../Assets/missing-image.png" }, "broken links fixture should report missing linked image file")
verify(brokenLinksResult.diagnostics.contains { $0.kind == .missingLocalImage && $0.source == "../Assets/missing-image.png" }, "broken links fixture should still report missing image diagnostics")
verify(brokenLinksResult.diagnostics.contains { $0.kind == .unsupportedLinkScheme && $0.source == "javascript:alert" }, "broken links fixture should report unsupported schemes")
verify(brokenLinksResult.diagnostics.contains { $0.kind == .malformedLink && $0.source == "https://" }, "broken links fixture should report malformed remote URLs")

let disabledLinkOptions = RichMarkdownOptions(validatesLocalLinks: false, validatesHeadingFragments: false)
let disabledLinkResult = try renderer.render(
    RenderRequest(
        document: brokenLinksDocument,
        options: RenderOptions(richMarkdownOptions: disabledLinkOptions)
    )
)
verify(!disabledLinkResult.diagnostics.contains { $0.kind == .missingLocalLink }, "local link validation should be disableable")
verify(!disabledLinkResult.diagnostics.contains { $0.kind == .missingHeadingFragment }, "heading link validation should be disableable")
verify(disabledLinkResult.diagnostics.contains { $0.kind == .missingLocalImage }, "image diagnostics should remain independent of link validation")

let linkValidationDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("OpenMarkedLinkValidation-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: linkValidationDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: linkValidationDirectory) }
let targetHeadingURL = linkValidationDirectory.appendingPathComponent("guide one.md")
try "# Target Heading\n\nBody.\n".write(to: targetHeadingURL, atomically: true, encoding: .utf8)
let sourceHeadingURL = linkValidationDirectory.appendingPathComponent("source.md")
try """
# Source

[Valid cross-doc heading](guide%20one.md?download=1#target-heading)
[Missing cross-doc heading](guide%20one.md#missing-heading)
[Missing current heading](source.md#missing-current)
""".write(to: sourceHeadingURL, atomically: true, encoding: .utf8)
let sourceHeadingDocument = try MarkdownDocumentLoader.load(url: sourceHeadingURL, createBookmark: false)
let sourceHeadingResult = try renderer.render(RenderRequest(document: sourceHeadingDocument))
verify(!sourceHeadingResult.diagnostics.contains { $0.kind == .missingLocalLink && ($0.source?.contains("guide%20one") ?? false) }, "percent-escaped local links should resolve")
verify(sourceHeadingResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "guide%20one.md#missing-heading" }, "cross-document missing headings should warn")
verify(sourceHeadingResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "source.md#missing-current" }, "current-file relative heading links should warn")
verify(!sourceHeadingResult.diagnostics.contains { $0.source == "guide%20one.md?download=1#target-heading" }, "valid cross-document heading links with queries should pass")

let profileDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("OpenMarkedProfileVerifier-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: profileDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: profileDirectory) }
let profileTargetURL = profileDirectory.appendingPathComponent("target.md")
let profileSourceURL = profileDirectory.appendingPathComponent("source.md")
try "# API_v2\n\nBody.\n".write(to: profileTargetURL, atomically: true, encoding: .utf8)
try "# Source\n\n[Target](target.md#api_v2)\n".write(to: profileSourceURL, atomically: true, encoding: .utf8)
let profileSourceDocument = try MarkdownDocumentLoader.load(url: profileSourceURL, createBookmark: false)
let openMarkedProfileResult = try renderer.render(RenderRequest(document: profileSourceDocument))
let gitHubProfileResult = try renderer.render(
    RenderRequest(
        document: profileSourceDocument,
        options: RenderOptions(renderProfile: .gitHubReadme)
    )
)
verify(openMarkedProfileResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#api_v2" }, "OpenMarked profile should use OpenMarked heading slugs for cross-document links")
verify(!gitHubProfileResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#api_v2" }, "GitHub README profile should use GitHub heading slugs for cross-document links")

let remoteLinkURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("openmarked-remote-link-\(UUID().uuidString).md")
try "# Remote\n\n[Remote](https://example.com/openmarked)\n".write(to: remoteLinkURL, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: remoteLinkURL) }
let remoteLinkDocument = try MarkdownDocumentLoader.load(url: remoteLinkURL, createBookmark: false)
let defaultRemoteLinkResult = try renderer.render(RenderRequest(document: remoteLinkDocument))
verify(!defaultRemoteLinkResult.diagnostics.contains { $0.kind == .linkValidationSkipped }, "remote link checks should be off by default")
let optInRemoteLinkResult = try renderer.render(
    RenderRequest(
        document: remoteLinkDocument,
        options: RenderOptions(richMarkdownOptions: RichMarkdownOptions(validatesRemoteLinks: true))
    )
)
verify(optInRemoteLinkResult.diagnostics.contains { $0.kind == .linkValidationSkipped && $0.source == "https://example.com/openmarked" }, "opt-in remote link validation should not crawl automatically")

let richDocumentURL = URL(fileURLWithPath: "Fixtures/Markdown/rich-markdown.md").standardizedFileURL
let richDocument = try MarkdownDocumentLoader.load(url: richDocumentURL, createBookmark: false)
let richResult = try renderer.render(RenderRequest(document: richDocument, theme: githubTheme))
let richExportHTML = HTMLExportDocumentBuilder.standaloneHTML(renderResult: richResult, document: richDocument)
verify(richResult.richMarkdownState.requiresMermaidRuntime, "rich Markdown fixture should require Mermaid runtime")
verify(richResult.richMarkdownState.requiresMathRuntime, "rich Markdown fixture should require KaTeX runtime")
verify(richExportHTML.contains("om-callout"), "rich HTML export should preserve GitHub callout markup")
verify(richExportHTML.contains("om-rich-content-assets"), "rich HTML export should include rich content CSS")
verify(richExportHTML.contains("katex-version"), "rich HTML export should include KaTeX CSS and font references")
verify(richExportHTML.contains("data-openmarked-rich-content-runtime"), "rich HTML export should embed the trusted runtime")
verify(richExportHTML.contains(#"globalThis["mermaid"]"#), "rich HTML export should embed bundled Mermaid JavaScript")
verify(richExportHTML.contains("KaTeX parse error"), "rich HTML export should embed bundled KaTeX JavaScript")
let richExportWithoutRuntime = HTMLExportDocumentBuilder.standaloneHTML(
    renderResult: richResult,
    document: richDocument,
    options: HTMLExportOptions(embedsRichContentRuntime: false)
)
verify(richExportWithoutRuntime.contains("om-rich-content-assets"), "rich HTML export without runtime should keep rich styles")
verify(!richExportWithoutRuntime.contains("data-openmarked-rich-content-runtime"), "rich HTML export should allow runtime embedding to be disabled")
let scriptedRichURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("openmarked-scripted-rich-\(UUID().uuidString).md")
try """
# Scripted Rich Export

<script src="https://example.com/user-script.js"></script>

```mermaid
flowchart LR
    A --> B
```

Inline math $x + 1$.
""".write(to: scriptedRichURL, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: scriptedRichURL) }
let scriptedRichDocument = try MarkdownDocumentLoader.load(url: scriptedRichURL, createBookmark: false)
let scriptedRichResult = try renderer.render(RenderRequest(document: scriptedRichDocument, theme: githubTheme))
let scriptedRichExportHTML = HTMLExportDocumentBuilder.standaloneHTML(
    renderResult: scriptedRichResult,
    document: scriptedRichDocument
)
verify(scriptedRichExportHTML.contains("data-openmarked-rich-content-runtime"), "scripted rich export should keep trusted runtime scripts")
verify(!scriptedRichExportHTML.lowercased().contains(#"<script src="https://example.com/user-script.js""#), "scripted rich export should remove user-authored scripts")
let disabledRichOptions = RichMarkdownOptions(rendersMermaid: false, rendersMath: false, rendersGitHubCallouts: false)
let disabledRichResult = try renderer.render(
    RenderRequest(
        document: richDocument,
        options: RenderOptions(richMarkdownOptions: disabledRichOptions)
    )
)
verify(disabledRichResult.richMarkdownState.documentFeatures.containsMermaid, "rich render state should detect Mermaid")
verify(disabledRichResult.richMarkdownState.documentFeatures.containsMath, "rich render state should detect math")
verify(disabledRichResult.richMarkdownState.documentFeatures.containsGitHubCallouts, "rich render state should detect callouts")
verify(disabledRichResult.diagnostics.filter { $0.kind == .richContentDisabled }.count == 3, "disabled rich rendering should produce focused diagnostics")

let calloutsURL = URL(fileURLWithPath: "Fixtures/Markdown/callouts.md").standardizedFileURL
let calloutsDocument = try MarkdownDocumentLoader.load(url: calloutsURL, createBookmark: false)
let calloutsResult = try renderer.render(RenderRequest(document: calloutsDocument))
verify(calloutsResult.richMarkdownState.documentFeatures.containsGitHubCallouts, "callout fixture should detect GitHub callouts")
verify(calloutsResult.bodyHTML.components(separatedBy: "class=\"om-callout ").count - 1 == 5, "callout fixture should render five supported callouts")
verify(calloutsResult.bodyHTML.contains("data-callout=\"note\""), "note callout should render")
verify(calloutsResult.bodyHTML.contains("data-callout=\"tip\""), "tip callout should render")
verify(calloutsResult.bodyHTML.contains("data-callout=\"important\""), "important callout should render")
verify(calloutsResult.bodyHTML.contains("data-callout=\"warning\""), "warning callout should render")
verify(calloutsResult.bodyHTML.contains("data-callout=\"caution\""), "caution callout should render")
verify(calloutsResult.bodyHTML.contains("[!QUESTION]"), "unknown callout markers should remain normal blockquotes")
verify(calloutsResult.fullHTML.contains(".om-callout"), "theme CSS should include callout styling")

let disabledCalloutsResult = try renderer.render(
    RenderRequest(
        document: calloutsDocument,
        options: RenderOptions(richMarkdownOptions: RichMarkdownOptions(rendersGitHubCallouts: false))
    )
)
verify(!disabledCalloutsResult.bodyHTML.contains("om-callout"), "disabled callouts should stay as blockquotes")
verify(disabledCalloutsResult.bodyHTML.contains("[!NOTE]"), "disabled callouts should preserve marker text")
verify(disabledCalloutsResult.diagnostics.contains { $0.kind == .richContentDisabled && $0.source == RichMarkdownFeature.gitHubCallouts.rawValue }, "disabled callouts should produce an informational diagnostic")

let malformedCalloutURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("openmarked-malformed-callout-\(UUID().uuidString).md")
try "# Malformed\n\n> [!NOTE\n> Missing bracket.\n\n> [!QUESTION]\n> Unknown marker stays quiet.\n".write(to: malformedCalloutURL, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: malformedCalloutURL) }
let malformedCalloutDocument = try MarkdownDocumentLoader.load(url: malformedCalloutURL, createBookmark: false)
let malformedCalloutResult = try renderer.render(RenderRequest(document: malformedCalloutDocument))
verify(malformedCalloutResult.diagnostics.contains { $0.kind == .malformedGitHubCallout && $0.source == "[!NOTE" }, "malformed supported callout marker should produce a diagnostic")
verify(malformedCalloutResult.diagnostics.filter { $0.kind == .malformedGitHubCallout }.count == 1, "malformed callout diagnostics should be low-noise")
verify(!malformedCalloutResult.bodyHTML.contains("om-callout-note"), "malformed callout marker should stay a blockquote")
verify(malformedCalloutResult.bodyHTML.contains("[!QUESTION]"), "unknown callout marker should stay quiet")

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
