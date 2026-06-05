import Foundation

public struct LinkReference: Equatable, Identifiable, Sendable {
    public let id: String
    public let source: String
    public let text: String
    public let occurrenceIndex: Int

    public init(source: String, text: String, occurrenceIndex: Int) {
        self.source = source
        self.text = text
        self.occurrenceIndex = occurrenceIndex
        self.id = "\(occurrenceIndex):\(source)"
    }
}

public enum LinkReferenceExtractor {
    public static func linkReferences(from html: String) -> [LinkReference] {
        let pattern = #"(?is)<a\b[^>]*\bhref\s*=\s*(["'])(.*?)\1[^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsHTML = html as NSString
        var references: [LinkReference] = []
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for (index, match) in matches.enumerated() {
            guard
                let hrefRange = Range(match.range(at: 2), in: html),
                let textRange = Range(match.range(at: 3), in: html)
            else {
                continue
            }

            let source = HTMLUtilities.decodeEntities(in: String(html[hrefRange]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty else {
                continue
            }

            references.append(
                LinkReference(
                    source: source,
                    text: HTMLUtilities.plainText(fromHTMLFragment: String(html[textRange])),
                    occurrenceIndex: index
                )
            )
        }

        return references
    }
}

public enum LinkValidator {
    public static let maxCrossDocumentHeadingFileSize = 1_000_000

    public static func diagnostics(
        from html: String,
        document: MarkdownDocument,
        outline: [OutlineItem],
        options: RichMarkdownOptions,
        renderProfile: MarkdownRenderProfile = .openMarked
    ) -> [RenderDiagnostic] {
        let references = LinkReferenceExtractor.linkReferences(from: html)
        guard !references.isEmpty else {
            return []
        }

        var collectedDiagnostics: [RenderDiagnostic] = []
        var seenDiagnosticIDs = Set<String>()
        let headingIDs = Set(outline.map(\.id))

        for reference in references {
            for diagnostic in diagnostics(
                for: reference,
                document: document,
                headingIDs: headingIDs,
                options: options,
                renderProfile: renderProfile
            ) {
                guard seenDiagnosticIDs.insert(diagnostic.id).inserted else {
                    continue
                }

                collectedDiagnostics.append(diagnostic)
            }
        }

        return collectedDiagnostics
    }

    private static func diagnostics(
        for reference: LinkReference,
        document: MarkdownDocument,
        headingIDs: Set<String>,
        options: RichMarkdownOptions,
        renderProfile: MarkdownRenderProfile
    ) -> [RenderDiagnostic] {
        let source = reference.source
        guard let components = URLComponents(string: source) else {
            return malformedDiagnosticsIfNeeded(for: source)
        }

        if let scheme = components.scheme?.lowercased() {
            return diagnosticsForSchemedLink(
                source: source,
                scheme: scheme,
                components: components,
                document: document,
                headingIDs: headingIDs,
                options: options,
                renderProfile: renderProfile
            )
        }

        if isSameDocumentReference(components: components, source: source) {
            return headingDiagnostics(
                source: source,
                fragment: components.fragment,
                targetDisplayName: nil,
                headingIDs: headingIDs,
                options: options
            )
        }

        guard options.validatesLocalLinks else {
            return []
        }

        guard let targetURL = LocalAssetReferenceExtractor.localFileURL(
            for: source,
            relativeTo: document.sourceURL.deletingLastPathComponent()
        ) else {
            return malformedDiagnosticsIfNeeded(for: source)
        }

        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            return [
                RenderDiagnostic(
                    severity: .warning,
                    kind: .missingLocalLink,
                    message: "Local link '\(source)' could not be found.",
                    source: source
                )
            ]
        }

        guard options.validatesHeadingFragments else {
            return []
        }

        if targetURL.standardizedFileURL.path == document.sourceURL.standardizedFileURL.path {
            return headingDiagnostics(
                source: source,
                fragment: components.fragment,
                targetDisplayName: nil,
                headingIDs: headingIDs,
                options: options
            )
        }

        return crossDocumentHeadingDiagnostics(
            source: source,
            targetURL: targetURL,
            fragment: components.fragment,
            currentDocumentURL: document.sourceURL,
            renderProfile: renderProfile
        )
    }

    private static func diagnosticsForSchemedLink(
        source: String,
        scheme: String,
        components: URLComponents,
        document: MarkdownDocument,
        headingIDs: Set<String>,
        options: RichMarkdownOptions,
        renderProfile: MarkdownRenderProfile
    ) -> [RenderDiagnostic] {
        switch scheme {
        case "http", "https":
            guard isValidRemoteURL(components) else {
                return [
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .malformedLink,
                        message: "Link '\(source)' is malformed.",
                        source: source
                    )
                ]
            }

            guard options.validatesRemoteLinks else {
                return []
            }

            return [
                RenderDiagnostic(
                    severity: .info,
                    kind: .linkValidationSkipped,
                    message: "Remote link '\(source)' was parsed but not checked automatically.",
                    source: source
                )
            ]
        case "file":
            guard options.validatesLocalLinks else {
                return []
            }

            guard let targetURL = LocalAssetReferenceExtractor.localFileURL(
                for: source,
                relativeTo: document.sourceURL.deletingLastPathComponent()
            ) else {
                return malformedDiagnosticsIfNeeded(for: source)
            }

            guard FileManager.default.fileExists(atPath: targetURL.path) else {
                return [
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .missingLocalLink,
                        message: "Local link '\(source)' could not be found.",
                        source: source
                    )
                ]
            }

            if targetURL.standardizedFileURL.path == document.sourceURL.standardizedFileURL.path {
                return headingDiagnostics(
                    source: source,
                    fragment: components.fragment,
                    targetDisplayName: nil,
                    headingIDs: headingIDs,
                    options: options
                )
            }

            guard options.validatesHeadingFragments else {
                return []
            }

            return crossDocumentHeadingDiagnostics(
                source: source,
                targetURL: targetURL,
                fragment: components.fragment,
                currentDocumentURL: document.sourceURL,
                renderProfile: renderProfile
            )
        case "mailto", "tel":
            guard !components.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return [
                    RenderDiagnostic(
                        severity: .warning,
                        kind: .malformedLink,
                        message: "Link '\(source)' is missing a destination.",
                        source: source
                    )
                ]
            }
            return []
        default:
            return [
                RenderDiagnostic(
                    severity: .warning,
                    kind: .unsupportedLinkScheme,
                    message: "Link scheme '\(scheme)' is not supported by OpenMarked preview.",
                    source: source
                )
            ]
        }
    }

    private static func headingDiagnostics(
        source: String,
        fragment: String?,
        targetDisplayName: String?,
        headingIDs: Set<String>,
        options: RichMarkdownOptions
    ) -> [RenderDiagnostic] {
        guard options.validatesHeadingFragments else {
            return []
        }

        guard let headingID = normalizedFragment(fragment), !headingID.isEmpty else {
            return []
        }

        guard !headingIDs.contains(headingID) else {
            return []
        }

        let location = targetDisplayName.map { " in '\($0)'" } ?? " in this document"
        return [
            RenderDiagnostic(
                severity: .warning,
                kind: .missingHeadingFragment,
                message: "Heading '#\(headingID)' could not be found\(location).",
                source: source
            )
        ]
    }

    private static func crossDocumentHeadingDiagnostics(
        source: String,
        targetURL: URL,
        fragment: String?,
        currentDocumentURL: URL,
        renderProfile: MarkdownRenderProfile
    ) -> [RenderDiagnostic] {
        guard let headingID = normalizedFragment(fragment), !headingID.isEmpty else {
            return []
        }

        if targetURL.standardizedFileURL.path == currentDocumentURL.standardizedFileURL.path {
            return []
        }

        guard AppInfo.supportsFileExtension(targetURL.pathExtension) else {
            return []
        }

        guard let fileSize = fileSize(at: targetURL) else {
            return [
                RenderDiagnostic(
                    severity: .info,
                    kind: .linkValidationSkipped,
                    message: "OpenMarked could not inspect headings in '\(targetURL.lastPathComponent)'.",
                    source: source
                )
            ]
        }

        guard fileSize <= maxCrossDocumentHeadingFileSize else {
            return [
                RenderDiagnostic(
                    severity: .info,
                    kind: .linkValidationSkipped,
                    message: "OpenMarked skipped heading validation for '\(targetURL.lastPathComponent)' because the file is large.",
                    source: source
                )
            ]
        }

        do {
            let targetDocument = try MarkdownDocumentLoader.load(url: targetURL, createBookmark: false)
            let renderOptions = RenderOptions(
                renderProfile: renderProfile,
                richMarkdownOptions: RichMarkdownOptions(
                    rendersMermaid: false,
                    rendersMath: false,
                    rendersGitHubCallouts: false,
                    validatesLocalLinks: false,
                    validatesHeadingFragments: false,
                    validatesRemoteLinks: false
                )
            )
            let result = try CMarkGFMRenderer().render(
                RenderRequest(
                    document: targetDocument,
                    options: renderOptions,
                    allowsRemoteImages: false
                )
            )
            let targetHeadingIDs = Set(result.outline.map(\.id))
            return headingDiagnostics(
                source: source,
                fragment: fragment,
                targetDisplayName: targetURL.lastPathComponent,
                headingIDs: targetHeadingIDs,
                options: RichMarkdownOptions()
            )
        } catch {
            return [
                RenderDiagnostic(
                    severity: .info,
                    kind: .linkValidationSkipped,
                    message: "OpenMarked could not inspect headings in '\(targetURL.lastPathComponent)'.",
                    source: source
                )
            ]
        }
    }

    private static func malformedDiagnosticsIfNeeded(for source: String) -> [RenderDiagnostic] {
        guard source.contains("://") || source.contains(":") else {
            return []
        }

        return [
            RenderDiagnostic(
                severity: .warning,
                kind: .malformedLink,
                message: "Link '\(source)' is malformed.",
                source: source
            )
        ]
    }

    private static func isSameDocumentReference(components: URLComponents, source: String) -> Bool {
        if source.hasPrefix("#") {
            return true
        }

        return components.scheme == nil
            && (components.path.isEmpty || components.path == ".")
            && components.fragment != nil
    }

    private static func isValidRemoteURL(_ components: URLComponents) -> Bool {
        guard let host = components.host, !host.isEmpty else {
            return false
        }

        return true
    }

    private static func normalizedFragment(_ fragment: String?) -> String? {
        guard let fragment else {
            return nil
        }

        return HTMLUtilities.decodeEntities(in: fragment)
            .removingPercentEncoding ?? HTMLUtilities.decodeEntities(in: fragment)
    }

    private static func fileSize(at url: URL) -> UInt64? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }

        return size.uint64Value
    }
}
