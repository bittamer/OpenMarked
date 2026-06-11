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

    func testVersionIsCurrentReleaseVersion() {
        XCTAssertEqual(AppInfo.version, "0.5.1")
        XCTAssertEqual(AppInfo.build, "7")
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

    func testInspectorStateTransitions() {
        var state = DocumentWindowState()

        XCTAssertFalse(state.layout.isInspectorVisible)
        XCTAssertEqual(state.layout.selectedInspectorSection, .summary)

        state.toggleInspector()
        XCTAssertTrue(state.layout.isInspectorVisible)
        XCTAssertEqual(state.statusMessage, "Inspector shown")

        state.selectInspectorSection(.links)
        XCTAssertEqual(state.layout.selectedInspectorSection, .links)
        XCTAssertTrue(state.layout.isInspectorVisible)

        state.showInspector(section: .export)
        XCTAssertTrue(state.layout.isInspectorVisible)
        XCTAssertEqual(state.layout.selectedInspectorSection, .export)

        state.setInspectorVisible(false)
        XCTAssertFalse(state.layout.isInspectorVisible)
        XCTAssertEqual(state.layout.selectedInspectorSection, .export)
    }

    func testCurrentSectionStateTracksRenderedOutline() {
        var state = DocumentWindowState()
        let document = MarkdownDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/outline.md"),
            sourceText: "# One\n\n## Two\n",
            bodyText: "# One\n\n## Two\n",
            frontMatter: nil,
            metadata: DocumentFileMetadata(fileSize: 0, createdAt: nil, modifiedAt: nil),
            statistics: .empty,
            loadedAt: Date(timeIntervalSince1970: 0),
            securityScopedBookmark: nil
        )
        let rendered = RenderResult(
            bodyHTML: "",
            fullHTML: "",
            outline: [
                OutlineItem(id: "one", level: 1, title: "One"),
                OutlineItem(id: "two", level: 2, title: "Two")
            ],
            diagnostics: [],
            statistics: .empty,
            rendererName: "test",
            rendererVersion: nil
        )

        state.finishOpening(document: OpenedDocument(markdownDocument: document))
        state.finishRendering(rendered)
        state.updateCurrentSection(id: "two")

        XCTAssertEqual(state.currentSectionID, "two")
        XCTAssertEqual(state.currentOutlineItem?.title, "Two")

        let rerendered = RenderResult(
            bodyHTML: "",
            fullHTML: "",
            outline: [OutlineItem(id: "one", level: 1, title: "One")],
            diagnostics: [],
            statistics: .empty,
            rendererName: "test",
            rendererVersion: nil
        )
        state.finishRendering(rerendered)

        XCTAssertNil(state.currentSectionID)
        XCTAssertNil(state.currentOutlineItem)
    }

    func testWindowLayoutDecodesOldPayloadWithInspectorDefaults() throws {
        let data = Data(
            """
            {
              "isOutlineVisible": false,
              "selectedThemeID": "github",
              "fontScale": 1.2
            }
            """.utf8
        )

        let layout = try JSONDecoder().decode(WindowLayoutState.self, from: data)

        XCTAssertFalse(layout.isOutlineVisible)
        XCTAssertFalse(layout.isInspectorVisible)
        XCTAssertEqual(layout.selectedInspectorSection, .summary)
        XCTAssertEqual(layout.outlineDisplayOptions, .default)
        XCTAssertEqual(layout.selectedThemeID, "github")
        XCTAssertEqual(layout.fontScale, 1.2)

        let unknownSectionData = Data(
            """
            {
              "isInspectorVisible": true,
              "selectedInspectorSection": "futureSection"
            }
            """.utf8
        )
        let unknownSectionLayout = try JSONDecoder().decode(WindowLayoutState.self, from: unknownSectionData)
        XCTAssertTrue(unknownSectionLayout.isInspectorVisible)
        XCTAssertEqual(unknownSectionLayout.selectedInspectorSection, .summary)
    }

    func testMarkdownDocumentLoadsSourceAndStats() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        XCTAssertTrue(document.sourceText.contains("# OpenMarked Fixture README"))
        XCTAssertNil(document.frontMatter)
        XCTAssertEqual(document.firstHeadingTitle, "OpenMarked Fixture README")
        XCTAssertGreaterThan(document.statistics.wordCount, 0)
        XCTAssertGreaterThan(document.metadata.fileSize, 0)
    }

    func testFrontMatterIsParsedAndRemovedFromBody() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/front-matter.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        XCTAssertEqual(document.frontMatter?.format, .yaml)
        XCTAssertEqual(document.frontMatter?.title, "Fixture With Front Matter")
        XCTAssertEqual(document.displayTitle, "Fixture With Front Matter")
        XCTAssertEqual(document.resolvedTitle, "Fixture With Front Matter")
        XCTAssertEqual(document.resolvedTitleSource, .frontMatter)
        XCTAssertEqual(document.firstHeadingTitle, "Body Heading")
        XCTAssertFalse(document.bodyText.contains("description: Metadata"))
    }

    func testDocumentTitleUsesStoredMarkdownHeadingScannerMetadata() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-setext-title-\(UUID().uuidString).md")
        try """
        ```swift
        # Ignored Fence Heading
        ```

        Scanner Title
        =============

        Body text.
        """.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        XCTAssertEqual(document.firstHeadingTitle, "Scanner Title")
        XCTAssertEqual(document.resolvedTitle, "Scanner Title")
        XCTAssertEqual(document.resolvedTitleSource, .firstHeading)
    }

    func testTitleFallsBackToFirstHeadingForPreviewAndExport() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let exportedHTML = HTMLExportDocumentBuilder.standaloneHTML(renderResult: result, document: document)
        let report = DocumentInspectionBuilder.build(document: document, renderResult: result)

        XCTAssertEqual(document.displayTitle, "readme.md")
        XCTAssertEqual(document.resolvedTitle, "OpenMarked Fixture README")
        XCTAssertEqual(document.resolvedTitleSource, .firstHeading)
        XCTAssertTrue(result.fullHTML.contains("<title>OpenMarked Fixture README</title>"))
        XCTAssertTrue(exportedHTML.contains("<title>OpenMarked Fixture README</title>"))
        XCTAssertEqual(report.metadata.displayTitle, "OpenMarked Fixture README")
        XCTAssertEqual(report.metadata.titleSource, .firstHeading)
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
        let layout = WindowLayoutState(
            isOutlineVisible: false,
            isInspectorVisible: true,
            selectedInspectorSection: .metadata,
            outlineDisplayOptions: OutlineDisplayOptions(mode: .flat, maximumVisibleLevel: 3, showsAutoNumbers: true),
            selectedThemeID: "default",
            fontScale: 1.2
        )

        let exportDestinations = DocumentExportDestinations(
            html: URL(fileURLWithPath: "/tmp/openmarked-readme.html"),
            pdf: URL(fileURLWithPath: "/tmp/openmarked-readme.pdf")
        )
        store.save(
            document: document,
            layout: layout,
            frame: DocumentWindowFrame(x: 10, y: 20, width: 900, height: 600),
            exportDestinations: exportDestinations
        )

        let restored = store.restore(forDocumentID: document.id)
        XCTAssertEqual(restored?.layout, layout)
        XCTAssertEqual(restored?.layout.outlineDisplayOptions.mode, .flat)
        XCTAssertEqual(restored?.layout.outlineDisplayOptions.maximumVisibleLevel, 3)
        XCTAssertTrue(restored?.layout.outlineDisplayOptions.showsAutoNumbers == true)
        XCTAssertEqual(restored?.frame?.width, 900)
        XCTAssertEqual(restored?.exportDestinations, exportDestinations)
    }

    func testWindowStateStorePreservesMultipleDocumentsWhenUpdatingOne() throws {
        let suiteName = "OpenMarkedWindowStateTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "DocumentWindowState"
        let store = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: storageKey)
        let first = persistedWindowState(documentID: "/tmp/first.md", themeID: "github", width: 800, savedAt: 1)
        let second = persistedWindowState(documentID: "/tmp/second.md", themeID: "nord", width: 900, savedAt: 2)
        let updatedFirst = persistedWindowState(documentID: first.documentID, themeID: "dracula", width: 1_000, savedAt: 3)

        store.save(first)
        store.save(second)
        store.save(updatedFirst)

        XCTAssertEqual(store.restore(forDocumentID: first.documentID), updatedFirst)
        XCTAssertEqual(store.restore(forDocumentID: second.documentID), second)
        XCTAssertEqual(store.loadAll().count, 2)

        let reloadedStore = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: storageKey)
        XCTAssertEqual(reloadedStore.restore(forDocumentID: first.documentID), updatedFirst)
        XCTAssertEqual(reloadedStore.restore(forDocumentID: second.documentID), second)
    }

    func testWindowStateStoreFallsBackFromCorruptedPersistedData() throws {
        let suiteName = "OpenMarkedWindowStateCorruptionTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "DocumentWindowState"
        userDefaults.set(Data("not-json".utf8), forKey: storageKey)

        let store = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: storageKey)
        XCTAssertTrue(store.loadAll().isEmpty)
        XCTAssertNil(store.restore(forDocumentID: "/tmp/missing.md"))

        let replacement = persistedWindowState(documentID: "/tmp/recovered.md", themeID: "default", width: 700, savedAt: 4)
        store.save(replacement)

        let reloadedStore = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: storageKey)
        XCTAssertEqual(reloadedStore.loadAll(), [replacement.documentID: replacement])
    }

    func testWindowStateStoreDoesNotReloadDefaultsAfterInitialization() throws {
        let suiteName = "OpenMarkedWindowStateReadCountTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(CountingUserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "DocumentWindowState"
        let store = DocumentWindowStateStore(userDefaults: userDefaults, storageKey: storageKey)
        let first = persistedWindowState(documentID: "/tmp/first.md", themeID: "github", width: 800, savedAt: 1)
        let second = persistedWindowState(documentID: "/tmp/second.md", themeID: "nord", width: 900, savedAt: 2)

        XCTAssertEqual(userDefaults.dataReadCount, 1)

        store.save(first)
        store.save(second)
        _ = store.restore(forDocumentID: first.documentID)
        _ = store.loadAll()

        XCTAssertEqual(userDefaults.dataReadCount, 1)
    }

    private func persistedWindowState(
        documentID: String,
        themeID: String,
        width: Double,
        savedAt: TimeInterval
    ) -> PersistedDocumentWindowState {
        PersistedDocumentWindowState(
            documentID: documentID,
            sourceURL: URL(fileURLWithPath: documentID),
            bookmarkData: nil,
            layout: WindowLayoutState(selectedThemeID: themeID),
            frame: DocumentWindowFrame(x: 10, y: 20, width: width, height: 600),
            savedAt: Date(timeIntervalSince1970: savedAt)
        )
    }

    private final class CountingUserDefaults: UserDefaults {
        private(set) var dataReadCount = 0

        override func data(forKey defaultName: String) -> Data? {
            dataReadCount += 1
            return super.data(forKey: defaultName)
        }
    }

    func testApplicationSettingsStorePersistsAndNormalizesSettings() throws {
        let suiteName = "OpenMarkedSettingsTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = ApplicationSettingsStore(userDefaults: userDefaults, settingsKey: "Settings", lastDocumentPathsKey: "LastPaths")
        let richOptions = RichMarkdownOptions(rendersMermaid: false, validatesRemoteLinks: true)
        let printConfiguration = PrintConfiguration(
            pageSize: .a4,
            margins: PrintMargins(top: 0.1, right: 3.0, bottom: 0.7, left: 0.8),
            contentMaxWidth: 100,
            startsHeadingOneOnNewPage: true,
            startsHeadingTwoOnNewPage: true,
            includesDocumentTitle: true,
            themeMode: .defaultPrint
        )
        store.save(
            ApplicationSettings(
                defaultThemeID: "missing",
                appChromeThemeID: "tokyo-night",
                defaultFontScale: 4.0,
                isLivePreviewEnabled: false,
                renderProfile: .gitHubReadme,
                richMarkdownOptions: richOptions,
                statisticsWordsPerMinute: 999,
                includesFrontMatterInStatistics: true,
                printConfiguration: printConfiguration
            )
        )

        let restored = store.load()
        XCTAssertEqual(restored.defaultThemeID, "default")
        XCTAssertEqual(restored.appChromeThemeID, "tokyo-night")
        XCTAssertEqual(restored.defaultFontScale, 2.0)
        XCTAssertFalse(restored.isLivePreviewEnabled)
        XCTAssertEqual(restored.renderProfile, .gitHubReadme)
        XCTAssertFalse(restored.richMarkdownOptions.rendersMermaid)
        XCTAssertTrue(restored.richMarkdownOptions.validatesRemoteLinks)
        XCTAssertEqual(restored.statisticsWordsPerMinute, DocumentStatisticsOptions.maximumWordsPerMinute)
        XCTAssertTrue(restored.includesFrontMatterInStatistics)
        XCTAssertEqual(restored.documentStatisticsOptions.wordsPerMinute, DocumentStatisticsOptions.maximumWordsPerMinute)
        XCTAssertTrue(restored.documentStatisticsOptions.includesFrontMatter)
        XCTAssertEqual(restored.printConfiguration.pageSize, .a4)
        XCTAssertEqual(restored.printConfiguration.margins.top, PrintMargins.minimumInches)
        XCTAssertEqual(restored.printConfiguration.margins.right, PrintMargins.maximumInches)
        XCTAssertEqual(restored.printConfiguration.contentMaxWidth, PrintConfiguration.minimumContentMaxWidth)
        XCTAssertTrue(restored.printConfiguration.startsHeadingOneOnNewPage)
        XCTAssertTrue(restored.printConfiguration.startsHeadingTwoOnNewPage)
        XCTAssertTrue(restored.printConfiguration.includesDocumentTitle)
        XCTAssertEqual(restored.printConfiguration.themeMode, .defaultPrint)

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
        XCTAssertEqual(decoded.appChromeThemeID, "default")
        XCTAssertEqual(decoded.defaultFontScale, 2.0)
        XCTAssertFalse(decoded.isLivePreviewEnabled)
        XCTAssertEqual(decoded.renderProfile, .openMarked)
        XCTAssertEqual(decoded.richMarkdownOptions, .default)
        XCTAssertFalse(decoded.richMarkdownOptions.validatesRemoteLinks)
        XCTAssertEqual(decoded.statisticsWordsPerMinute, DocumentStatisticsOptions.defaultWordsPerMinute)
        XCTAssertFalse(decoded.includesFrontMatterInStatistics)
        XCTAssertEqual(decoded.printConfiguration, .default)
    }

    func testRenderProfileGroundworkAffectsHeadingAndLinkBehavior() throws {
        XCTAssertEqual(MarkdownRenderProfile.openMarked.displayName, "OpenMarked")
        XCTAssertEqual(MarkdownRenderProfile.gitHubReadme.headingSlugStyle, .gitHub)
        XCTAssertTrue(MarkdownRenderProfile.gitHubReadme.supportsGitHubCallouts)
        XCTAssertTrue(MarkdownRenderProfile.gitHubReadme.validatesHeadingLinksByDefault)
        XCTAssertEqual(HeadingPostProcessor.slug(for: "API_v2", style: .openMarked), "api-v2")
        XCTAssertEqual(HeadingPostProcessor.slug(for: "API_v2", style: .gitHub), "api_v2")

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedProfile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let targetURL = directory.appendingPathComponent("target.md")
        let sourceURL = directory.appendingPathComponent("source.md")
        try "# API_v2\n\nBody.\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try "# Source\n\n[Target](target.md#api_v2)\n".write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let openMarkedResult = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let gitHubResult = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(renderProfile: .gitHubReadme)
            )
        )

        XCTAssertTrue(openMarkedResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#api_v2" })
        XCTAssertFalse(gitHubResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#api_v2" })
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

    func testRichContentAssetStoreLoadsBundledResources() throws {
        let manifest = RichContentAssetStore.manifest()

        XCTAssertEqual(manifest.mermaid.version, "11.15.0")
        XCTAssertEqual(manifest.katex.version, "0.17.0")
        XCTAssertTrue(manifest.hasMermaidRuntime)
        XCTAssertTrue(manifest.hasKaTeXRuntime)
        XCTAssertTrue(manifest.hasKaTeXCSS)
        XCTAssertTrue(manifest.hasOpenMarkedRuntime)
        XCTAssertTrue(manifest.hasOpenMarkedCSS)
        XCTAssertGreaterThan(manifest.katexFontCount, 0)
        XCTAssertTrue(try RichContentAssetStore.mermaidRuntimeJavaScript().contains("mermaid"))
        XCTAssertTrue(try RichContentAssetStore.katexRuntimeJavaScript().contains("katex"))
        XCTAssertTrue(try RichContentAssetStore.openMarkedRuntimeJavaScript().contains("openMarkedRichContent"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try RichContentAssetStore.requiredResourceURL("RichContent/Mermaid/Mermaid-LICENSE").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try RichContentAssetStore.requiredResourceURL("RichContent/KaTeX/KaTeX-LICENSE").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: try RichContentAssetStore.requiredResourceURL("RichContent/KaTeX/fonts/KaTeX_Main-Regular.woff2").path))

        let katexCSS = try RichContentAssetStore.katexCSSForHTML()
        XCTAssertTrue(katexCSS.contains("file://"))
        XCTAssertTrue(katexCSS.contains("KaTeX_Main-Regular.woff2"))
    }

    func testRichContentHTMLAssetsAreConditional() throws {
        let plainHTML = HTMLDocumentAssembler.assemble(title: "Plain", bodyHTML: "<p>Plain</p>")
        XCTAssertFalse(plainHTML.contains("om-rich-content-assets"))
        XCTAssertFalse(plainHTML.contains("katex-version"))

        let state = RichMarkdownRenderState(
            documentFeatures: RichMarkdownDocumentFeatures(features: [.mermaid, .math])
        )
        let richHTML = HTMLDocumentAssembler.assemble(
            title: "Rich",
            bodyHTML: "<p>Rich</p>",
            richMarkdownState: state
        )

        XCTAssertTrue(richHTML.contains(#"id="om-rich-content-assets""#))
        XCTAssertTrue(richHTML.contains("data-openmarked-rich-content=\"math mermaid\""))
        XCTAssertTrue(richHTML.contains("katex-version"))
        XCTAssertTrue(try RichContentRuntimeAssembler.runtimeScripts(for: state).count == 3)
        XCTAssertTrue(RichContentRuntimeAssembler.invocationScript(for: state).contains("mermaid: true"))
        XCTAssertTrue(RichContentRuntimeAssembler.invocationScript(for: state).contains("katex: true"))
    }

    func testRichContentRuntimeStatusParsing() {
        let status = RichContentWebViewRuntime.status(
            from: [
                "ready": false,
                "timedOut": true,
                "errors": ["Timed out"]
            ],
            requestedFeatures: [.mermaid]
        )

        XCTAssertTrue(status.hasFailure)
        XCTAssertEqual(status.requestedFeatures, [.mermaid])
        XCTAssertEqual(status.userMessage, "Rich content rendering timed out")
    }

    func testRichContentPreviewStatusTransitions() {
        var state = DocumentWindowState()
        let richState = RichMarkdownRenderState(
            documentFeatures: RichMarkdownDocumentFeatures(features: [.mermaid, .math])
        )
        let result = RenderResult(
            bodyHTML: "<p>Rich</p>",
            fullHTML: "<!doctype html><p>Rich</p>",
            outline: [],
            diagnostics: [],
            statistics: .empty,
            rendererName: "test",
            rendererVersion: nil,
            richMarkdownState: richState
        )

        state.finishRendering(result)
        XCTAssertEqual(state.richContentPreview, .pending([.mermaid, .math]))
        state.beginRichContentRendering(features: [.mermaid, .math])
        XCTAssertEqual(state.richContentPreview, .rendering([.mermaid, .math]))
        XCTAssertEqual(state.statusMessage, "Rendering rich content")
        state.finishRichContentRendering(features: [.mermaid, .math])
        XCTAssertEqual(state.richContentPreview, .ready([.mermaid, .math]))
        state.failRichContentRendering("Rich content rendering failed")
        XCTAssertEqual(state.richContentPreview, .failed("Rich content rendering failed"))
    }

    func testMermaidPostProcessorBuildsPlaceholdersBeforeHighlighting() {
        let html = """
        <pre><code class="language-mermaid">flowchart LR
        A --&gt; B</code></pre>
        <pre><code class="language-swift">let value = 1</code></pre>
        """

        let result = MermaidPostProcessor.process(html)
        let highlighted = CodeHighlighter.highlight(result.html)

        XCTAssertEqual(result.diagramCount, 1)
        XCTAssertTrue(highlighted.contains(#"<figure class="om-mermaid" data-openmarked-rich="mermaid" id="om-mermaid-1">"#))
        XCTAssertTrue(highlighted.contains(#"<pre class="om-mermaid-source"><code>flowchart LR"#))
        XCTAssertTrue(highlighted.contains("A --&gt; B"))
        XCTAssertTrue(highlighted.contains(#"class="om-code-block om-code-swift""#))
        XCTAssertFalse(highlighted.contains(#"language-mermaid">flowchart"#))
    }

    func testRendererTransformsMermaidFixtureAndReportsPreflightDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/mermaid.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.richMarkdownState.requiresMermaidRuntime)
        XCTAssertTrue(result.bodyHTML.contains(#"id="om-mermaid-1""#))
        XCTAssertTrue(result.bodyHTML.contains(#"id="om-mermaid-6""#))
        XCTAssertTrue(result.bodyHTML.contains(#"class="om-code-block om-code-swift""#))
        XCTAssertFalse(result.bodyHTML.contains("language-mermaid"))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .mermaidRenderFailure && $0.source == "om-mermaid-6" })
    }

    func testMermaidStandaloneHTMLExportEmbedsTrustedRuntime() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/mermaid.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let html = HTMLExportDocumentBuilder.standaloneHTML(renderResult: result, document: document)

        XCTAssertTrue(html.contains("data-openmarked-rich-content-runtime"))
        XCTAssertTrue(html.contains("openMarkedRichContent"))
        XCTAssertTrue(html.contains(#"globalThis["mermaid"]"#))
        XCTAssertTrue(html.contains(#"data-openmarked-rich="mermaid""#))
    }

    func testMathDelimiterRulesAvoidCommonFalsePositives() {
        let mathSamples = [
            "Inline math uses $E = mc^2$.",
            """
            $$
            \\sum_{n=1}^{10} n = 55
            $$
            """
        ]

        let nonMathSamples = [
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

        XCTAssertTrue(mathSamples.allSatisfy { MathDelimiterRules.containsMath(in: $0) })
        XCTAssertTrue(nonMathSamples.allSatisfy { !MathDelimiterRules.containsMath(in: $0) })
    }

    func testMathPostProcessorBuildsPlaceholdersAndSkipsProtectedHTML() {
        let html = #"""
        <p>Inline $E = mc^2$ and price $12.00.</p>
        <p>Code <code>$not_math$</code> link <a href="/">$x$</a>.</p>
        <p>$$
        \sum_{n=1}^{10} n = 55
        $$</p>
        <p>Broken $\frac{1}{$.</p>
        """#

        let result = MathPostProcessor.process(html)
        let disabledResult = MathPostProcessor.process("<p>$x$</p>", isEnabled: false)

        XCTAssertEqual(result.expressionCount, 3)
        XCTAssertTrue(result.html.contains(#"class="om-math-inline""#))
        XCTAssertTrue(result.html.contains(#"class="om-math-display""#))
        XCTAssertTrue(result.html.contains(#"data-openmarked-rich="math""#))
        XCTAssertTrue(result.html.contains(#"data-openmarked-math-source="E = mc^2""#))
        XCTAssertTrue(result.html.contains("price $12.00"))
        XCTAssertTrue(result.html.contains("<code>$not_math$</code>"))
        XCTAssertTrue(result.html.contains(#"<a href="/">$x$</a>"#))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .mathRenderFailure && $0.source == "om-math-3" })
        XCTAssertEqual(disabledResult.expressionCount, 0)
        XCTAssertEqual(disabledResult.html, "<p>$x$</p>")
    }

    func testRendererTransformsMathFixtureAndPreservesNonMathDollars() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/math.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertTrue(result.richMarkdownState.requiresMathRuntime)
        XCTAssertTrue(result.bodyHTML.contains(#"id="om-math-1""#))
        XCTAssertTrue(result.bodyHTML.contains(#"id="om-math-2""#))
        XCTAssertTrue(result.bodyHTML.contains(#"class="om-math-inline""#))
        XCTAssertTrue(result.bodyHTML.contains(#"class="om-math-display""#))
        XCTAssertTrue(result.bodyHTML.contains("$12.00"))
        XCTAssertTrue(result.bodyHTML.contains("$not_math$"))
        XCTAssertTrue(result.bodyHTML.contains("$x + 1"))
        XCTAssertFalse(result.diagnostics.contains { $0.kind == .mathRenderFailure })
    }

    func testKaTeXStandaloneHTMLExportEmbedsTrustedRuntime() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/math.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let html = HTMLExportDocumentBuilder.standaloneHTML(renderResult: result, document: document)

        XCTAssertTrue(html.contains("data-openmarked-rich-content-runtime"))
        XCTAssertTrue(html.contains("openMarkedRichContent"))
        XCTAssertTrue(html.contains("katex-version"))
        XCTAssertTrue(html.contains("KaTeX parse error"))
        XCTAssertTrue(html.contains(#"data-openmarked-rich="math""#))
    }

    func testDocumentInspectionBuildsEmptyDocumentWithoutRenderResult() {
        let document = MarkdownDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/empty.md"),
            sourceText: "",
            bodyText: "",
            frontMatter: nil,
            metadata: DocumentFileMetadata(fileSize: 0, createdAt: nil, modifiedAt: nil),
            statistics: .empty,
            loadedAt: Date(timeIntervalSince1970: 0),
            securityScopedBookmark: nil
        )

        let report = DocumentInspectionBuilder.build(document: document)

        XCTAssertEqual(report.metadata.displayTitle, "empty.md")
        XCTAssertEqual(report.metadata.titleSource, .fileName)
        XCTAssertEqual(report.statistics, RichDocumentStatistics.empty)
        XCTAssertTrue(report.links.isEmpty)
        XCTAssertTrue(report.assets.isEmpty)
        XCTAssertTrue(report.exportReadiness.isReady)
    }

    func testDocumentInspectionBuildsMetadataReportWithoutRenderResult() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/metadata-rich.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, loadedAt: Date(timeIntervalSince1970: 0), createBookmark: false)
        let report = DocumentInspectionBuilder.build(document: document)

        XCTAssertEqual(report.metadata.displayTitle, "Workbench Metadata Fixture")
        XCTAssertEqual(report.metadata.titleSource, .frontMatter)
        XCTAssertEqual(report.metadata.frontMatterFormat, .yaml)
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "tags" && $0.value == "inspection, metadata, release" && $0.valueKind == .list && $0.tokens == ["inspection", "metadata", "release"] })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "draft" && $0.valueKind == .boolean && $0.value == "false" })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "date" && $0.valueKind == .date })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "priority" && $0.valueKind == .number && $0.value == "3" })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "aliases" && $0.valueKind == .list && $0.tokens == ["Workbench", "Document Inspector"] })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "options" && $0.valueKind == .object && $0.value.contains("mode: compact") })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "custom-field" && !$0.isStandard })
        XCTAssertTrue(report.metadata.fileFacts.contains { $0.key == "titleSource" && $0.value == "Front matter" })
        XCTAssertTrue(report.metadata.fileFacts.contains { $0.key == "path" && $0.value.hasSuffix("metadata-rich.md") })
        XCTAssertEqual(report.statistics.words, document.statistics.wordCount)
        XCTAssertEqual(report.statistics.linkCount, 0)
    }

    func testJSONFrontMatterIsParsedForMetadataInspection() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/json-front-matter.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let report = DocumentInspectionBuilder.build(document: document)

        XCTAssertEqual(document.frontMatter?.format, .json)
        XCTAssertEqual(document.resolvedTitle, "JSON Metadata Fixture")
        XCTAssertEqual(report.metadata.frontMatterFormat, .json)
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "tags" && $0.valueKind == .list && $0.tokens == ["json", "metadata"] })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "draft" && $0.valueKind == .boolean && $0.value == "false" })
        XCTAssertTrue(report.metadata.fields.contains { $0.key == "priority" && $0.valueKind == .number && $0.value == "2" })
    }

    func testMalformedFrontMatterProducesDiagnosticsWithoutBlockingRender() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/malformed-front-matter.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let report = DocumentInspectionBuilder.build(document: document, renderResult: result)

        XCTAssertEqual(document.frontMatter?.title, "Malformed Metadata Fixture")
        XCTAssertFalse(document.bodyText.contains("broken field without separator"))
        XCTAssertTrue(document.frontMatterDiagnostics.contains { $0.kind == .malformedFrontMatter && $0.source == "broken field without separator" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .malformedFrontMatter && $0.source == "broken field without separator" })
        XCTAssertTrue(report.diagnostics.contains { $0.kind == .malformedFrontMatter })
        XCTAssertFalse(report.exportReadiness.isReady)
        XCTAssertTrue(report.exportReadiness.issues.contains { $0.title == "Malformed front matter" })
    }

    func testDocumentInspectionReportsRichStatistics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/statistics-rich.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let report = DocumentInspectionBuilder.build(document: document, renderResult: result)

        XCTAssertGreaterThanOrEqual(report.statistics.headingCount, 6)
        XCTAssertEqual(report.statistics.linkCount, 1)
        XCTAssertEqual(report.statistics.imageCount, 1)
        XCTAssertEqual(report.statistics.codeBlockCount, 2)
        XCTAssertEqual(report.statistics.tableCount, 1)
        XCTAssertEqual(report.statistics.calloutCount, 1)
        XCTAssertEqual(report.statistics.mermaidDiagramCount, 1)
        XCTAssertEqual(report.statistics.mathExpressionCount, 2)
        XCTAssertEqual(report.statistics.headingLevels[2], 6)
        XCTAssertEqual(report.statistics.sectionStatistics.filter { $0.level == 2 }.count, 6)
        XCTAssertNotNil(report.statistics.longestSection)
        XCTAssertGreaterThanOrEqual(report.statistics.estimatedPageCount, 1)
        XCTAssertTrue(report.exportReadiness.isReady)
    }

    func testDocumentInspectionUsesReadingStatisticsOptions() throws {
        let bodyWords = Array(repeating: "body", count: 450).joined(separator: " ")
        let frontMatterWords = Array(repeating: "meta", count: 250).joined(separator: " ")
        let source = """
        ---
        title: Reading Options
        summary: \(frontMatterWords)
        ---
        # Reading Options

        \(bodyWords)
        """
        let parsed = FrontMatterParser.parse(source)
        let document = MarkdownDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/reading-options.md"),
            sourceText: source,
            bodyText: parsed.bodyText,
            frontMatter: parsed.frontMatter,
            metadata: DocumentFileMetadata(fileSize: Int64(source.utf8.count), createdAt: nil, modifiedAt: nil),
            statistics: DocumentStatisticsCalculator.calculate(bodyText: parsed.bodyText),
            loadedAt: Date(timeIntervalSince1970: 0),
            securityScopedBookmark: nil
        )

        let bodyOnlyReport = DocumentInspectionBuilder.build(document: document)
        let inclusiveReport = DocumentInspectionBuilder.build(
            document: document,
            statisticsOptions: DocumentStatisticsOptions(wordsPerMinute: 100, includesFrontMatter: true)
        )

        XCTAssertFalse(bodyOnlyReport.statistics.includesFrontMatter)
        XCTAssertTrue(inclusiveReport.statistics.includesFrontMatter)
        XCTAssertEqual(inclusiveReport.statistics.wordsPerMinute, 100)
        XCTAssertGreaterThan(inclusiveReport.statistics.words, bodyOnlyReport.statistics.words)
        XCTAssertGreaterThan(inclusiveReport.statistics.readingTimeMinutes, bodyOnlyReport.statistics.readingTimeMinutes)
    }

    func testDocumentInspectionReportsLinksAssetsAndReadiness() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/inspection-links-assets.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let report = DocumentInspectionBuilder.build(document: document, renderResult: result)

        XCTAssertEqual(report.metadata.displayTitle, "Inspection Links And Assets")
        XCTAssertEqual(report.metadata.frontMatterFormat, .toml)
        XCTAssertTrue(report.links.contains { $0.target == "README.md" && $0.status == .valid })
        XCTAssertTrue(report.links.contains { $0.target == "#asset-section" && $0.kind == .sameDocumentHeading && $0.status == .valid })
        XCTAssertTrue(report.links.contains { $0.target == "missing-guide.md" && $0.status == .missing })
        XCTAssertTrue(report.links.contains { $0.target == "https://example.com/openmarked" && $0.kind == .remoteURL && $0.status == .skipped })
        XCTAssertTrue(report.links.contains { $0.target == "https://" && $0.status == .malformed })
        XCTAssertTrue(report.links.contains { $0.target == "javascript:alert" && $0.status == .unsupported })
        XCTAssertTrue(report.assets.contains { $0.source == "../Assets/sample-mark.svg" && $0.status == .valid })
        XCTAssertTrue(report.assets.contains { $0.source == "../Assets/missing-image.png" && $0.status == .missing })
        XCTAssertTrue(report.assets.contains { $0.source == "https://example.com/openmarked.png" && $0.kind == .remoteImage && $0.status == .skipped })
        XCTAssertTrue(report.links.contains { $0.target == "README.md" && $0.resolvedPath?.hasSuffix("Fixtures/Markdown/README.md") == true })
        let localAsset = try XCTUnwrap(report.assets.first { $0.source == "../Assets/sample-mark.svg" })
        XCTAssertTrue(localAsset.resolvedPath?.hasSuffix("Fixtures/Assets/sample-mark.svg") == true)
        XCTAssertGreaterThan(localAsset.fileInfo?.byteSize ?? 0, 0)
        XCTAssertEqual(localAsset.fileInfo?.pixelWidth, 640)
        XCTAssertEqual(localAsset.fileInfo?.pixelHeight, 360)
        XCTAssertFalse(report.exportReadiness.isReady)
        XCTAssertTrue(report.exportReadiness.issues.contains { $0.title == "Missing local link" && $0.source == "missing-guide.md" })
        XCTAssertTrue(report.exportReadiness.issues.contains { $0.title == "Missing image" && $0.source == "../Assets/missing-image.png" })
        XCTAssertTrue(report.exportReadiness.issues.contains { $0.title == "Remote image" && $0.source == "https://example.com/openmarked.png" })
    }

    func testExportReadinessReportsBlockedRemoteImages() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("openmarked-blocked-remote-image-\(UUID().uuidString).md")
        try "# Remote\n\n![Remote](https://example.com/image.png)\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document, allowsRemoteImages: false))
        let report = DocumentInspectionBuilder.build(document: document, renderResult: result)

        XCTAssertTrue(report.assets.contains { $0.source == "https://example.com/image.png" && $0.status == .blocked })
        XCTAssertFalse(report.exportReadiness.isReady)
        XCTAssertTrue(report.exportReadiness.issues.contains { $0.title == "Remote image blocked" && $0.source == "https://example.com/image.png" })
    }

    func testRenderDiagnosticKindsIncludeRichMarkdownFoundationKinds() {
        let expectedKinds: Set<RenderDiagnosticKind> = [
            .missingLocalImage,
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .malformedFrontMatter,
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
            "Fixtures/Markdown/github-readme-compat.md",
            "Fixtures/Markdown/metadata-rich.md",
            "Fixtures/Markdown/malformed-front-matter.md",
            "Fixtures/Markdown/json-front-matter.md"
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

    func testRenderedHTMLIndexCollectsLinksImagesAndCounts() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let html = ##"""
        <p><a href='guide.md'>Guide <strong>Now</strong></a></p>
        <p><img src="../Assets/sample-mark.svg" alt="Sample mark"></p>
        <p><img src="about:blank" data-openmarked-blocked-src="https://example.com/blocked.png" alt="Blocked"></p>
        <table><tr><td>Cell</td></tr></table>
        """##

        let index = RenderedHTMLIndex.build(from: html, document: document)

        XCTAssertEqual(index.links.map(\.source), ["guide.md"])
        XCTAssertEqual(index.links.map(\.text), ["Guide Now"])
        XCTAssertEqual(index.images.map(\.source), ["../Assets/sample-mark.svg", "https://example.com/blocked.png"])
        XCTAssertEqual(index.images.map(\.altText), ["Sample mark", "Blocked"])
        XCTAssertTrue(index.images[1].isBlocked)
        XCTAssertTrue(index.localImageURLs.contains { $0.lastPathComponent == "sample-mark.svg" })
        XCTAssertEqual(index.paragraphCount, 3)
        XCTAssertEqual(index.tableCount, 1)
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

    func testCrossDocumentHeadingValidationScansMarkdownWithoutRenderingTarget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedHeadingScanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let targetURL = directory.appendingPathComponent("target.md")
        try """
        ---
        title: Target
        ---

        Setext Target
        =============

        Duplicate
        ---------

        Duplicate
        ---------

        ```
        # Hidden Heading
        ```

        <h3 id="custom-html">HTML Heading</h3>
        """.write(to: targetURL, atomically: true, encoding: .utf8)

        let sourceURL = directory.appendingPathComponent("source.md")
        try """
        # Source

        [Setext](target.md#setext-target)
        [Duplicate](target.md#duplicate)
        [Duplicate 2](target.md#duplicate-1)
        [HTML](target.md#custom-html)
        [Hidden](target.md#hidden-heading)
        """.write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        XCTAssertFalse(result.diagnostics.contains { $0.source == "target.md#setext-target" })
        XCTAssertFalse(result.diagnostics.contains { $0.source == "target.md#duplicate" })
        XCTAssertFalse(result.diagnostics.contains { $0.source == "target.md#duplicate-1" })
        XCTAssertFalse(result.diagnostics.contains { $0.source == "target.md#custom-html" })
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#hidden-heading" })
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

        XCTAssertEqual(
            AppChromeThemeStore.allBuiltInThemes.map(\.id),
            ["default", "catppuccin", "tokyo-night", "everforest", "nord", "rose-pine", "dracula", "gruvbox"]
        )
        XCTAssertEqual(
            AppChromeThemeStore.builtInThemeIDs,
            ["default", "catppuccin", "tokyo-night", "everforest", "nord", "rose-pine", "dracula", "gruvbox"]
        )
        XCTAssertTrue(AppChromeThemeStore.isBuiltInThemeID("tokyo-night"))
        XCTAssertFalse(AppChromeThemeStore.isBuiltInThemeID("missing"))
        XCTAssertEqual(AppChromeThemeStore.allBuiltInThemes, AppChromeThemeStore.allBuiltInThemes)
        XCTAssertEqual(AppChromeThemeStore.theme(id: "missing").id, "default")
        XCTAssertEqual(ApplicationSettings(appChromeThemeID: "tokyo-night").normalized().appChromeThemeID, "tokyo-night")
        XCTAssertEqual(
            PreviewThemeStore.allBuiltInThemes.map(\.id),
            ["default", "github", "minimal", "catppuccin", "tokyo-night", "everforest", "nord", "rose-pine", "dracula", "gruvbox"]
        )
        XCTAssertEqual(PreviewThemeStore.theme(id: "missing").id, "default")
        XCTAssertTrue(result.fullHTML.contains("--om-font-scale: 1.300"))
        XCTAssertTrue(result.fullHTML.contains("Segoe UI"))
    }

    func testUserPreviewThemeStoreImportsValidatesAndPersistsThemes() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-theme-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let suiteName = "OpenMarkedUserThemeTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let importURL = rootURL.appendingPathComponent("Fixture.css")
        try "body { color: #123456; }\n".write(to: importURL, atomically: true, encoding: .utf8)
        let managedURL = rootURL.appendingPathComponent("Managed", isDirectory: true)
        let store = UserPreviewThemeStore(userDefaults: userDefaults, metadataKey: "Themes", themesDirectoryURL: managedURL)

        let imported = try store.importTheme(from: importURL, name: "Fixture Theme")
        XCTAssertTrue(imported.id.hasPrefix(UserPreviewTheme.idPrefix))
        XCTAssertEqual(store.load(), [imported])
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.screenCSSPath))
        XCTAssertTrue(store.previewTheme(for: imported).screenCSS.contains("#123456"))

        try "body { color: #654321; background: #abcdef; }\n".write(
            to: URL(fileURLWithPath: imported.screenCSSPath),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertTrue(store.previewTheme(for: imported).screenCSS.contains("#654321"))

        let reloadedStore = UserPreviewThemeStore(userDefaults: userDefaults, metadataKey: "Themes", themesDirectoryURL: managedURL)
        XCTAssertEqual(reloadedStore.load(), [imported])

        try "body { background-image: url(javascript:alert(1)); }\n".write(
            to: URL(fileURLWithPath: imported.screenCSSPath),
            atomically: true,
            encoding: .utf8
        )
        XCTAssertEqual(store.previewTheme(for: imported).screenCSS, PreviewThemeStore.defaultTheme.screenCSS)

        let remoteImportURL = rootURL.appendingPathComponent("Remote.css")
        try "@import url(\"https://example.com/theme.css\");\n".write(to: remoteImportURL, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try store.importTheme(from: remoteImportURL)) { error in
            XCTAssertEqual(error as? UserPreviewThemeError, .importRulesUnsupported)
        }

        let renamed = try store.renameTheme(id: imported.id, name: "Renamed Fixture")
        XCTAssertEqual(renamed.name, "Renamed Fixture")

        let duplicate = try store.duplicateBuiltInTheme(id: "github", name: "GitHub Fork")
        XCTAssertTrue(FileManager.default.fileExists(atPath: duplicate.screenCSSPath))
        XCTAssertNotNil(duplicate.codeCSSPath)
        XCTAssertNotNil(duplicate.printCSSPath)

        try store.deleteTheme(id: renamed.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: renamed.screenCSSPath))
        XCTAssertEqual(store.load().map(\.id), [duplicate.id])
    }

    func testUserThemeIDsSurviveSettingsNormalization() {
        let userThemeID = "\(UserPreviewTheme.idPrefix)fixture"
        let settings = ApplicationSettings(defaultThemeID: userThemeID, defaultFontScale: 1.25)
        let normalized = settings.normalized()

        XCTAssertEqual(normalized.defaultThemeID, userThemeID)
        XCTAssertEqual(normalized.defaultLayout.selectedThemeID, userThemeID)
        XCTAssertEqual(ApplicationSettings(defaultThemeID: "missing").normalized().defaultThemeID, "default")
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

    func testOutlineDisplayBuilderAppliesDisplayOptions() {
        let outline = [
            OutlineItem(id: "intro", level: 1, title: "Introduction"),
            OutlineItem(id: "goals", level: 2, title: "Goals"),
            OutlineItem(id: "details", level: 3, title: "Implementation Details"),
            OutlineItem(id: "api", level: 2, title: "API")
        ]

        let hierarchical = OutlineDisplayBuilder.items(outline: outline)
        XCTAssertEqual(hierarchical.map(\.id), ["intro", "goals", "details", "api"])
        XCTAssertEqual(hierarchical.map(\.displayTitle), ["Introduction", "Goals", "Implementation Details", "API"])
        XCTAssertEqual(hierarchical.map(\.indentationLevel), [0, 1, 2, 1])

        let collapsed = OutlineDisplayBuilder.items(
            outline: outline,
            options: OutlineDisplayOptions(maximumVisibleLevel: 2)
        )
        XCTAssertEqual(collapsed.map(\.id), ["intro", "goals", "api"])

        let flatNumbered = OutlineDisplayBuilder.items(
            outline: outline,
            options: OutlineDisplayOptions(mode: .flat, maximumVisibleLevel: 6, showsAutoNumbers: true)
        )
        XCTAssertEqual(flatNumbered.map(\.displayTitle), ["1 Introduction", "1.1 Goals", "1.1.1 Implementation Details", "1.2 API"])
        XCTAssertEqual(flatNumbered.map(\.indentationLevel), [0, 0, 0, 0])

        let flatUnnumbered = OutlineDisplayBuilder.items(
            outline: outline,
            options: OutlineDisplayOptions(mode: .flat, maximumVisibleLevel: 6, showsAutoNumbers: false)
        )
        XCTAssertEqual(flatUnnumbered.map(\.displayTitle), ["Introduction", "Goals", "Implementation Details", "API"])

        let filtered = OutlineDisplayBuilder.items(
            outline: outline,
            query: "details",
            options: OutlineDisplayOptions(maximumVisibleLevel: 2)
        )
        XCTAssertEqual(filtered.map(\.id), ["details"])
        XCTAssertEqual(filtered.map(\.indentationLevel), [0])
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

    func testPrintConfigurationAppliesToStandaloneHTML() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let configuration = PrintConfiguration(
            pageSize: .a4,
            margins: PrintMargins(top: 0.5, right: 0.6, bottom: 0.7, left: 0.8),
            contentMaxWidth: 700,
            startsHeadingOneOnNewPage: true,
            startsHeadingTwoOnNewPage: true,
            includesDocumentTitle: true,
            themeMode: .defaultPrint
        )

        let html = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: result,
            document: document,
            options: HTMLExportOptions(printConfiguration: configuration)
        )

        XCTAssertTrue(html.contains("om-print-document-title"))
        XCTAssertTrue(html.contains("OpenMarked Fixture README"))
        XCTAssertTrue(html.contains("om-print-include-title om-print-break-h1 om-print-break-h2 om-print-limit-width om-print-default-theme"))
        XCTAssertTrue(html.contains("size: A4;"))
        XCTAssertTrue(html.contains("margin: 0.50in 0.60in 0.70in 0.80in;"))
        XCTAssertTrue(html.contains("max-width: min(700px, 100%);"))
        XCTAssertTrue(html.contains("break-before: page;"))

        let unstyledHTML = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: result,
            document: document,
            options: HTMLExportOptions(embedsThemeCSS: false, printConfiguration: configuration)
        )
        XCTAssertFalse(unstyledHTML.contains("om-print-document-title"))
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
        let unsafeHTML = #"""
        <h1 onclick="alert(1)" onmouseover='alert(2)' ONFOCUS=alert(3)>Title</h1>
        <a href="java&#x73;cript:alert(1)">bad link</a>
        <a href="java&#10;script:alert(1)">control-obfuscated bad link</a>
        <a href="java&Tab;script:alert(1)">named-whitespace bad link</a>
        <a href="vbscript:msgbox(1)">bad vbscript link</a>
        <img srcset="javascript:alert(1) 1x" alt="bad srcset">
        <form formaction="data:text/html,<b>bad</b>"></form>
        <script src="https://example.com/x.js"></script>
        <a href="https://example.com/#safe">safe link</a>
        <a href="#fragment">safe fragment</a>
        <a href="notes/page.md">safe relative</a>
        <a href="mailto:team@example.com">safe mail</a>
        <a href="file:///tmp/openmarked.md">safe file</a>
        <img src="data:image/png;base64,AAAA" alt="safe image">
        """#
        let sanitizedHTML = PreviewHTMLSecurityPolicy.sanitize(unsafeHTML)
        let lowercasedHTML = sanitizedHTML.lowercased()

        XCTAssertFalse(lowercasedHTML.contains("<script"))
        XCTAssertFalse(lowercasedHTML.contains("onclick"))
        XCTAssertFalse(lowercasedHTML.contains("onmouseover"))
        XCTAssertFalse(lowercasedHTML.contains("onfocus"))
        XCTAssertFalse(lowercasedHTML.contains("javascript:"))
        XCTAssertFalse(lowercasedHTML.contains("java&#10;script:"))
        XCTAssertFalse(lowercasedHTML.contains("java&tab;script:"))
        XCTAssertFalse(lowercasedHTML.contains("vbscript:"))
        XCTAssertFalse(lowercasedHTML.contains("data:text/html"))
        XCTAssertTrue(sanitizedHTML.contains(#"href="https://example.com/#safe""#))
        XCTAssertTrue(sanitizedHTML.contains("href=\"#fragment\""))
        XCTAssertTrue(sanitizedHTML.contains(#"href="notes/page.md""#))
        XCTAssertTrue(sanitizedHTML.contains(#"href="mailto:team@example.com""#))
        XCTAssertTrue(sanitizedHTML.contains(#"href="file:///tmp/openmarked.md""#))
        XCTAssertTrue(sanitizedHTML.contains(#"src="data:image/png;base64,AAAA""#))
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

    @Test("Current release version is exposed")
    func versionIsCurrentReleaseVersion() {
        #expect(AppInfo.version == "0.5.1")
        #expect(AppInfo.build == "7")
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

    @Test("Current section state tracks rendered outline")
    func currentSectionStateTracksRenderedOutline() {
        var state = DocumentWindowState()
        let document = MarkdownDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/outline.md"),
            sourceText: "# One\n\n## Two\n",
            bodyText: "# One\n\n## Two\n",
            frontMatter: nil,
            metadata: DocumentFileMetadata(fileSize: 0, createdAt: nil, modifiedAt: nil),
            statistics: .empty,
            loadedAt: Date(timeIntervalSince1970: 0),
            securityScopedBookmark: nil
        )
        let rendered = RenderResult(
            bodyHTML: "",
            fullHTML: "",
            outline: [
                OutlineItem(id: "one", level: 1, title: "One"),
                OutlineItem(id: "two", level: 2, title: "Two")
            ],
            diagnostics: [],
            statistics: .empty,
            rendererName: "test",
            rendererVersion: nil
        )

        state.finishOpening(document: OpenedDocument(markdownDocument: document))
        state.finishRendering(rendered)
        state.updateCurrentSection(id: "two")

        #expect(state.currentSectionID == "two")
        #expect(state.currentOutlineItem?.title == "Two")

        let rerendered = RenderResult(
            bodyHTML: "",
            fullHTML: "",
            outline: [OutlineItem(id: "one", level: 1, title: "One")],
            diagnostics: [],
            statistics: .empty,
            rendererName: "test",
            rendererVersion: nil
        )
        state.finishRendering(rerendered)

        #expect(state.currentSectionID == nil)
        #expect(state.currentOutlineItem == nil)
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
        let printConfiguration = PrintConfiguration(
            pageSize: .a4,
            margins: PrintMargins(top: 0.1, right: 3.0, bottom: 0.7, left: 0.8),
            contentMaxWidth: 100,
            startsHeadingOneOnNewPage: true,
            startsHeadingTwoOnNewPage: true,
            includesDocumentTitle: true,
            themeMode: .defaultPrint
        )
        store.save(
            ApplicationSettings(
                defaultThemeID: "missing",
                appChromeThemeID: "tokyo-night",
                defaultFontScale: 4.0,
                isLivePreviewEnabled: false,
                renderProfile: .gitHubReadme,
                richMarkdownOptions: richOptions,
                statisticsWordsPerMinute: 999,
                includesFrontMatterInStatistics: true,
                printConfiguration: printConfiguration
            )
        )

        let restored = store.load()
        #expect(restored.defaultThemeID == "default")
        #expect(restored.appChromeThemeID == "tokyo-night")
        #expect(restored.defaultFontScale == 2.0)
        #expect(!restored.isLivePreviewEnabled)
        #expect(restored.renderProfile == .gitHubReadme)
        #expect(!restored.richMarkdownOptions.rendersMermaid)
        #expect(restored.richMarkdownOptions.validatesRemoteLinks)
        #expect(restored.statisticsWordsPerMinute == DocumentStatisticsOptions.maximumWordsPerMinute)
        #expect(restored.includesFrontMatterInStatistics)
        #expect(restored.documentStatisticsOptions.wordsPerMinute == DocumentStatisticsOptions.maximumWordsPerMinute)
        #expect(restored.documentStatisticsOptions.includesFrontMatter)
        #expect(restored.printConfiguration.pageSize == .a4)
        #expect(restored.printConfiguration.margins.top == PrintMargins.minimumInches)
        #expect(restored.printConfiguration.margins.right == PrintMargins.maximumInches)
        #expect(restored.printConfiguration.contentMaxWidth == PrintConfiguration.minimumContentMaxWidth)
        #expect(restored.printConfiguration.startsHeadingOneOnNewPage)
        #expect(restored.printConfiguration.startsHeadingTwoOnNewPage)
        #expect(restored.printConfiguration.includesDocumentTitle)
        #expect(restored.printConfiguration.themeMode == .defaultPrint)

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
        #expect(decoded.appChromeThemeID == "default")
        #expect(decoded.defaultFontScale == 2.0)
        #expect(!decoded.isLivePreviewEnabled)
        #expect(decoded.renderProfile == .openMarked)
        #expect(decoded.richMarkdownOptions == .default)
        #expect(!decoded.richMarkdownOptions.validatesRemoteLinks)
        #expect(decoded.statisticsWordsPerMinute == DocumentStatisticsOptions.defaultWordsPerMinute)
        #expect(!decoded.includesFrontMatterInStatistics)
        #expect(decoded.printConfiguration == .default)
    }

    @Test("Render profile groundwork affects heading and link behavior")
    func renderProfileGroundworkAffectsHeadingAndLinkBehavior() throws {
        #expect(MarkdownRenderProfile.openMarked.displayName == "OpenMarked")
        #expect(MarkdownRenderProfile.gitHubReadme.headingSlugStyle == .gitHub)
        #expect(MarkdownRenderProfile.gitHubReadme.supportsGitHubCallouts)
        #expect(MarkdownRenderProfile.gitHubReadme.validatesHeadingLinksByDefault)
        #expect(HeadingPostProcessor.slug(for: "API_v2", style: .openMarked) == "api-v2")
        #expect(HeadingPostProcessor.slug(for: "API_v2", style: .gitHub) == "api_v2")

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedProfile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let targetURL = directory.appendingPathComponent("target.md")
        let sourceURL = directory.appendingPathComponent("source.md")
        try "# API_v2\n\nBody.\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try "# Source\n\n[Target](target.md#api_v2)\n".write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let openMarkedResult = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let gitHubResult = try CMarkGFMRenderer().render(
            RenderRequest(
                document: document,
                options: RenderOptions(renderProfile: .gitHubReadme)
            )
        )

        #expect(openMarkedResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#api_v2" })
        #expect(!gitHubResult.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#api_v2" })
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

    @Test("Rich content asset store loads bundled resources")
    func richContentAssetStoreLoadsBundledResources() throws {
        let manifest = RichContentAssetStore.manifest()

        #expect(manifest.mermaid.version == "11.15.0")
        #expect(manifest.katex.version == "0.17.0")
        #expect(manifest.hasMermaidRuntime)
        #expect(manifest.hasKaTeXRuntime)
        #expect(manifest.hasKaTeXCSS)
        #expect(manifest.hasOpenMarkedRuntime)
        #expect(manifest.hasOpenMarkedCSS)
        #expect(manifest.katexFontCount > 0)
        #expect(try RichContentAssetStore.mermaidRuntimeJavaScript().contains("mermaid"))
        #expect(try RichContentAssetStore.katexRuntimeJavaScript().contains("katex"))
        #expect(try RichContentAssetStore.openMarkedRuntimeJavaScript().contains("openMarkedRichContent"))
        #expect(FileManager.default.fileExists(atPath: try RichContentAssetStore.requiredResourceURL("RichContent/Mermaid/Mermaid-LICENSE").path))
        #expect(FileManager.default.fileExists(atPath: try RichContentAssetStore.requiredResourceURL("RichContent/KaTeX/KaTeX-LICENSE").path))
        #expect(FileManager.default.fileExists(atPath: try RichContentAssetStore.requiredResourceURL("RichContent/KaTeX/fonts/KaTeX_Main-Regular.woff2").path))

        let katexCSS = try RichContentAssetStore.katexCSSForHTML()
        #expect(katexCSS.contains("file://"))
        #expect(katexCSS.contains("KaTeX_Main-Regular.woff2"))
    }

    @Test("Rich content HTML assets are conditional")
    func richContentHTMLAssetsAreConditional() throws {
        let plainHTML = HTMLDocumentAssembler.assemble(title: "Plain", bodyHTML: "<p>Plain</p>")
        #expect(!plainHTML.contains("om-rich-content-assets"))
        #expect(!plainHTML.contains("katex-version"))

        let state = RichMarkdownRenderState(
            documentFeatures: RichMarkdownDocumentFeatures(features: [.mermaid, .math])
        )
        let richHTML = HTMLDocumentAssembler.assemble(
            title: "Rich",
            bodyHTML: "<p>Rich</p>",
            richMarkdownState: state
        )

        #expect(richHTML.contains(#"id="om-rich-content-assets""#))
        #expect(richHTML.contains("data-openmarked-rich-content=\"math mermaid\""))
        #expect(richHTML.contains("katex-version"))
        #expect(try RichContentRuntimeAssembler.runtimeScripts(for: state).count == 3)
        #expect(RichContentRuntimeAssembler.invocationScript(for: state).contains("mermaid: true"))
        #expect(RichContentRuntimeAssembler.invocationScript(for: state).contains("katex: true"))
    }

    @Test("Rich content runtime status parsing is deterministic")
    func richContentRuntimeStatusParsing() {
        let status = RichContentWebViewRuntime.status(
            from: [
                "ready": false,
                "timedOut": true,
                "errors": ["Timed out"]
            ],
            requestedFeatures: [.mermaid]
        )

        #expect(status.hasFailure)
        #expect(status.requestedFeatures == [.mermaid])
        #expect(status.userMessage == "Rich content rendering timed out")
    }

    @Test("Rich content preview status transitions are tracked")
    func richContentPreviewStatusTransitions() {
        var state = DocumentWindowState()
        let richState = RichMarkdownRenderState(
            documentFeatures: RichMarkdownDocumentFeatures(features: [.mermaid, .math])
        )
        let result = RenderResult(
            bodyHTML: "<p>Rich</p>",
            fullHTML: "<!doctype html><p>Rich</p>",
            outline: [],
            diagnostics: [],
            statistics: .empty,
            rendererName: "test",
            rendererVersion: nil,
            richMarkdownState: richState
        )

        state.finishRendering(result)
        #expect(state.richContentPreview == .pending([.mermaid, .math]))
        state.beginRichContentRendering(features: [.mermaid, .math])
        #expect(state.richContentPreview == .rendering([.mermaid, .math]))
        #expect(state.statusMessage == "Rendering rich content")
        state.finishRichContentRendering(features: [.mermaid, .math])
        #expect(state.richContentPreview == .ready([.mermaid, .math]))
        state.failRichContentRendering("Rich content rendering failed")
        #expect(state.richContentPreview == .failed("Rich content rendering failed"))
    }

    @Test("Mermaid postprocessor builds placeholders before highlighting")
    func mermaidPostProcessorBuildsPlaceholdersBeforeHighlighting() {
        let html = """
        <pre><code class="language-mermaid">flowchart LR
        A --&gt; B</code></pre>
        <pre><code class="language-swift">let value = 1</code></pre>
        """

        let result = MermaidPostProcessor.process(html)
        let highlighted = CodeHighlighter.highlight(result.html)

        #expect(result.diagramCount == 1)
        #expect(highlighted.contains(#"<figure class="om-mermaid" data-openmarked-rich="mermaid" id="om-mermaid-1">"#))
        #expect(highlighted.contains(#"<pre class="om-mermaid-source"><code>flowchart LR"#))
        #expect(highlighted.contains("A --&gt; B"))
        #expect(highlighted.contains(#"class="om-code-block om-code-swift""#))
        #expect(!highlighted.contains(#"language-mermaid">flowchart"#))
    }

    @Test("Renderer transforms Mermaid fixture and reports preflight diagnostics")
    func rendererTransformsMermaidFixtureAndReportsPreflightDiagnostics() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/mermaid.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.richMarkdownState.requiresMermaidRuntime)
        #expect(result.bodyHTML.contains(#"id="om-mermaid-1""#))
        #expect(result.bodyHTML.contains(#"id="om-mermaid-6""#))
        #expect(result.bodyHTML.contains(#"class="om-code-block om-code-swift""#))
        #expect(!result.bodyHTML.contains("language-mermaid"))
        #expect(result.diagnostics.contains { $0.kind == .mermaidRenderFailure && $0.source == "om-mermaid-6" })
    }

    @Test("Mermaid standalone HTML export embeds trusted runtime")
    func mermaidStandaloneHTMLExportEmbedsTrustedRuntime() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/mermaid.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let html = HTMLExportDocumentBuilder.standaloneHTML(renderResult: result, document: document)

        #expect(html.contains("data-openmarked-rich-content-runtime"))
        #expect(html.contains("openMarkedRichContent"))
        #expect(html.contains(#"globalThis["mermaid"]"#))
        #expect(html.contains(#"data-openmarked-rich="mermaid""#))
    }

    @Test("Math delimiter rules avoid common false positives")
    func mathDelimiterRulesAvoidCommonFalsePositives() {
        let mathSamples = [
            "Inline math uses $E = mc^2$.",
            """
            $$
            \\sum_{n=1}^{10} n = 55
            $$
            """
        ]

        let nonMathSamples = [
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

        #expect(mathSamples.allSatisfy { MathDelimiterRules.containsMath(in: $0) })
        #expect(nonMathSamples.allSatisfy { !MathDelimiterRules.containsMath(in: $0) })
    }

    @Test("Math postprocessor builds placeholders and skips protected HTML")
    func mathPostProcessorBuildsPlaceholdersAndSkipsProtectedHTML() {
        let html = #"""
        <p>Inline $E = mc^2$ and price $12.00.</p>
        <p>Code <code>$not_math$</code> link <a href="/">$x$</a>.</p>
        <p>$$
        \sum_{n=1}^{10} n = 55
        $$</p>
        <p>Broken $\frac{1}{$.</p>
        """#

        let result = MathPostProcessor.process(html)
        let disabledResult = MathPostProcessor.process("<p>$x$</p>", isEnabled: false)

        #expect(result.expressionCount == 3)
        #expect(result.html.contains(#"class="om-math-inline""#))
        #expect(result.html.contains(#"class="om-math-display""#))
        #expect(result.html.contains(#"data-openmarked-rich="math""#))
        #expect(result.html.contains(#"data-openmarked-math-source="E = mc^2""#))
        #expect(result.html.contains("price $12.00"))
        #expect(result.html.contains("<code>$not_math$</code>"))
        #expect(result.html.contains(#"<a href="/">$x$</a>"#))
        #expect(result.diagnostics.contains { $0.kind == .mathRenderFailure && $0.source == "om-math-3" })
        #expect(disabledResult.expressionCount == 0)
        #expect(disabledResult.html == "<p>$x$</p>")
    }

    @Test("Renderer transforms math fixture and preserves non-math dollars")
    func rendererTransformsMathFixtureAndPreservesNonMathDollars() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/math.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(result.richMarkdownState.requiresMathRuntime)
        #expect(result.bodyHTML.contains(#"id="om-math-1""#))
        #expect(result.bodyHTML.contains(#"id="om-math-2""#))
        #expect(result.bodyHTML.contains(#"class="om-math-inline""#))
        #expect(result.bodyHTML.contains(#"class="om-math-display""#))
        #expect(result.bodyHTML.contains("$12.00"))
        #expect(result.bodyHTML.contains("$not_math$"))
        #expect(result.bodyHTML.contains("$x + 1"))
        #expect(!result.diagnostics.contains { $0.kind == .mathRenderFailure })
    }

    @Test("KaTeX standalone HTML export embeds trusted runtime")
    func katexStandaloneHTMLExportEmbedsTrustedRuntime() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/math.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let html = HTMLExportDocumentBuilder.standaloneHTML(renderResult: result, document: document)

        #expect(html.contains("data-openmarked-rich-content-runtime"))
        #expect(html.contains("openMarkedRichContent"))
        #expect(html.contains("katex-version"))
        #expect(html.contains("KaTeX parse error"))
        #expect(html.contains(#"data-openmarked-rich="math""#))
    }

    @Test("Render diagnostic kinds include rich Markdown foundation kinds")
    func renderDiagnosticKindsIncludeRichMarkdownFoundationKinds() {
        let expectedKinds: Set<RenderDiagnosticKind> = [
            .missingLocalImage,
            .missingLocalLink,
            .missingHeadingFragment,
            .malformedLink,
            .malformedFrontMatter,
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
        #expect(document.firstHeadingTitle == "OpenMarked Fixture README")
        #expect(document.statistics.wordCount > 0)
        #expect(document.metadata.fileSize > 0)
    }

    @Test("Document statistics options tune reading estimates")
    func documentStatisticsOptionsTuneReadingEstimates() throws {
        let bodyWords = Array(repeating: "body", count: 450).joined(separator: " ")
        let frontMatterWords = Array(repeating: "meta", count: 250).joined(separator: " ")
        let source = """
        ---
        title: Reading Options
        summary: \(frontMatterWords)
        ---
        # Reading Options

        \(bodyWords)
        """
        let parsed = FrontMatterParser.parse(source)
        let document = MarkdownDocument(
            sourceURL: URL(fileURLWithPath: "/tmp/reading-options.md"),
            sourceText: source,
            bodyText: parsed.bodyText,
            frontMatter: parsed.frontMatter,
            metadata: DocumentFileMetadata(fileSize: Int64(source.utf8.count), createdAt: nil, modifiedAt: nil),
            statistics: DocumentStatisticsCalculator.calculate(bodyText: parsed.bodyText),
            loadedAt: Date(timeIntervalSince1970: 0),
            securityScopedBookmark: nil
        )

        let bodyOnlyReport = DocumentInspectionBuilder.build(document: document)
        let inclusiveReport = DocumentInspectionBuilder.build(
            document: document,
            statisticsOptions: DocumentStatisticsOptions(wordsPerMinute: 100, includesFrontMatter: true)
        )

        #expect(!bodyOnlyReport.statistics.includesFrontMatter)
        #expect(inclusiveReport.statistics.includesFrontMatter)
        #expect(inclusiveReport.statistics.wordsPerMinute == 100)
        #expect(inclusiveReport.statistics.words > bodyOnlyReport.statistics.words)
        #expect(inclusiveReport.statistics.readingTimeMinutes > bodyOnlyReport.statistics.readingTimeMinutes)
    }

    @Test("Front matter is parsed and removed from body")
    func frontMatterIsParsedAndRemovedFromBody() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/front-matter.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        #expect(document.frontMatter?.format == .yaml)
        #expect(document.frontMatter?.title == "Fixture With Front Matter")
        #expect(document.displayTitle == "Fixture With Front Matter")
        #expect(document.firstHeadingTitle == "Body Heading")
        #expect(!document.bodyText.contains("description: Metadata"))
    }

    @Test("Document title uses stored Markdown heading scanner metadata")
    func documentTitleUsesStoredMarkdownHeadingScannerMetadata() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-setext-title-\(UUID().uuidString).md")
        try """
        ```swift
        # Ignored Fence Heading
        ```

        Scanner Title
        =============

        Body text.
        """.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)

        #expect(document.firstHeadingTitle == "Scanner Title")
        #expect(document.resolvedTitle == "Scanner Title")
        #expect(document.resolvedTitleSource == .firstHeading)
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
            "Fixtures/Markdown/github-readme-compat.md",
            "Fixtures/Markdown/metadata-rich.md",
            "Fixtures/Markdown/malformed-front-matter.md",
            "Fixtures/Markdown/json-front-matter.md"
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

    @Test("Rendered HTML index collects links, images, and counts")
    func renderedHTMLIndexCollectsLinksImagesAndCounts() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/local-images.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let html = ##"""
        <p><a href='guide.md'>Guide <strong>Now</strong></a></p>
        <p><img src="../Assets/sample-mark.svg" alt="Sample mark"></p>
        <p><img src="about:blank" data-openmarked-blocked-src="https://example.com/blocked.png" alt="Blocked"></p>
        <table><tr><td>Cell</td></tr></table>
        """##

        let index = RenderedHTMLIndex.build(from: html, document: document)

        #expect(index.links.map(\.source) == ["guide.md"])
        #expect(index.links.map(\.text) == ["Guide Now"])
        #expect(index.images.map(\.source) == ["../Assets/sample-mark.svg", "https://example.com/blocked.png"])
        #expect(index.images.map(\.altText) == ["Sample mark", "Blocked"])
        #expect(index.images[1].isBlocked)
        #expect(index.localImageURLs.contains { $0.lastPathComponent == "sample-mark.svg" })
        #expect(index.paragraphCount == 3)
        #expect(index.tableCount == 1)
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

    @Test("Cross-document heading validation scans Markdown without rendering target")
    func crossDocumentHeadingValidationScansMarkdownWithoutRenderingTarget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenMarkedHeadingScanner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let targetURL = directory.appendingPathComponent("target.md")
        try """
        ---
        title: Target
        ---

        Setext Target
        =============

        Duplicate
        ---------

        Duplicate
        ---------

        ```
        # Hidden Heading
        ```

        <h3 id="custom-html">HTML Heading</h3>
        """.write(to: targetURL, atomically: true, encoding: .utf8)

        let sourceURL = directory.appendingPathComponent("source.md")
        try """
        # Source

        [Setext](target.md#setext-target)
        [Duplicate](target.md#duplicate)
        [Duplicate 2](target.md#duplicate-1)
        [HTML](target.md#custom-html)
        [Hidden](target.md#hidden-heading)
        """.write(to: sourceURL, atomically: true, encoding: .utf8)

        let document = try MarkdownDocumentLoader.load(url: sourceURL, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))

        #expect(!result.diagnostics.contains { $0.source == "target.md#setext-target" })
        #expect(!result.diagnostics.contains { $0.source == "target.md#duplicate" })
        #expect(!result.diagnostics.contains { $0.source == "target.md#duplicate-1" })
        #expect(!result.diagnostics.contains { $0.source == "target.md#custom-html" })
        #expect(result.diagnostics.contains { $0.kind == .missingHeadingFragment && $0.source == "target.md#hidden-heading" })
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

        #expect(
            AppChromeThemeStore.allBuiltInThemes.map(\.id)
                == ["default", "catppuccin", "tokyo-night", "everforest", "nord", "rose-pine", "dracula", "gruvbox"]
        )
        #expect(
            AppChromeThemeStore.builtInThemeIDs
                == ["default", "catppuccin", "tokyo-night", "everforest", "nord", "rose-pine", "dracula", "gruvbox"]
        )
        #expect(AppChromeThemeStore.isBuiltInThemeID("tokyo-night"))
        #expect(!AppChromeThemeStore.isBuiltInThemeID("missing"))
        #expect(AppChromeThemeStore.allBuiltInThemes == AppChromeThemeStore.allBuiltInThemes)
        #expect(AppChromeThemeStore.theme(id: "missing").id == "default")
        #expect(ApplicationSettings(appChromeThemeID: "tokyo-night").normalized().appChromeThemeID == "tokyo-night")
        #expect(
            PreviewThemeStore.allBuiltInThemes.map(\.id)
                == ["default", "github", "minimal", "catppuccin", "tokyo-night", "everforest", "nord", "rose-pine", "dracula", "gruvbox"]
        )
        #expect(PreviewThemeStore.theme(id: "missing").id == "default")
        #expect(result.fullHTML.contains("--om-font-scale: 1.300"))
        #expect(result.fullHTML.contains("Segoe UI"))
    }

    @Test("User preview theme store imports, validates, and persists themes")
    func userPreviewThemeStoreImportsValidatesAndPersistsThemes() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("openmarked-theme-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let suiteName = "OpenMarkedUserThemeTests-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Expected a test UserDefaults suite")
            return
        }
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let importURL = rootURL.appendingPathComponent("Fixture.css")
        try "body { color: #123456; }\n".write(to: importURL, atomically: true, encoding: .utf8)
        let managedURL = rootURL.appendingPathComponent("Managed", isDirectory: true)
        let store = UserPreviewThemeStore(userDefaults: userDefaults, metadataKey: "Themes", themesDirectoryURL: managedURL)

        let imported = try store.importTheme(from: importURL, name: "Fixture Theme")
        #expect(imported.id.hasPrefix(UserPreviewTheme.idPrefix))
        #expect(store.load() == [imported])
        #expect(FileManager.default.fileExists(atPath: imported.screenCSSPath))
        #expect(store.previewTheme(for: imported).screenCSS.contains("#123456"))

        try "body { color: #654321; background: #abcdef; }\n".write(
            to: URL(fileURLWithPath: imported.screenCSSPath),
            atomically: true,
            encoding: .utf8
        )
        #expect(store.previewTheme(for: imported).screenCSS.contains("#654321"))

        let reloadedStore = UserPreviewThemeStore(userDefaults: userDefaults, metadataKey: "Themes", themesDirectoryURL: managedURL)
        #expect(reloadedStore.load() == [imported])

        try "body { background-image: url(javascript:alert(1)); }\n".write(
            to: URL(fileURLWithPath: imported.screenCSSPath),
            atomically: true,
            encoding: .utf8
        )
        #expect(store.previewTheme(for: imported).screenCSS == PreviewThemeStore.defaultTheme.screenCSS)

        let remoteImportURL = rootURL.appendingPathComponent("Remote.css")
        try "@import url(\"https://example.com/theme.css\");\n".write(to: remoteImportURL, atomically: true, encoding: .utf8)
        do {
            _ = try store.importTheme(from: remoteImportURL)
            Issue.record("Expected remote CSS import to be rejected")
        } catch {
            #expect(error as? UserPreviewThemeError == .importRulesUnsupported)
        }

        let renamed = try store.renameTheme(id: imported.id, name: "Renamed Fixture")
        #expect(renamed.name == "Renamed Fixture")

        let duplicate = try store.duplicateBuiltInTheme(id: "github", name: "GitHub Fork")
        #expect(FileManager.default.fileExists(atPath: duplicate.screenCSSPath))
        #expect(duplicate.codeCSSPath != nil)
        #expect(duplicate.printCSSPath != nil)

        try store.deleteTheme(id: renamed.id)
        #expect(!FileManager.default.fileExists(atPath: renamed.screenCSSPath))
        #expect(store.load().map(\.id) == [duplicate.id])
    }

    @Test("User theme IDs survive settings normalization")
    func userThemeIDsSurviveSettingsNormalization() {
        let userThemeID = "\(UserPreviewTheme.idPrefix)fixture"
        let settings = ApplicationSettings(defaultThemeID: userThemeID, defaultFontScale: 1.25)
        let normalized = settings.normalized()

        #expect(normalized.defaultThemeID == userThemeID)
        #expect(normalized.defaultLayout.selectedThemeID == userThemeID)
        #expect(ApplicationSettings(defaultThemeID: "missing").normalized().defaultThemeID == "default")
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

    @Test("Outline display builder applies display options")
    func outlineDisplayBuilderAppliesDisplayOptions() {
        let outline = [
            OutlineItem(id: "intro", level: 1, title: "Introduction"),
            OutlineItem(id: "goals", level: 2, title: "Goals"),
            OutlineItem(id: "details", level: 3, title: "Implementation Details"),
            OutlineItem(id: "api", level: 2, title: "API")
        ]

        let hierarchical = OutlineDisplayBuilder.items(outline: outline)
        #expect(hierarchical.map(\.id) == ["intro", "goals", "details", "api"])
        #expect(hierarchical.map(\.displayTitle) == ["Introduction", "Goals", "Implementation Details", "API"])
        #expect(hierarchical.map(\.indentationLevel) == [0, 1, 2, 1])

        let collapsed = OutlineDisplayBuilder.items(
            outline: outline,
            options: OutlineDisplayOptions(maximumVisibleLevel: 2)
        )
        #expect(collapsed.map(\.id) == ["intro", "goals", "api"])

        let flatNumbered = OutlineDisplayBuilder.items(
            outline: outline,
            options: OutlineDisplayOptions(mode: .flat, maximumVisibleLevel: 6, showsAutoNumbers: true)
        )
        #expect(flatNumbered.map(\.displayTitle) == ["1 Introduction", "1.1 Goals", "1.1.1 Implementation Details", "1.2 API"])
        #expect(flatNumbered.map(\.indentationLevel) == [0, 0, 0, 0])

        let flatUnnumbered = OutlineDisplayBuilder.items(
            outline: outline,
            options: OutlineDisplayOptions(mode: .flat, maximumVisibleLevel: 6, showsAutoNumbers: false)
        )
        #expect(flatUnnumbered.map(\.displayTitle) == ["Introduction", "Goals", "Implementation Details", "API"])

        let filtered = OutlineDisplayBuilder.items(
            outline: outline,
            query: "details",
            options: OutlineDisplayOptions(maximumVisibleLevel: 2)
        )
        #expect(filtered.map(\.id) == ["details"])
        #expect(filtered.map(\.indentationLevel) == [0])
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

    @Test("Print configuration applies to standalone HTML")
    func printConfigurationAppliesToStandaloneHTML() throws {
        let url = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: url, createBookmark: false)
        let result = try CMarkGFMRenderer().render(RenderRequest(document: document))
        let configuration = PrintConfiguration(
            pageSize: .a4,
            margins: PrintMargins(top: 0.5, right: 0.6, bottom: 0.7, left: 0.8),
            contentMaxWidth: 700,
            startsHeadingOneOnNewPage: true,
            startsHeadingTwoOnNewPage: true,
            includesDocumentTitle: true,
            themeMode: .defaultPrint
        )

        let html = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: result,
            document: document,
            options: HTMLExportOptions(printConfiguration: configuration)
        )

        #expect(html.contains("om-print-document-title"))
        #expect(html.contains("OpenMarked Fixture README"))
        #expect(html.contains("om-print-include-title om-print-break-h1 om-print-break-h2 om-print-limit-width om-print-default-theme"))
        #expect(html.contains("size: A4;"))
        #expect(html.contains("margin: 0.50in 0.60in 0.70in 0.80in;"))
        #expect(html.contains("max-width: min(700px, 100%);"))
        #expect(html.contains("break-before: page;"))

        let unstyledHTML = HTMLExportDocumentBuilder.standaloneHTML(
            renderResult: result,
            document: document,
            options: HTMLExportOptions(embedsThemeCSS: false, printConfiguration: configuration)
        )
        #expect(!unstyledHTML.contains("om-print-document-title"))
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
