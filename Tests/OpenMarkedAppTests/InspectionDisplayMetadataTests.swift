@testable import OpenMarkedApp
@testable import OpenMarkedCore

#if canImport(Testing)
import Testing

@Test("Diagnostic display metadata preserves labels, icons, and sort priority")
func diagnosticDisplayMetadataPreservesLabelsIconsAndSortPriority() {
    #expect(DiagnosticDisplayMetadata.kindTitle(for: .missingLocalImage) == "Missing Images")
    #expect(DiagnosticDisplayMetadata.kindTitle(for: .missingLocalImage, context: .popover) == "Images")
    #expect(DiagnosticDisplayMetadata.kindTitle(for: .unsupportedExtension) == "Unsupported Files")
    #expect(DiagnosticDisplayMetadata.kindTitle(for: .unsupportedExtension, context: .popover) == "Renderer Extensions")
    #expect(DiagnosticDisplayMetadata.severityTitle(for: .warning) == "Warning")
    #expect(DiagnosticDisplayMetadata.sortPriority(for: .error) < DiagnosticDisplayMetadata.sortPriority(for: .warning))
    #expect(DiagnosticDisplayMetadata.sortPriority(for: .warning) < DiagnosticDisplayMetadata.sortPriority(for: .info))

    let missingLink = RenderDiagnostic(
        severity: .warning,
        kind: .missingLocalLink,
        message: "Missing link",
        source: "missing.md"
    )
    let renderFailure = RenderDiagnostic(
        severity: .error,
        kind: .renderFailure,
        message: "Render failed",
        source: nil
    )

    #expect(DiagnosticDisplayMetadata.iconName(for: missingLink, context: .popover) == "link")
    #expect(DiagnosticDisplayMetadata.iconName(for: renderFailure, context: .popover) == "xmark.octagon")
    #expect(DiagnosticDisplayMetadata.iconName(for: renderFailure) == "info.circle")
}

@Test("Diagnostic matching uses shared display metadata")
func diagnosticMatchingUsesSharedDisplayMetadata() {
    let diagnostic = RenderDiagnostic(
        severity: .warning,
        kind: .missingLocalImage,
        message: "Could not resolve asset",
        source: "image.png"
    )

    #expect(diagnostic.matches(query: "missing images"))
    #expect(diagnostic.matches(query: "warning"))
    #expect(diagnostic.matches(query: "image.png"))
    #expect(!diagnostic.matches(query: "mermaid"))
}
#endif
