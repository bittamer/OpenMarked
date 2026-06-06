import AppKit
import CryptoKit
import Foundation
import WebKit
import OpenMarkedCore

enum SnapshotSurface: String, Codable, Sendable {
    case preview
    case inspector
    case settings
}

struct SnapshotCase: Sendable {
    let id: String
    let fixturePath: String
    let themeID: String
    let appearance: String
    let width: Int
    let height: Int
    let surface: SnapshotSurface
    let inspectorSection: DocumentInspectorSection?
    let requiredDiagnosticKinds: [RenderDiagnosticKind]

    init(
        id: String,
        fixturePath: String,
        themeID: String,
        appearance: String,
        width: Int,
        height: Int,
        surface: SnapshotSurface = .preview,
        inspectorSection: DocumentInspectorSection? = nil,
        requiredDiagnosticKinds: [RenderDiagnosticKind] = []
    ) {
        self.id = id
        self.fixturePath = fixturePath
        self.themeID = themeID
        self.appearance = appearance
        self.width = width
        self.height = height
        self.surface = surface
        self.inspectorSection = inspectorSection
        self.requiredDiagnosticKinds = requiredDiagnosticKinds
    }
}

struct SnapshotManifest: Codable, Sendable {
    let schemaVersion: Int
    let appVersion: String
    let appBuild: String
    let snapshots: [SnapshotManifestEntry]
}

struct SnapshotManifestEntry: Codable, Sendable {
    let id: String
    let fixturePath: String
    let themeID: String
    let appearance: String
    let surface: SnapshotSurface
    let inspectorSection: DocumentInspectorSection?
    let width: Int
    let height: Int
    let file: String
    let bytes: Int
    let sha256: String
    let diagnosticCount: Int
    let diagnosticKinds: [String]
}

enum SnapshotError: Error, LocalizedError {
    case missingArgument(String)
    case imageEncodingFailed(String)
    case blankSnapshot(String)
    case webNavigationFailed(String)
    case pdfExportFailed(String)
    case expectedDiagnosticsMissing(String, [String])
    case inspectorSectionMissing(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing value for \(name)."
        case .imageEncodingFailed(let id):
            return "Could not encode snapshot \(id) as PNG."
        case .blankSnapshot(let id):
            return "Snapshot \(id) appears blank."
        case .webNavigationFailed(let reason):
            return "WebKit could not render snapshot HTML. \(reason)"
        case .pdfExportFailed(let id):
            return "Could not export PDF snapshot \(id)."
        case .expectedDiagnosticsMissing(let id, let kinds):
            return "Snapshot \(id) did not produce expected diagnostics: \(kinds.joined(separator: ", "))."
        case .inspectorSectionMissing(let id):
            return "Snapshot \(id) is an inspector surface without a selected inspector section."
        }
    }
}

struct SnapshotWebContent: Sendable {
    let html: String
    let baseURL: URL
    let diagnosticCount: Int
    let diagnosticKinds: [String]
    let richMarkdownState: RichMarkdownRenderState?
}

@main
struct OpenMarkedSnapshotter {
    static func main() async {
        do {
            let runner = SnapshotRunner(arguments: Array(CommandLine.arguments.dropFirst()))
            try await runner.run()
        } catch {
            FileHandle.standardError.write(Data("Snapshotter failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}

@MainActor
final class SnapshotRunner: NSObject, WKNavigationDelegate {
    private let arguments: [String]
    private var navigationContinuation: CheckedContinuation<Void, Error>?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func run() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)

        let outputDirectory = try outputDirectoryURL()
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let pdfOutputDirectory = try pdfOutputDirectoryURL()
        if let pdfOutputDirectory {
            try FileManager.default.createDirectory(at: pdfOutputDirectory, withIntermediateDirectories: true)
        }

        let renderer = CMarkGFMRenderer()
        var entries: [SnapshotManifestEntry] = []

        for snapshotCase in snapshotCases {
            let entry = try await capture(
                snapshotCase,
                renderer: renderer,
                outputDirectory: outputDirectory,
                pdfOutputDirectory: pdfOutputDirectory
            )
            entries.append(entry)
            print("Captured \(entry.file) (\(entry.bytes) bytes)")
        }

        let manifest = SnapshotManifest(
            schemaVersion: 3,
            appVersion: AppInfo.version,
            appBuild: AppInfo.build,
            snapshots: entries
        )
        let manifestData = try JSONEncoder.openMarkedPretty.encode(manifest)
        try manifestData.write(to: outputDirectory.appendingPathComponent("manifest.json"))

        print("Snapshot manifest written to \(outputDirectory.appendingPathComponent("manifest.json").path)")
    }

    private func outputDirectoryURL() throws -> URL {
        guard let outputIndex = arguments.firstIndex(of: "--output") else {
            return URL(fileURLWithPath: ".build/openmarked-visual-snapshots", isDirectory: true)
        }

        let valueIndex = arguments.index(after: outputIndex)
        guard arguments.indices.contains(valueIndex) else {
            throw SnapshotError.missingArgument("--output")
        }

        return URL(fileURLWithPath: arguments[valueIndex], isDirectory: true)
    }

    private func pdfOutputDirectoryURL() throws -> URL? {
        guard let outputIndex = arguments.firstIndex(of: "--pdf-output") else {
            return nil
        }

        let valueIndex = arguments.index(after: outputIndex)
        guard arguments.indices.contains(valueIndex) else {
            throw SnapshotError.missingArgument("--pdf-output")
        }

        return URL(fileURLWithPath: arguments[valueIndex], isDirectory: true)
    }

    private var snapshotCases: [SnapshotCase] {
        let paletteThemeIDs = [
            "catppuccin",
            "tokyo-night",
            "everforest",
            "nord",
            "rose-pine",
            "dracula",
            "gruvbox"
        ]
        let paletteThemeCases = paletteThemeIDs.flatMap { themeID in
            [
                SnapshotCase(id: "\(themeID)-gfm-light", fixturePath: "Fixtures/Markdown/gfm.md", themeID: themeID, appearance: "light", width: 960, height: 720),
                SnapshotCase(id: "\(themeID)-rich-dark", fixturePath: "Fixtures/Markdown/rich-markdown.md", themeID: themeID, appearance: "dark", width: 960, height: 720)
            ]
        }

        return [
            SnapshotCase(id: "default-readme-light", fixturePath: "Fixtures/Markdown/README.md", themeID: "default", appearance: "light", width: 960, height: 720),
            SnapshotCase(id: "github-gfm-light", fixturePath: "Fixtures/Markdown/gfm.md", themeID: "github", appearance: "light", width: 960, height: 720),
            SnapshotCase(id: "minimal-prose-light", fixturePath: "Fixtures/Markdown/prose.md", themeID: "minimal", appearance: "light", width: 960, height: 720),
            SnapshotCase(id: "github-rich-markdown-light", fixturePath: "Fixtures/Markdown/rich-markdown.md", themeID: "github", appearance: "light", width: 960, height: 720),
            SnapshotCase(id: "github-rich-markdown-dark", fixturePath: "Fixtures/Markdown/rich-markdown.md", themeID: "github", appearance: "dark", width: 960, height: 720),
            SnapshotCase(id: "github-broken-links-light", fixturePath: "Fixtures/Markdown/broken-links.md", themeID: "github", appearance: "light", width: 960, height: 720, requiredDiagnosticKinds: [.missingHeadingFragment, .missingLocalLink, .unsupportedLinkScheme, .malformedLink]),
            SnapshotCase(id: "default-local-images-light", fixturePath: "Fixtures/Markdown/local-images.md", themeID: "default", appearance: "light", width: 960, height: 720),
            SnapshotCase(id: "github-long-document-dark", fixturePath: "Fixtures/Markdown/long-document.md", themeID: "github", appearance: "dark", width: 960, height: 720),
            SnapshotCase(id: "user-fixture-theme-gfm-light", fixturePath: "Fixtures/Markdown/gfm.md", themeID: "user.fixture", appearance: "light", width: 960, height: 720),
            SnapshotCase(id: "inspector-summary-light", fixturePath: "Fixtures/Markdown/metadata-rich.md", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .inspector, inspectorSection: .summary),
            SnapshotCase(id: "inspector-metadata-light", fixturePath: "Fixtures/Markdown/metadata-rich.md", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .inspector, inspectorSection: .metadata),
            SnapshotCase(id: "inspector-statistics-light", fixturePath: "Fixtures/Markdown/statistics-rich.md", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .inspector, inspectorSection: .statistics),
            SnapshotCase(id: "inspector-links-light", fixturePath: "Fixtures/Markdown/inspection-links-assets.md", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .inspector, inspectorSection: .links),
            SnapshotCase(id: "inspector-assets-light", fixturePath: "Fixtures/Markdown/inspection-links-assets.md", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .inspector, inspectorSection: .assets),
            SnapshotCase(id: "inspector-diagnostics-dark", fixturePath: "Fixtures/Markdown/broken-links.md", themeID: "github", appearance: "dark", width: 1120, height: 760, surface: .inspector, inspectorSection: .diagnostics, requiredDiagnosticKinds: [.missingHeadingFragment, .missingLocalLink, .unsupportedLinkScheme, .malformedLink]),
            SnapshotCase(id: "inspector-export-readiness-light", fixturePath: "Fixtures/Markdown/print-readiness.md", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .inspector, inspectorSection: .export),
            SnapshotCase(id: "settings-theme-manager-light", fixturePath: "Fixtures/Themes/user-fixture.css", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .settings),
            SnapshotCase(id: "settings-print-controls-light", fixturePath: "Fixtures/Markdown/print-readiness.md", themeID: "default", appearance: "light", width: 1120, height: 760, surface: .settings)
        ] + paletteThemeCases
    }

    private func capture(
        _ snapshotCase: SnapshotCase,
        renderer: CMarkGFMRenderer,
        outputDirectory: URL,
        pdfOutputDirectory: URL?
    ) async throws -> SnapshotManifestEntry {
        let content = try makeWebContent(for: snapshotCase, renderer: renderer)
        let diagnosticKinds = content.diagnosticKinds
        let diagnosticKindSet = Set(diagnosticKinds)
        let missingDiagnosticKinds = snapshotCase.requiredDiagnosticKinds
            .map(\.rawValue)
            .filter { !diagnosticKindSet.contains($0) }
        if !missingDiagnosticKinds.isEmpty {
            throw SnapshotError.expectedDiagnosticsMissing(snapshotCase.id, missingDiagnosticKinds)
        }
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: snapshotCase.width, height: snapshotCase.height))
        webView.navigationDelegate = self
        webView.appearance = snapshotCase.appearance == "dark" ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)

        let window = NSWindow(
            contentRect: webView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.orderFrontRegardless()
        defer {
            window.orderOut(nil)
            webView.navigationDelegate = nil
        }

        try await loadHTML(
            PreviewHTMLSecurityPolicy.sanitize(content.html),
            baseURL: content.baseURL,
            in: webView
        )
        if let richMarkdownState = content.richMarkdownState {
            let richContentStatus = try await RichContentWebViewRuntime.installAndWait(
                for: richMarkdownState,
                in: webView
            )
            guard !richContentStatus.hasFailure else {
                throw SnapshotError.webNavigationFailed(richContentStatus.userMessage)
            }
        }
        try await Task.sleep(nanoseconds: 250_000_000)

        let configuration = WKSnapshotConfiguration()
        configuration.rect = webView.bounds
        let image = try await takeSnapshot(webView: webView, configuration: configuration)
        guard snapshotHasContent(image) else {
            throw SnapshotError.blankSnapshot(snapshotCase.id)
        }

        if let pdfOutputDirectory {
            let pdfURL = pdfOutputDirectory.appendingPathComponent("\(snapshotCase.id).pdf")
            try await writePDF(from: webView, to: pdfURL, id: snapshotCase.id)
            let pdfBytes = (try FileManager.default.attributesOfItem(atPath: pdfURL.path)[.size] as? NSNumber)?.intValue ?? 0
            guard pdfBytes > 10_000 else {
                throw SnapshotError.pdfExportFailed(snapshotCase.id)
            }
            print("Exported \(pdfURL.lastPathComponent) (\(pdfBytes) bytes)")
        }

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw SnapshotError.imageEncodingFailed(snapshotCase.id)
        }

        let fileName = "\(snapshotCase.id).png"
        let fileURL = outputDirectory.appendingPathComponent(fileName)
        try pngData.write(to: fileURL)

        return SnapshotManifestEntry(
            id: snapshotCase.id,
            fixturePath: snapshotCase.fixturePath,
            themeID: snapshotCase.themeID,
            appearance: snapshotCase.appearance,
            surface: snapshotCase.surface,
            inspectorSection: snapshotCase.inspectorSection,
            width: snapshotCase.width,
            height: snapshotCase.height,
            file: fileName,
            bytes: pngData.count,
            sha256: SHA256.hash(data: pngData).hexString,
            diagnosticCount: content.diagnosticCount,
            diagnosticKinds: Array(Set(diagnosticKinds)).sorted()
        )
    }

    private func makeWebContent(for snapshotCase: SnapshotCase, renderer: CMarkGFMRenderer) throws -> SnapshotWebContent {
        switch snapshotCase.surface {
        case .preview:
            let documentURL = URL(fileURLWithPath: snapshotCase.fixturePath).standardizedFileURL
            let document = try MarkdownDocumentLoader.load(url: documentURL, createBookmark: false)
            let theme = try previewTheme(for: snapshotCase)
            let result = try renderer.render(RenderRequest(document: document, theme: theme))
            return SnapshotWebContent(
                html: result.fullHTML,
                baseURL: document.sourceURL.deletingLastPathComponent(),
                diagnosticCount: result.diagnostics.count,
                diagnosticKinds: result.diagnostics.map(\.kind.rawValue).sorted(),
                richMarkdownState: result.richMarkdownState
            )
        case .inspector:
            let documentURL = URL(fileURLWithPath: snapshotCase.fixturePath).standardizedFileURL
            let document = try MarkdownDocumentLoader.load(url: documentURL, createBookmark: false)
            let theme = try previewTheme(for: snapshotCase)
            let result = try renderer.render(RenderRequest(document: document, theme: theme))
            guard let section = snapshotCase.inspectorSection else {
                throw SnapshotError.inspectorSectionMissing(snapshotCase.id)
            }
            let report = DocumentInspectionBuilder.build(document: document, renderResult: result)
            return SnapshotWebContent(
                html: inspectorHTML(document: document, report: report, section: section, theme: theme, appearance: snapshotCase.appearance),
                baseURL: document.sourceURL.deletingLastPathComponent(),
                diagnosticCount: result.diagnostics.count,
                diagnosticKinds: result.diagnostics.map(\.kind.rawValue).sorted(),
                richMarkdownState: nil
            )
        case .settings:
            return SnapshotWebContent(
                html: settingsHTML(for: snapshotCase),
                baseURL: URL(fileURLWithPath: ".").standardizedFileURL,
                diagnosticCount: 0,
                diagnosticKinds: [],
                richMarkdownState: nil
            )
        }
    }

    private func previewTheme(for snapshotCase: SnapshotCase) throws -> PreviewTheme {
        guard snapshotCase.themeID == "user.fixture" else {
            return PreviewThemeStore.theme(id: snapshotCase.themeID)
        }

        let cssURL = URL(fileURLWithPath: "Fixtures/Themes/user-fixture.css").standardizedFileURL
        let css = try String(contentsOf: cssURL, encoding: .utf8)
        try UserPreviewThemeStore.validateCSS(css)
        let fallbackTheme = PreviewThemeStore.defaultTheme
        return PreviewTheme(
            id: snapshotCase.themeID,
            name: "Fixture User Theme",
            screenCSS: css,
            printCSS: fallbackTheme.printCSS,
            codeHighlightingCSS: fallbackTheme.codeHighlightingCSS,
            supportsDarkMode: true,
            defaultMaxWidth: fallbackTheme.defaultMaxWidth
        )
    }

    private func inspectorHTML(
        document: MarkdownDocument,
        report: DocumentInspectionReport,
        section: DocumentInspectorSection,
        theme: PreviewTheme,
        appearance: String
    ) -> String {
        let title = "Inspector - \(section.title)"
        let navigation = DocumentInspectorSection.allCases.map { item in
            let count = inspectorCount(for: item, report: report)
            let selectedClass = item == section ? " is-selected" : ""
            return """
            <li class="nav-item\(selectedClass)">
              <span>\(HTMLUtilities.escapeText(item.title))</span>
              <strong>\(HTMLUtilities.escapeText(count))</strong>
            </li>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(HTMLUtilities.escapeText(title))</title>
          <style>\(snapshotChromeCSS(appearance: appearance))</style>
        </head>
        <body class="surface-\(HTMLUtilities.escapeAttribute(appearance))">
          <main class="snapshot-shell">
            <aside class="snapshot-sidebar">
              <p class="eyebrow">Document Inspector</p>
              <h1>\(HTMLUtilities.escapeText(report.metadata.displayTitle))</h1>
              <p class="muted">\(HTMLUtilities.escapeText(document.displayName))</p>
              <ul class="nav-list">
                \(navigation)
              </ul>
              <div class="sidebar-card">
                <span>Theme</span>
                <strong>\(HTMLUtilities.escapeText(theme.name))</strong>
              </div>
            </aside>
            <section class="snapshot-panel">
              <header class="panel-header">
                <p class="eyebrow">\(HTMLUtilities.escapeText(section.title))</p>
                <h2>\(HTMLUtilities.escapeText(sectionHeading(for: section)))</h2>
                <p>\(HTMLUtilities.escapeText(sectionSubtitle(for: section, report: report)))</p>
              </header>
              \(inspectorSectionHTML(section: section, report: report))
            </section>
          </main>
        </body>
        </html>
        """
    }

    private func settingsHTML(for snapshotCase: SnapshotCase) -> String {
        switch snapshotCase.id {
        case "settings-theme-manager-light":
            let builtInThemes = PreviewThemeStore.allBuiltInThemes
            let themeRows = builtInThemes.map { theme in
                """
                <article class="theme-tile">
                  <div class="theme-swatch swatch-\(HTMLUtilities.escapeAttribute(theme.id))"></div>
                  <h3>\(HTMLUtilities.escapeText(theme.name))</h3>
                  <p>\(theme.supportsDarkMode ? "Light and dark preview" : "Light preview")</p>
                  <span>\(theme.defaultMaxWidth)px max width</span>
                </article>
                """
            }.joined(separator: "\n")
            return settingsShellHTML(
                title: "Theme Manager",
                selectedItem: "Themes",
                body: """
                <header class="panel-header">
                  <p class="eyebrow">Settings</p>
                  <h2>Theme Manager</h2>
                  <p>Built-in palettes, imported CSS themes, and safe local theme management.</p>
                </header>
                <section class="toolbar-row">
                  <button>Import CSS</button>
                  <button>Duplicate Built-In</button>
                  <button>Reveal Folder</button>
                </section>
                <section class="theme-grid">
                  \(themeRows)
                  <article class="theme-tile user-theme">
                    <div class="theme-swatch swatch-user"></div>
                    <h3>Fixture User Theme</h3>
                    <p>Local CSS, validated before use.</p>
                    <span>~/Library/Application Support/OpenMarked/Themes</span>
                  </article>
                </section>
                <section class="notice-row">
                  <strong>Safety</strong>
                  <span>@import, javascript: URLs, and embedded script/style tags are blocked.</span>
                </section>
                """
            )
        default:
            let configuration = PrintConfiguration(
                pageSize: .a4,
                margins: PrintMargins(top: 0.65, right: 0.8, bottom: 0.7, left: 0.8),
                contentMaxWidth: 760,
                startsHeadingOneOnNewPage: true,
                startsHeadingTwoOnNewPage: false,
                includesDocumentTitle: true,
                themeMode: .defaultPrint
            ).normalized()
            return settingsShellHTML(
                title: "Print Controls",
                selectedItem: "Print",
                body: """
                <header class="panel-header">
                  <p class="eyebrow">Settings</p>
                  <h2>Print Controls</h2>
                  <p>Page setup and export readiness controls for PDF and native printing.</p>
                </header>
                <section class="settings-grid">
                  \(settingControlHTML(label: "Page Size", value: configuration.pageSize.displayName))
                  \(settingControlHTML(label: "Margins", value: configuration.margins.cssValue))
                  \(settingControlHTML(label: "Content Width", value: "\(configuration.contentMaxWidth ?? PrintConfiguration.defaultContentMaxWidth)px"))
                  \(settingControlHTML(label: "Print Theme", value: configuration.themeMode.displayName))
                  \(settingToggleHTML(label: "Include Document Title", isOn: configuration.includesDocumentTitle))
                  \(settingToggleHTML(label: "Start H1 On New Page", isOn: configuration.startsHeadingOneOnNewPage))
                  \(settingToggleHTML(label: "Start H2 On New Page", isOn: configuration.startsHeadingTwoOnNewPage))
                </section>
                <section class="readiness-card">
                  <h3>Export Readiness</h3>
                  <p>Warnings surface missing local images, wide tables, remote assets, and rich-content failures before PDF export.</p>
                  <div class="meter"><span style="width: 72%"></span></div>
                </section>
                """
            )
        }
    }

    private func settingsShellHTML(title: String, selectedItem: String, body: String) -> String {
        let items = ["General", "Themes", "Markdown", "Print", "Accessibility"]
            .map { item in
                let selectedClass = item == selectedItem ? " is-selected" : ""
                return #"<li class="nav-item\#(selectedClass)"><span>\#(HTMLUtilities.escapeText(item))</span></li>"#
            }
            .joined(separator: "\n")
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(HTMLUtilities.escapeText(title))</title>
          <style>\(snapshotChromeCSS(appearance: "light"))</style>
        </head>
        <body class="surface-light">
          <main class="snapshot-shell">
            <aside class="snapshot-sidebar">
              <p class="eyebrow">OpenMarked</p>
              <h1>Settings</h1>
              <p class="muted">Version \(HTMLUtilities.escapeText(AppInfo.version)) build \(HTMLUtilities.escapeText(AppInfo.build))</p>
              <ul class="nav-list">\(items)</ul>
            </aside>
            <section class="snapshot-panel">
              \(body)
            </section>
          </main>
        </body>
        </html>
        """
    }

    private func inspectorSectionHTML(section: DocumentInspectorSection, report: DocumentInspectionReport) -> String {
        switch section {
        case .summary:
            return """
            <section class="metric-grid">
              \(metricCardHTML(label: "Words", value: "\(report.statistics.words)", detail: "\(report.statistics.readingTimeMinutes) min read"))
              \(metricCardHTML(label: "Headings", value: "\(report.statistics.headingCount)", detail: "\(report.statistics.sectionStatistics.count) sections"))
              \(metricCardHTML(label: "Links", value: "\(report.links.count)", detail: "\(report.statistics.missingReferenceCount) missing references"))
              \(metricCardHTML(label: "Readiness", value: report.exportReadiness.isReady ? "Ready" : "\(report.exportReadiness.issues.count) issues", detail: "PDF and print"))
            </section>
            <section class="content-card">
              <h3>Metadata</h3>
              \(fieldListHTML(report.metadata.fields.prefix(6)))
            </section>
            <section class="content-card">
              <h3>Export Readiness</h3>
              \(readinessListHTML(report.exportReadiness.issues))
            </section>
            """
        case .metadata:
            return """
            <section class="content-card">
              <h3>Front Matter</h3>
              \(fieldListHTML(report.metadata.fields))
            </section>
            <section class="content-card">
              <h3>File Facts</h3>
              \(fieldListHTML(report.metadata.fileFacts))
            </section>
            """
        case .links:
            return """
            <section class="table-card">
              <h3>Rendered Links</h3>
              \(linkTableHTML(report.links))
            </section>
            """
        case .assets:
            return """
            <section class="table-card">
              <h3>Images And Assets</h3>
              \(assetTableHTML(report.assets))
            </section>
            """
        case .diagnostics:
            return """
            <section class="content-card">
              <h3>Diagnostics</h3>
              \(diagnosticsListHTML(report.diagnostics))
            </section>
            """
        case .statistics:
            return """
            <section class="metric-grid">
              \(metricCardHTML(label: "Characters", value: "\(report.statistics.characters)", detail: "\(report.statistics.lines) lines"))
              \(metricCardHTML(label: "Pages", value: "\(report.statistics.estimatedPageCount)", detail: "estimate"))
              \(metricCardHTML(label: "Tables", value: "\(report.statistics.tableCount)", detail: "\(report.statistics.wideTableCandidateCount) wide candidates"))
              \(metricCardHTML(label: "Rich Blocks", value: "\(report.statistics.mermaidDiagramCount + report.statistics.mathExpressionCount)", detail: "Mermaid and math"))
            </section>
            <section class="content-card">
              <h3>Sections</h3>
              \(sectionStatsHTML(report.statistics.sectionStatistics))
            </section>
            """
        case .export:
            return """
            <section class="content-card">
              <h3>Export Readiness</h3>
              \(readinessListHTML(report.exportReadiness.issues))
            </section>
            <section class="metric-grid">
              \(metricCardHTML(label: "Images", value: "\(report.statistics.imageCount)", detail: "local and remote"))
              \(metricCardHTML(label: "Links", value: "\(report.statistics.linkCount)", detail: "\(report.statistics.missingReferenceCount) missing"))
              \(metricCardHTML(label: "Wide Tables", value: "\(report.statistics.wideTableCandidateCount)", detail: "print review"))
              \(metricCardHTML(label: "Diagnostics", value: "\(report.statistics.diagnosticCount)", detail: "render pipeline"))
            </section>
            """
        }
    }

    private func fieldListHTML(_ fields: some Sequence<MetadataField>) -> String {
        let rows = fields.map { field in
            let chips = field.tokens.isEmpty
                ? ""
                : "<div class=\"chip-row\">\(field.tokens.map { "<span>\(HTMLUtilities.escapeText($0))</span>" }.joined(separator: ""))</div>"
            return """
            <div class="field-row">
              <div>
                <strong>\(HTMLUtilities.escapeText(field.label))</strong>
                <span>\(HTMLUtilities.escapeText(field.source.rawValue)) - \(HTMLUtilities.escapeText(field.valueKind.rawValue))</span>
              </div>
              <p>\(HTMLUtilities.escapeText(field.value))</p>
              \(chips)
            </div>
            """
        }.joined(separator: "\n")
        return rows.isEmpty ? #"<p class="empty-state">No metadata fields.</p>"# : rows
    }

    private func linkTableHTML(_ links: [DocumentLinkReference]) -> String {
        tableHTML(
            headings: ["Text", "Target", "Kind", "Status"],
            rows: links.map { link in
                [
                    link.text,
                    link.target,
                    link.kind.rawValue,
                    link.status.rawValue
                ]
            }
        )
    }

    private func assetTableHTML(_ assets: [DocumentAssetReference]) -> String {
        tableHTML(
            headings: ["Alt", "Source", "Kind", "Status", "Info"],
            rows: assets.map { asset in
                [
                    asset.altText.isEmpty ? "No alt text" : asset.altText,
                    asset.source,
                    asset.kind.rawValue,
                    asset.status.rawValue,
                    assetInfoText(asset.fileInfo)
                ]
            }
        )
    }

    private func diagnosticsListHTML(_ diagnostics: [RenderDiagnostic]) -> String {
        guard !diagnostics.isEmpty else {
            return #"<p class="empty-state">No diagnostics for this document.</p>"#
        }

        return diagnostics.map { diagnostic in
            """
            <article class="issue issue-\(HTMLUtilities.escapeAttribute(diagnostic.severity.rawValue))">
              <strong>\(HTMLUtilities.escapeText(diagnostic.kind.rawValue))</strong>
              <p>\(HTMLUtilities.escapeText(diagnostic.message))</p>
              <span>\(HTMLUtilities.escapeText(diagnostic.source ?? "Document"))</span>
            </article>
            """
        }.joined(separator: "\n")
    }

    private func readinessListHTML(_ issues: [ExportReadinessIssue]) -> String {
        guard !issues.isEmpty else {
            return #"<p class="empty-state">Ready for export. No warnings found.</p>"#
        }

        return issues.map { issue in
            """
            <article class="issue issue-\(HTMLUtilities.escapeAttribute(issue.severity.rawValue))">
              <strong>\(HTMLUtilities.escapeText(issue.title))</strong>
              <p>\(HTMLUtilities.escapeText(issue.message))</p>
              <span>\(HTMLUtilities.escapeText(issue.source ?? "Document"))</span>
            </article>
            """
        }.joined(separator: "\n")
    }

    private func sectionStatsHTML(_ sections: [DocumentSectionStatistic]) -> String {
        guard !sections.isEmpty else {
            return #"<p class="empty-state">No sections detected.</p>"#
        }

        return sections.prefix(10).map { section in
            """
            <div class="section-row" style="--bar-width: \(min(100, max(10, section.wordCount * 2)))%">
              <div>
                <strong>H\(section.level) \(HTMLUtilities.escapeText(section.title))</strong>
                <span>\(section.wordCount) words, \(section.paragraphCount) paragraphs</span>
              </div>
              <i></i>
            </div>
            """
        }.joined(separator: "\n")
    }

    private func tableHTML(headings: [String], rows: [[String]]) -> String {
        guard !rows.isEmpty else {
            return #"<p class="empty-state">No rows for this section.</p>"#
        }

        let headingHTML = headings.map { "<th>\(HTMLUtilities.escapeText($0))</th>" }.joined()
        let rowHTML = rows.map { row in
            "<tr>\(row.map { "<td>\(HTMLUtilities.escapeText($0))</td>" }.joined())</tr>"
        }.joined(separator: "\n")
        return """
        <table>
          <thead><tr>\(headingHTML)</tr></thead>
          <tbody>\(rowHTML)</tbody>
        </table>
        """
    }

    private func metricCardHTML(label: String, value: String, detail: String) -> String {
        """
        <article class="metric-card">
          <span>\(HTMLUtilities.escapeText(label))</span>
          <strong>\(HTMLUtilities.escapeText(value))</strong>
          <p>\(HTMLUtilities.escapeText(detail))</p>
        </article>
        """
    }

    private func settingControlHTML(label: String, value: String) -> String {
        """
        <article class="setting-control">
          <span>\(HTMLUtilities.escapeText(label))</span>
          <strong>\(HTMLUtilities.escapeText(value))</strong>
        </article>
        """
    }

    private func settingToggleHTML(label: String, isOn: Bool) -> String {
        """
        <article class="setting-control toggle-control">
          <span>\(HTMLUtilities.escapeText(label))</span>
          <strong>\(isOn ? "On" : "Off")</strong>
          <i class="toggle \(isOn ? "is-on" : "")"></i>
        </article>
        """
    }

    private func inspectorCount(for section: DocumentInspectorSection, report: DocumentInspectionReport) -> String {
        switch section {
        case .summary:
            return "\(report.statistics.words)"
        case .metadata:
            return "\(report.metadata.fields.count + report.metadata.fileFacts.count)"
        case .links:
            return "\(report.links.count)"
        case .assets:
            return "\(report.assets.count)"
        case .diagnostics:
            return "\(report.diagnostics.count)"
        case .statistics:
            return "\(report.statistics.sectionStatistics.count)"
        case .export:
            return "\(report.exportReadiness.issues.count)"
        }
    }

    private func sectionHeading(for section: DocumentInspectorSection) -> String {
        switch section {
        case .summary:
            return "Document health at a glance"
        case .metadata:
            return "Front matter and file facts"
        case .links:
            return "Rendered link inventory"
        case .assets:
            return "Images and local asset status"
        case .diagnostics:
            return "Warnings from the render pipeline"
        case .statistics:
            return "Reading, structure, and rich content"
        case .export:
            return "PDF and print readiness"
        }
    }

    private func sectionSubtitle(for section: DocumentInspectorSection, report: DocumentInspectionReport) -> String {
        switch section {
        case .summary:
            return "\(report.statistics.words) words, \(report.links.count) links, \(report.assets.count) assets."
        case .metadata:
            return report.metadata.frontMatterFormat.map { "\($0.rawValue.uppercased()) front matter plus file metadata." } ?? "File metadata without front matter."
        case .links:
            return "Local, remote, malformed, and unsupported links stay visible."
        case .assets:
            return "Local images include path and size details when available."
        case .diagnostics:
            return "Diagnostics are grouped into user-facing review items."
        case .statistics:
            return "Counts include headings, sections, tables, callouts, Mermaid, and math."
        case .export:
            return report.exportReadiness.isReady ? "No blocking export issues." : "Review warnings before sharing this document."
        }
    }

    private func assetInfoText(_ info: DocumentAssetFileInfo?) -> String {
        guard let info else {
            return "Not available"
        }

        let byteText = info.byteSize.map { "\($0) bytes" } ?? "unknown size"
        if let width = info.pixelWidth, let height = info.pixelHeight {
            return "\(width)x\(height), \(byteText)"
        }
        return byteText
    }

    private func snapshotChromeCSS(appearance: String) -> String {
        let isDark = appearance == "dark"
        let background = isDark ? "#101318" : "#eef2f5"
        let sidebar = isDark ? "#161b22" : "#f8fafc"
        let panel = isDark ? "#0f141b" : "#ffffff"
        let text = isDark ? "#e6edf3" : "#1f2937"
        let muted = isDark ? "#8b949e" : "#64748b"
        let border = isDark ? "#30363d" : "#d9e0e7"
        let accent = isDark ? "#7dd3fc" : "#2563eb"
        return """
        * { box-sizing: border-box; }
        html, body { min-height: 100%; }
        body {
          margin: 0;
          background: \(background);
          color: \(text);
          font: 15px/1.5 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif;
        }
        .snapshot-shell {
          display: grid;
          grid-template-columns: 300px minmax(0, 1fr);
          min-height: 100vh;
        }
        .snapshot-sidebar {
          background: \(sidebar);
          border-right: 1px solid \(border);
          padding: 28px 20px;
        }
        .snapshot-sidebar h1 {
          margin: 0;
          font-size: 24px;
          line-height: 1.15;
          letter-spacing: 0;
        }
        .muted, .panel-header p, .field-row span, .metric-card p, .theme-tile p, .theme-tile span, .section-row span, .issue span {
          color: \(muted);
        }
        .eyebrow {
          margin: 0 0 8px;
          color: \(accent);
          font-size: 12px;
          font-weight: 700;
          letter-spacing: 0;
          text-transform: uppercase;
        }
        .nav-list {
          display: grid;
          gap: 8px;
          margin: 26px 0;
          padding: 0;
          list-style: none;
        }
        .nav-item {
          display: flex;
          align-items: center;
          justify-content: space-between;
          min-height: 38px;
          padding: 8px 10px;
          border: 1px solid transparent;
          border-radius: 8px;
        }
        .nav-item.is-selected {
          color: \(accent);
          background: color-mix(in srgb, \(accent) 13%, transparent);
          border-color: color-mix(in srgb, \(accent) 35%, transparent);
        }
        .sidebar-card, .content-card, .table-card, .metric-card, .theme-tile, .setting-control, .readiness-card, .notice-row {
          background: \(panel);
          border: 1px solid \(border);
          border-radius: 8px;
          box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
        }
        .sidebar-card {
          display: grid;
          gap: 4px;
          padding: 14px;
        }
        .snapshot-panel {
          min-width: 0;
          padding: 34px;
          overflow: hidden;
        }
        .panel-header {
          max-width: 820px;
          margin-bottom: 22px;
        }
        .panel-header h2 {
          margin: 0;
          font-size: 30px;
          line-height: 1.12;
          letter-spacing: 0;
        }
        .panel-header p {
          margin: 8px 0 0;
          max-width: 760px;
        }
        .metric-grid {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          gap: 12px;
          margin-bottom: 16px;
        }
        .metric-card {
          min-height: 116px;
          padding: 16px;
        }
        .metric-card span, .setting-control span {
          color: \(muted);
          font-size: 12px;
          font-weight: 700;
          text-transform: uppercase;
        }
        .metric-card strong {
          display: block;
          margin-top: 10px;
          font-size: 28px;
          line-height: 1.1;
        }
        .content-card, .table-card, .readiness-card, .notice-row {
          margin-bottom: 16px;
          padding: 18px;
        }
        h3 {
          margin: 0 0 12px;
          font-size: 16px;
        }
        .field-row, .section-row, .issue {
          display: grid;
          gap: 6px;
          padding: 12px 0;
          border-top: 1px solid \(border);
        }
        .field-row:first-of-type, .section-row:first-of-type, .issue:first-of-type {
          border-top: 0;
        }
        .field-row p, .issue p, .metric-card p, .theme-tile p {
          margin: 0;
        }
        .chip-row {
          display: flex;
          flex-wrap: wrap;
          gap: 6px;
        }
        .chip-row span {
          padding: 3px 8px;
          border: 1px solid \(border);
          border-radius: 999px;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          table-layout: fixed;
        }
        th, td {
          padding: 10px 8px;
          border-top: 1px solid \(border);
          text-align: left;
          overflow-wrap: anywhere;
          vertical-align: top;
        }
        th {
          color: \(muted);
          font-size: 12px;
          text-transform: uppercase;
        }
        .issue strong {
          color: \(accent);
        }
        .issue-warning strong, .issue-error strong {
          color: #d97706;
        }
        .section-row i, .meter {
          display: block;
          height: 7px;
          overflow: hidden;
          background: color-mix(in srgb, \(accent) 12%, \(panel));
          border-radius: 999px;
        }
        .section-row i::before {
          display: block;
          width: var(--bar-width);
          height: 100%;
          background: \(accent);
          content: "";
        }
        .toolbar-row {
          display: flex;
          gap: 10px;
          margin-bottom: 16px;
        }
        button {
          min-height: 34px;
          padding: 0 12px;
          color: \(text);
          background: \(panel);
          border: 1px solid \(border);
          border-radius: 7px;
          font: inherit;
        }
        .theme-grid {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          gap: 12px;
        }
        .theme-tile {
          min-height: 156px;
          padding: 14px;
        }
        .theme-swatch {
          height: 46px;
          margin-bottom: 12px;
          border-radius: 7px;
          background: linear-gradient(135deg, #f8fafc, #2563eb 52%, #111827);
        }
        .swatch-catppuccin { background: linear-gradient(135deg, #f5e0dc, #cba6f7, #181825); }
        .swatch-tokyo-night { background: linear-gradient(135deg, #c0caf5, #7aa2f7, #1a1b26); }
        .swatch-everforest { background: linear-gradient(135deg, #fff4d2, #a7c080, #2d353b); }
        .swatch-nord { background: linear-gradient(135deg, #eceff4, #88c0d0, #2e3440); }
        .swatch-rose-pine { background: linear-gradient(135deg, #faf4ed, #ebbcba, #191724); }
        .swatch-dracula { background: linear-gradient(135deg, #f8f8f2, #bd93f9, #282a36); }
        .swatch-gruvbox { background: linear-gradient(135deg, #fbf1c7, #d79921, #282828); }
        .swatch-user { background: linear-gradient(135deg, #fff7ed, #0f766e, #111827); }
        .settings-grid {
          display: grid;
          grid-template-columns: repeat(2, minmax(0, 1fr));
          gap: 12px;
          margin-bottom: 16px;
        }
        .setting-control {
          position: relative;
          min-height: 96px;
          padding: 16px;
        }
        .setting-control strong {
          display: block;
          margin-top: 10px;
          font-size: 21px;
        }
        .toggle {
          position: absolute;
          right: 16px;
          bottom: 16px;
          width: 42px;
          height: 24px;
          border-radius: 999px;
          background: \(border);
        }
        .toggle::after {
          position: absolute;
          top: 4px;
          left: 4px;
          width: 16px;
          height: 16px;
          border-radius: 50%;
          background: #fff;
          content: "";
        }
        .toggle.is-on {
          background: \(accent);
        }
        .toggle.is-on::after {
          left: 22px;
        }
        .meter span {
          display: block;
          height: 100%;
          background: \(accent);
        }
        .empty-state {
          margin: 0;
          color: \(muted);
        }
        """
    }

    private func loadHTML(_ html: String, baseURL: URL, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { continuation in
            navigationContinuation = continuation
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    private func takeSnapshot(webView: WKWebView, configuration: WKSnapshotConfiguration) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: SnapshotError.imageEncodingFailed("unknown"))
                }
            }
        }
    }

    private func writePDF(from webView: WKWebView, to destinationURL: URL, id: String) async throws {
        let configuration = WKPDFConfiguration()
        configuration.rect = webView.bounds

        let data = try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: configuration) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        guard data.count > 10_000 else {
            throw SnapshotError.pdfExportFailed(id)
        }

        try data.write(to: destinationURL)
    }

    private func snapshotHasContent(_ image: NSImage) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return false
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var uniqueSamples = Set<UInt32>()
        let stride = max(1, pixels.count / 8000)
        var index = 0
        while index + 3 < pixels.count {
            let value = UInt32(pixels[index]) << 24
                | UInt32(pixels[index + 1]) << 16
                | UInt32(pixels[index + 2]) << 8
                | UInt32(pixels[index + 3])
            uniqueSamples.insert(value)
            if uniqueSamples.count > 8 {
                return true
            }
            index += stride
        }

        return false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume()
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: SnapshotError.webNavigationFailed(error.localizedDescription))
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: SnapshotError.webNavigationFailed(error.localizedDescription))
        navigationContinuation = nil
    }
}

private extension JSONEncoder {
    static var openMarkedPretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
