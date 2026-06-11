import SwiftUI
import OpenMarkedCore

enum DiagnosticDisplayContext {
    case inspector
    case popover
}

enum DiagnosticColorContext {
    case label
    case group
}

enum DiagnosticDisplayMetadata {
    static func kindTitle(
        for kind: RenderDiagnosticKind,
        context: DiagnosticDisplayContext = .inspector
    ) -> String {
        switch kind {
        case .missingLocalImage:
            return context == .popover ? "Images" : "Missing Images"
        case .missingLocalLink:
            return "Missing Links"
        case .missingHeadingFragment:
            return "Heading Links"
        case .malformedLink:
            return "Malformed Links"
        case .malformedFrontMatter:
            return "Front Matter"
        case .unsupportedLinkScheme:
            return "Unsupported Links"
        case .mermaidRenderFailure:
            return "Mermaid"
        case .mathRenderFailure:
            return "Math"
        case .richContentDisabled:
            return "Disabled Features"
        case .malformedGitHubCallout:
            return "Callouts"
        case .linkValidationSkipped:
            return "Skipped Link Checks"
        case .unsupportedExtension:
            return context == .popover ? "Renderer Extensions" : "Unsupported Files"
        case .renderFailure:
            return "Rendering"
        }
    }

    static func severityTitle(for severity: RenderDiagnosticSeverity) -> String {
        switch severity {
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }

    static func iconName(
        for diagnostic: RenderDiagnostic,
        context: DiagnosticDisplayContext = .inspector
    ) -> String {
        guard context == .popover else {
            return diagnostic.severity == .warning ? "exclamationmark.triangle" : "info.circle"
        }

        switch diagnostic.kind {
        case .missingLocalImage:
            return "photo"
        case .missingLocalLink, .malformedLink, .unsupportedLinkScheme, .linkValidationSkipped:
            return "link"
        case .malformedFrontMatter:
            return "tag"
        case .missingHeadingFragment:
            return "number"
        default:
            break
        }

        switch diagnostic.severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    static func tint(
        for severity: RenderDiagnosticSeverity,
        chrome: ResolvedAppChromeTheme,
        context: DiagnosticColorContext = .label
    ) -> Color {
        switch context {
        case .group:
            return severity == .warning ? chrome.warning : chrome.secondaryText
        case .label:
            switch severity {
            case .info:
                return chrome.secondaryText
            case .warning:
                return chrome.warning
            case .error:
                return .red
            }
        }
    }

    static func sortPriority(for severity: RenderDiagnosticSeverity) -> Int {
        switch severity {
        case .error:
            return 0
        case .warning:
            return 1
        case .info:
            return 2
        }
    }
}

extension RenderDiagnostic {
    func matches(query: String) -> Bool {
        let haystack = [
            DiagnosticDisplayMetadata.kindTitle(for: kind),
            kind.rawValue,
            DiagnosticDisplayMetadata.severityTitle(for: severity),
            message,
            source ?? ""
        ]
        .joined(separator: " ")

        return haystack.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
