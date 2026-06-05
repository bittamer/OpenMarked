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

    func testVersionIsMVPReleaseVersion() {
        XCTAssertEqual(AppInfo.version, "0.2.0")
        XCTAssertEqual(AppInfo.build, "2")
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
        let richOptions = RichMarkdownOptions(rendersMermaid: false, validatesRemoteLinks: true)
        store.save(
            ApplicationSettings(
                defaultThemeID: "missing",
                defaultFontScale: 4.0,
                isLivePreviewEnabled: false,
                richMarkdownOptions: richOptions
            )
        )

        let restored = store.load()
        XCTAssertEqual(restored.defaultThemeID, "default")
        XCTAssertEqual(restored.defaultFontScale, 2.0)
        XCTAssertFalse(restored.isLivePreviewEnabled)
        XCTAssertFalse(restored.richMarkdownOptions.rendersMermaid)
        XCTAssertTrue(restored.richMarkdownOptions.validatesRemoteLinks)

        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        store.saveLastDocumentURLs([url])
        XCTAssertEqual(store.loadLastDocumentURLs().first?.path, url.path)
    }

    func testApplicationSettingsDecodeOldPayloadWithRichMarkdownDefaults() throws {
        let data = Data(
            """
            {
              "defaultThemeID": "missing",
              "defaultFontScale": 4.0,
              "isLivePreviewEnabled": false
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(ApplicationSettings.self, from: data).normalized()

        XCTAssertEqual(decoded.defaultThemeID, "default")
        XCTAssertEqual(decoded.defaultFontScale, 2.0)
        XCTAssertFalse(decoded.isLivePreviewEnabled)
        XCTAssertEqual(decoded.richMarkdownOptions, .default)
        XCTAssertFalse(decoded.richMarkdownOptions.validatesRemoteLinks)
    }

    func testRichMarkdownOptionsDefaultsKeepNetworkValidationOff() {
        let options = RichMarkdownOptions.default

        XCTAssertTrue(options.rendersMermaid)
        XCTAssertTrue(options.rendersMath)
        XCTAssertTrue(options.rendersGitHubCallouts)
        XCTAssertTrue(options.validatesLocalLinks)
        XCTAssertTrue(options.validatesHeadingFragments)
        XCTAssertFalse(options.validatesRemoteLinks)
        XCTAssertTrue(RichMarkdownFeature.remoteLinkValidation.contactsNetwork)
    }

    func testRichMarkdownDocumentFeatureDetection() {
        let markdown = """
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

        let detected = RichMarkdownDocumentFeatures.detect(in: markdown)

        XCTAssertTrue(detected.containsMermaid)
        XCTAssertTrue(detected.containsMath)
        XCTAssertTrue(detected.containsGitHubCallouts)
        XCTAssertTrue(detected.containsLocalLinks)
        XCTAssertTrue(detected.containsHeadingLinks)
        XCTAssertTrue(detected.containsRemoteLinks)
    }

    func testRichMarkdownDisabledFeatureDiagnostics() {
        let documentFeatures = RichMarkdownDocumentFeatures(
            features: [.mermaid, .math, .gitHubCallouts, .localLinkValidation, .remoteLinkValidation]
        )
        let options = RichMarkdownOptions(
            rendersMermaid: false,
            rendersMath: false,
            rendersGitHubCallouts: false,
            validatesLocalLinks: false,
            validatesRemoteLinks: false
        )
        let state = RichMarkdownRenderState(options: options, documentFeatures: documentFeatures)

        XCTAssertEqual(state.disabledFeatureDiagnostics.count, 3)
        XCTAssertTrue(state.disabledFeatureDiagnostics.allSatisfy { $0.kind == .richContentDisabled })
        XCTAssertFalse(state.requiresRemoteValidation)
    }

    func testRenderDiagnosticKindsIncludeRichMarkdownFoundationKinds() {
        let expectedKinds: Set<RenderDiagnosticKind> = [
            .missingLocalImage,
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .unsupportedLinkScheme,
            .mermaidRenderFailure,
            .mathRenderFailure,
            .richContentDisabled,
            .malformedGitHubCallout,
            .linkValidationSkipped,
            .unsupportedExtension,
            .renderFailure
        ]

        XCTAssertEqual(Set(RenderDiagnosticKind.allCases), expectedKinds)
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

    func testRichMarkdownFixturesLoadAndRender() throws {
        let fixturePaths = [
            "Fixtures/Markdown/rich-markdown.md",
            "Fixtures/Markdown/mermaid.md",
            "Fixtures/Markdown/math.md",
            "Fixtures/Markdown/callouts.md",
            "Fixtures/Markdown/links.md",
            "Fixtures/Markdown/broken-links.md",
            "Fixtures/Markdown/github-readme-compat.md"
        ]

        let renderer = CMarkGFMRenderer()

        for path in fixturePaths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
            let result = try renderer.render(RenderRequest(document: document))

            XCTAssertFalse(document.bodyText.isEmpty, "\(path) should load source text")
            XCTAssertFalse(result.fullHTML.isEmpty, "\(path) should render full HTML")
        }
    }

    func testRendererReportsDisabledRichContent() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/rich-markdown.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let options = RichMarkdownOptions(rendersMermaid: false, rendersMath: false, rendersGitHubCallouts: false)
        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: options)
            )
        )

        XCTAssertTrue(result.richMarkdownState.documentFeatures.containsMermaid)
        XCTAssertTrue(result.richMarkdownState.documentFeatures.containsMath)
        XCTAssertTrue(result.richMarkdownState.documentFeatures.containsGitHubCallouts)
        XCTAssertEqual(result.diagnostics.filter { $0.kind == .richContentDisabled }.count, 3)
    }

    func testLinkReferenceExtractorFindsRenderedAnchors() {
        let html = ##"<p><a href="guide.md">Guide</a><code>&lt;a href=&quot;ignored.md&quot;&gt;</code><a href="#existing-heading">Heading</a><a href="">Empty</a></p>"##
        let references = LinkReferenceExtractor.linkReferences(from: html)

        XCTAssertEqual(references.map(\.source), ["guide.md", "#existing-heading"])
        XCTAssertEqual(references.map(\.text), ["Guide", "Heading"])
    }

    func testValidLinkFixtureProducesNoLinkDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/links.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let linkDiagnosticKinds: Set<RenderDiagnosticKind> = [
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .unsupportedLinkScheme,
            .linkValidationSkipped
        ]

        XCTAssertFalse(result.diagnostics.contains { linkDiagnosticKinds.contains($0.kind) })
    }

    func testBrokenLinkFixtureProducesLinkDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/broken-links.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "#missing-heading" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingLocalLink && $0.source == "missing-guide.md" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingLocalLink && $0.source == "../Assets/missing-image.png" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingLocalImage && $0.source == "../Assets/missing-image.png" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .unsupportedLinkScheme && $0.source == "javascript:alert" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .malformedLink && $0.source == "https://" })
    }

    func testLinkValidationHandlesPercentEscapesQueriesAndCrossDocumentHeadings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedLinkValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let targetURL = directory.appendingPathComponent("guide one.md")
        try "# Target Heading\n\nBody.\n".write(to: targetURL, atomically: true, encoding: .utf8)

        let sourceURL = directory.appendingPathComponent("source.md")
        try """
        # Source

        [Valid cross-doc heading](guide%20one.md?download=1#target-heading)
        [Missing cross-doc heading](guide%20one.md#missing-heading)
        [Missing current heading](source.md#missing-current)
        """.write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertFalse(result.diagnostics.contains { $0.kind == .missingLocalLink && $0.source.contains("guide%20one") })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "guide%20one.md#missing-heading" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "source.md#missing-current" })
        XCTAssertFalse(result.diagnostics.contains { $0.source == "guide%20one.md?download=1#target-heading" })
    }

    func testLinkValidationOptionsCanDisableLocalAndHeadingDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/broken-links.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let options = RichMarkdownOptions(validatesLocalLinks: false, validatesHeadingFragments: false)
        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: options)
            )
        )

        XCTAssertFalse(result.diagnostics.contains { $0.kind == .missingLocalLink })
        XCTAssertFalse(result.diagnostics.contains { $0.kind == .missingHeadingFragment })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingLocalImage })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .unsupportedLinkScheme })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .malformedLink })
    }

    func testRemoteLinkValidationIsOptInAndDoesNotCrawl() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-remote-link-\(UUID().uuidString).md")
        try "# Remote\n\n[Remote](https://example.com/openmarked)\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let defaultResult = try CMarkGFMRenderer().render(RenderRequest(document: document))
        XCTAssertFalse(defaultResult.diagnostics.contains { $0.kind == .linkValidationSkipped })

        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: RichMarkdownOptions(validatesRemoteLinks: true))
            )
        )

        XCTAssertTrue(result.diagnostics.contains { $0.kind == .linkValidationSkipped && $0.source == "https://example.com/openmarked" })
    }

    func testLargeCrossDocumentHeadingValidationIsSkipped() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedLargeLinkValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let largeTargetURL = directory.appendingPathComponent("large.md")
        try Data(repeating: 65, count: Int(LinkValidator.maxCrossDocumentHeadingFileSize) + 1).write(to: largeTargetURL)

        let sourceURL = directory.appendingPathComponent("source.md")
        try "# Source\n\n[Large](large.md#heading)\n".write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.diagnostics.contains { $0.kind == .linkValidationSkipped && $0.source == "large.md#heading" })
    }

    func testGitHubCalloutPostProcessorTransformsSupportedMarkers() {
        let html = """
        <blockquote>
        <p>[!NOTE]
        Notes provide useful context.</p>
        </blockquote>
        <blockquote>
        <p>This is ordinary.</p>
        </blockquote>
        """

        let result = GitHubCalloutPostProcessor.process(html, sourceMarkdown: "> [!NOTE]\n> Notes provide useful context.")

        XCTAssertTrue(result.html.contains(#"<aside class="om-callout om-callout-note" data-callout="note">"#))
        XCTAssertTrue(result.html.contains(#"<p class="om-callout-title">Note</p>"#))
        XCTAssertTrue(result.html.contains("<p>Notes provide useful context.</p>"))
        XCTAssertTrue(result.html.contains("<blockquote>"))
        XCTAssertFalse(result.html.contains("[!NOTE]"))
        XCTAssertTrue(result.diagnostics.isEmpty)
    }

    func testGitHubCalloutPostProcessorHandlesMultiParagraphCallouts() {
        let html = """
        <blockquote>
        <p>[!WARNING]</p>
        <p>First paragraph.</p>
        <ul>
        <li>Nested list item.</li>
        </ul>
        </blockquote>
        """

        let result = GitHubCalloutPostProcessor.process(html, sourceMarkdown: "> [!WARNING]\n>\n> First paragraph.")

        XCTAssertTrue(result.html.contains(#"om-callout-warning"#))
        XCTAssertTrue(result.html.contains("<p>First paragraph.</p>"))
        XCTAssertTrue(result.html.contains("<li>Nested list item.</li>"))
        XCTAssertFalse(result.html.contains("[!WARNING]"))
    }

    func testRendererTransformsGitHubCalloutFixture() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/callouts.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.richMarkdownState.documentFeatures.containsGitHubCallouts)
        XCTAssertEqual(result.bodyHTML.components(separatedBy: #"class="om-callout "#).count - 1, 5)
        XCTAssertTrue(result.bodyHTML.contains(#"data-callout="note""#))
        XCTAssertTrue(result.bodyHTML.contains(#"data-callout="tip""#))
        XCTAssertTrue(result.bodyHTML.contains(#"data-callout="important""#))
        XCTAssertTrue(result.bodyHTML.contains(#"data-callout="warning""#))
        XCTAssertTrue(result.bodyHTML.contains(#"data-callout="caution""#))
        XCTAssertTrue(result.bodyHTML.contains("<blockquote>"))
        XCTAssertTrue(result.bodyHTML.contains("[!QUESTION]"))
        XCTAssertTrue(result.fullHTML.contains(".om-callout"))
    }

    func testGitHubCalloutsCanBeDisabled() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/callouts.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let options = RichMarkdownOptions(rendersGitHubCallouts: false)
        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: options)
            )
        )

        XCTAssertFalse(result.bodyHTML.contains("om-callout"))
        XCTAssertTrue(result.bodyHTML.contains("[!NOTE]"))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .richContentDisabled && $0.source == RichMarkdownFeature.gitHubCallouts.rawValue })
    }

    func testMalformedGitHubCalloutDiagnostic() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-malformed-callout-\(UUID().uuidString).md")
        try "# Malformed\n\n> [!NOTE\n> Missing bracket.\n\n> [!QUESTION]\n> Unknown marker stays quiet.\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.diagnostics.contains { $0.kind == .malformedGitHubCallout && $0.source == "[!NOTE" })
        XCTAssertEqual(result.diagnostics.filter { $0.kind == .malformedGitHubCallout }.count, 1)
        XCTAssertFalse(result.bodyHTML.contains("om-callout-note"))
        XCTAssertTrue(result.bodyHTML.contains("[!QUESTION]"))
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

    @Test("QA hardening release uses 0.2.0 version")
    func versionIsMVPReleaseVersion() {
        #expect(AppInfo.version == "0.2.0")
        #expect(AppInfo.build == "2")
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
        let richOptions = RichMarkdownOptions(rendersMermaid: false, validatesRemoteLinks: true)
        store.save(
            ApplicationSettings(
                defaultThemeID: "missing",
                defaultFontScale: 4.0,
                isLivePreviewEnabled: false,
                richMarkdownOptions: richOptions
            )
        )

        let restored = store.load()
        #expect(restored.defaultThemeID == "default")
        #expect(restored.defaultFontScale == 2.0)
        #expect(!restored.isLivePreviewEnabled)
        #expect(!restored.richMarkdownOptions.rendersMermaid)
        #expect(restored.richMarkdownOptions.validatesRemoteLinks)

        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        store.saveLastDocumentURLs([url])
        #expect(store.loadLastDocumentURLs().first?.path == url.path)
    }

    @Test("Old settings payloads decode with rich Markdown defaults")
    func applicationSettingsDecodeOldPayloadWithRichMarkdownDefaults() throws {
        let data = Data(
            """
            {
              "defaultThemeID": "missing",
              "defaultFontScale": 4.0,
              "isLivePreviewEnabled": false
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(ApplicationSettings.self, from: data).normalized()

        #expect(decoded.defaultThemeID == "default")
        #expect(decoded.defaultFontScale == 2.0)
        #expect(!decoded.isLivePreviewEnabled)
        #expect(decoded.richMarkdownOptions == .default)
        #expect(!decoded.richMarkdownOptions.validatesRemoteLinks)
    }

    @Test("Rich Markdown defaults keep network validation off")
    func richMarkdownOptionsDefaultsKeepNetworkValidationOff() {
        let options = RichMarkdownOptions.default

        #expect(options.rendersMermaid)
        #expect(options.rendersMath)
        #expect(options.rendersGitHubCallouts)
        #expect(options.validatesLocalLinks)
        #expect(options.validatesHeadingFragments)
        #expect(!options.validatesRemoteLinks)
        #expect(RichMarkdownFeature.remoteLinkValidation.contactsNetwork)
    }

    @Test("Rich Markdown document feature detection finds planned 0.3 features")
    func richMarkdownDocumentFeatureDetection() {
        let markdown = """
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

        let detected = RichMarkdownDocumentFeatures.detect(in: markdown)

        #expect(detected.containsMermaid)
        #expect(detected.containsMath)
        #expect(detected.containsGitHubCallouts)
        #expect(detected.containsLocalLinks)
        #expect(detected.containsHeadingLinks)
        #expect(detected.containsRemoteLinks)
    }

    @Test("Disabled rich rendering produces low-noise diagnostics")
    func richMarkdownDisabledFeatureDiagnostics() {
        let documentFeatures = RichMarkdownDocumentFeatures(
            features: [.mermaid, .math, .gitHubCallouts, .localLinkValidation, .remoteLinkValidation]
        )
        let options = RichMarkdownOptions(
            rendersMermaid: false,
            rendersMath: false,
            rendersGitHubCallouts: false,
            validatesLocalLinks: false,
            validatesRemoteLinks: false
        )
        let state = RichMarkdownRenderState(options: options, documentFeatures: documentFeatures)

        #expect(state.disabledFeatureDiagnostics.count == 3)
        #expect(state.disabledFeatureDiagnostics.allSatisfy { $0.kind == .richContentDisabled })
        #expect(!state.requiresRemoteValidation)
    }

    @Test("Render diagnostic kinds include rich Markdown foundation kinds")
    func renderDiagnosticKindsIncludeRichMarkdownFoundationKinds() {
        let expectedKinds: Set<RenderDiagnosticKind> = [
            .missingLocalImage,
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .unsupportedLinkScheme,
            .mermaidRenderFailure,
            .mathRenderFailure,
            .richContentDisabled,
            .malformedGitHubCallout,
            .linkValidationSkipped,
            .unsupportedExtension,
            .renderFailure
        ]

        #expect(Set(RenderDiagnosticKind.allCases) == expectedKinds)
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

    @Test("Rich Markdown fixtures load and render")
    func richMarkdownFixturesLoadAndRender() throws {
        let fixturePaths = [
            "Fixtures/Markdown/rich-markdown.md",
            "Fixtures/Markdown/mermaid.md",
            "Fixtures/Markdown/math.md",
            "Fixtures/Markdown/callouts.md",
            "Fixtures/Markdown/links.md",
            "Fixtures/Markdown/broken-links.md",
            "Fixtures/Markdown/github-readme-compat.md"
        ]

        let renderer = CMarkGFMRenderer()

        for path in fixturePaths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
            let result = try renderer.render(RenderRequest(document: document))

            #expect(!document.bodyText.isEmpty)
            #expect(!result.fullHTML.isEmpty)
        }
    }

    @Test("Renderer reports disabled rich content")
    func rendererReportsDisabledRichContent() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/rich-markdown.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let options = RichMarkdownOptions(rendersMermaid: false, rendersMath: false, rendersGitHubCallouts: false)
        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: options)
            )
        )

        #expect(result.richMarkdownState.documentFeatures.containsMermaid)
        #expect(result.richMarkdownState.documentFeatures.containsMath)
        #expect(result.richMarkdownState.documentFeatures.containsGitHubCallouts)
        #expect(result.diagnostics.filter { $0.kind == .richContentDisabled }.count == 3)
    }

    @Test("Link reference extractor finds rendered anchors")
    func linkReferenceExtractorFindsRenderedAnchors() {
        let html = ##"<p><a href="guide.md">Guide</a><code>&lt;a href=&quot;ignored.md&quot;&gt;</code><a href="#existing-heading">Heading</a><a href="">Empty</a></p>"##
        let references = LinkReferenceExtractor.linkReferences(from: html)

        #expect(references.map(\.source) == ["guide.md", "#existing-heading"])
        #expect(references.map(\.text) == ["Guide", "Heading"])
    }

    @Test("Valid link fixture produces no link diagnostics")
    func validLinkFixtureProducesNoLinkDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/links.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let linkDiagnosticKinds: Set<RenderDiagnosticKind> = [
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .unsupportedLinkScheme,
            .linkValidationSkipped
        ]

        #expect(!result.diagnostics.contains { linkDiagnosticKinds.contains($0.kind) })
    }

    @Test("Broken link fixture produces link diagnostics")
    func brokenLinkFixtureProducesLinkDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/broken-links.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "#missing-heading" })
        #expect(result.diagnostics.contains { $0.kind == .missingLocalLink && $0.source == "missing-guide.md" })
        #expect(result.diagnostics.contains { $0.kind == .missingLocalLink && $0.source == "../Assets/missing-image.png" })
        #expect(result.diagnostics.contains { $0.kind == .missingLocalImage && $0.source == "../Assets/missing-image.png" })
        #expect(result.diagnostics.contains { $0.kind == .unsupportedLinkScheme && $0.source == "javascript:alert" })
        #expect(result.diagnostics.contains { $0.kind == .malformedLink && $0.source == "https://" })
    }

    @Test("Link validation handles percent escapes, queries, and cross-document headings")
    func linkValidationHandlesPercentEscapesQueriesAndCrossDocumentHeadings() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedLinkValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let targetURL = directory.appendingPathComponent("guide one.md")
        try "# Target Heading\n\nBody.\n".write(to: targetURL, atomically: true, encoding: .utf8)

        let sourceURL = directory.appendingPathComponent("source.md")
        try """
        # Source

        [Valid cross-doc heading](guide%20one.md?download=1#target-heading)
        [Missing cross-doc heading](guide%20one.md#missing-heading)
        [Missing current heading](source.md#missing-current)
        """.write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(!result.diagnostics.contains { $0.kind == .missingLocalLink && $0.source?.contains("guide%20one") == true })
        #expect(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "guide%20one.md#missing-heading" })
        #expect(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "source.md#missing-current" })
        #expect(!result.diagnostics.contains { $0.source == "guide%20one.md?download=1#target-heading" })
    }

    @Test("Link validation options can disable local and heading diagnostics")
    func linkValidationOptionsCanDisableLocalAndHeadingDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/broken-links.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let options = RichMarkdownOptions(validatesLocalLinks: false, validatesHeadingFragments: false)
        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: options)
            )
        )

        #expect(!result.diagnostics.contains { $0.kind == .missingLocalLink })
        #expect(!result.diagnostics.contains { $0.kind == .missingHeadingFragment })
        #expect(result.diagnostics.contains { $0.kind == .missingLocalImage })
        #expect(result.diagnostics.contains { $0.kind == .unsupportedLinkScheme })
        #expect(result.diagnostics.contains { $0.kind == .malformedLink })
    }

    @Test("Remote link validation is opt-in and does not crawl")
    func remoteLinkValidationIsOptInAndDoesNotCrawl() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-remote-link-\(UUID().uuidString).md")
        try "# Remote\n\n[Remote](https://example.com/openmarked)\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let defaultResult = try CMarkGFMRenderer().render(RenderRequest(document: document))
        #expect(!defaultResult.diagnostics.contains { $0.kind == .linkValidationSkipped })

        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: RichMarkdownOptions(validatesRemoteLinks: true))
            )
        )

        #expect(result.diagnostics.contains { $0.kind == .linkValidationSkipped && $0.source == "https://example.com/openmarked" })
    }

    @Test("Large cross-document heading validation is skipped")
    func largeCrossDocumentHeadingValidationIsSkipped() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedLargeLinkValidation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let largeTargetURL = directory.appendingPathComponent("large.md")
        try Data(repeating: 65, count: Int(LinkValidator.maxCrossDocumentHeadingFileSize) + 1).write(to: largeTargetURL)

        let sourceURL = directory.appendingPathComponent("source.md")
        try "# Source\n\n[Large](large.md#heading)\n".write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.diagnostics.contains { $0.kind == .linkValidationSkipped && $0.source == "large.md#heading" })
    }

    @Test("GitHub callout postprocessor transforms supported markers")
    func gitHubCalloutPostProcessorTransformsSupportedMarkers() {
        let html = """
        <blockquote>
        <p>[!NOTE]
        Notes provide useful context.</p>
        </blockquote>
        <blockquote>
        <p>This is ordinary.</p>
        </blockquote>
        """

        let result = GitHubCalloutPostProcessor.process(html, sourceMarkdown: "> [!NOTE]\n> Notes provide useful context.")

        #expect(result.html.contains(#"<aside class="om-callout om-callout-note" data-callout="note">"#))
        #expect(result.html.contains(#"<p class="om-callout-title">Note</p>"#))
        #expect(result.html.contains("<p>Notes provide useful context.</p>"))
        #expect(result.html.contains("<blockquote>"))
        #expect(!result.html.contains("[!NOTE]"))
        #expect(result.diagnostics.isEmpty)
    }

    @Test("GitHub callout postprocessor handles multi-paragraph callouts")
    func gitHubCalloutPostProcessorHandlesMultiParagraphCallouts() {
        let html = """
        <blockquote>
        <p>[!WARNING]</p>
        <p>First paragraph.</p>
        <ul>
        <li>Nested list item.</li>
        </ul>
        </blockquote>
        """

        let result = GitHubCalloutPostProcessor.process(html, sourceMarkdown: "> [!WARNING]\n>\n> First paragraph.")

        #expect(result.html.contains(#"om-callout-warning"#))
        #expect(result.html.contains("<p>First paragraph.</p>"))
        #expect(result.html.contains("<li>Nested list item.</li>"))
        #expect(!result.html.contains("[!WARNING]"))
    }

    @Test("Renderer transforms GitHub callout fixture")
    func rendererTransformsGitHubCalloutFixture() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/callouts.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.richMarkdownState.documentFeatures.containsGitHubCallouts)
        #expect(result.bodyHTML.components(separatedBy: #"class="om-callout "#).count - 1 == 5)
        #expect(result.bodyHTML.contains(#"data-callout="note""#))
        #expect(result.bodyHTML.contains(#"data-callout="tip""#))
        #expect(result.bodyHTML.contains(#"data-callout="important""#))
        #expect(result.bodyHTML.contains(#"data-callout="warning""#))
        #expect(result.bodyHTML.contains(#"data-callout="caution""#))
        #expect(result.bodyHTML.contains("<blockquote>"))
        #expect(result.bodyHTML.contains("[!QUESTION]"))
        #expect(result.fullHTML.contains(".om-callout"))
    }

    @Test("GitHub callouts can be disabled")
    func gitHubCalloutsCanBeDisabled() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/callouts.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let options = RichMarkdownOptions(rendersGitHubCallouts: false)
        let result = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(richMarkdownOptions: options)
            )
        )

        #expect(!result.bodyHTML.contains("om-callout"))
        #expect(result.bodyHTML.contains("[!NOTE]"))
        #expect(result.diagnostics.contains { $0.kind == .richContentDisabled && $0.source == RichMarkdownFeature.gitHubCallouts.rawValue })
    }

    @Test("Malformed GitHub callout marker produces one diagnostic")
    func malformedGitHubCalloutDiagnostic() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-malformed-callout-\(UUID().uuidString).md")
        try "# Malformed\n\n> [!NOTE\n> Missing bracket.\n\n> [!QUESTION]\n> Unknown marker stays quiet.\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.diagnostics.contains { $0.kind == .malformedGitHubCallout && $0.source == "[!NOTE" })
        #expect(result.diagnostics.filter { $0.kind == .malformedGitHubCallout }.count == 1)
        #expect(!result.bodyHTML.contains("om-callout-note"))
        #expect(result.bodyHTML.contains("[!QUESTION]"))
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
