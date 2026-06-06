import AppKit
import CryptoKit
import Foundation
import WebKit
import OpenMarkedCore

struct SnapshotCase: Sendable {
    let id: String
    let fixturePath: String
    let themeID: String
    let appearance: String
    let width: Int
    let height: Int
    let requiredDiagnosticKinds: [RenderDiagnosticKind]

    init(
        id: String,
        fixturePath: String,
        themeID: String,
        appearance: String,
        width: Int,
        height: Int,
        requiredDiagnosticKinds: [RenderDiagnosticKind] = []
    ) {
        self.id = id
        self.fixturePath = fixturePath
        self.themeID = themeID
        self.appearance = appearance
        self.width = width
        self.height = height
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
        }
    }
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
            schemaVersion: 2,
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
            SnapshotCase(id: "user-fixture-theme-gfm-light", fixturePath: "Fixtures/Markdown/gfm.md", themeID: "user.fixture", appearance: "light", width: 960, height: 720)
        ] + paletteThemeCases
    }

    private func capture(
        _ snapshotCase: SnapshotCase,
        renderer: CMarkGFMRenderer,
        outputDirectory: URL,
        pdfOutputDirectory: URL?
    ) async throws -> SnapshotManifestEntry {
        let documentURL = URL(fileURLWithPath: snapshotCase.fixturePath).standardizedFileURL
        let document = try MarkdownDocumentLoader.load(url: documentURL, createBookmark: false)
        let theme = try previewTheme(for: snapshotCase)
        let result = try renderer.render(RenderRequest(document: document, theme: theme))
        let diagnosticKinds = result.diagnostics.map(\.kind.rawValue).sorted()
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
            PreviewHTMLSecurityPolicy.sanitize(result.fullHTML),
            baseURL: document.sourceURL.deletingLastPathComponent(),
            in: webView
        )
        let richContentStatus = try await RichContentWebViewRuntime.installAndWait(
            for: result.richMarkdownState,
            in: webView
        )
        guard !richContentStatus.hasFailure else {
            throw SnapshotError.webNavigationFailed(richContentStatus.userMessage)
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
            width: snapshotCase.width,
            height: snapshotCase.height,
            file: fileName,
            bytes: pngData.count,
            sha256: SHA256.hash(data: pngData).hexString,
            diagnosticCount: result.diagnostics.count,
            diagnosticKinds: Array(Set(diagnosticKinds)).sorted()
        )
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
