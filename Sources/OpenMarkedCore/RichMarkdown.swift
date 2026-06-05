import Foundation

public enum RichMarkdownFeature: String, CaseIterable, Codable, Sendable {
    case mermaid
    case math
    case gitHubCallouts
    case localLinkValidation
    case headingLinkValidation
    case remoteLinkValidation

    public var displayName: String {
        switch self {
        case .mermaid:
            return "Mermaid diagrams"
        case .math:
            return "KaTeX math"
        case .gitHubCallouts:
            return "GitHub callouts"
        case .localLinkValidation:
            return "local link validation"
        case .headingLinkValidation:
            return "heading link validation"
        case .remoteLinkValidation:
            return "remote link validation"
        }
    }

    public var contactsNetwork: Bool {
        self == .remoteLinkValidation
    }
}

public struct RichMarkdownOptions: Codable, Equatable, Sendable {
    public var rendersMermaid: Bool
    public var rendersMath: Bool
    public var rendersGitHubCallouts: Bool
    public var validatesLocalLinks: Bool
    public var validatesHeadingFragments: Bool
    public var validatesRemoteLinks: Bool

    public init(
        rendersMermaid: Bool = true,
        rendersMath: Bool = true,
        rendersGitHubCallouts: Bool = true,
        validatesLocalLinks: Bool = true,
        validatesHeadingFragments: Bool = true,
        validatesRemoteLinks: Bool = false
    ) {
        self.rendersMermaid = rendersMermaid
        self.rendersMath = rendersMath
        self.rendersGitHubCallouts = rendersGitHubCallouts
        self.validatesLocalLinks = validatesLocalLinks
        self.validatesHeadingFragments = validatesHeadingFragments
        self.validatesRemoteLinks = validatesRemoteLinks
    }

    public static let `default` = RichMarkdownOptions()

    public var enabledFeatures: Set<RichMarkdownFeature> {
        var features: Set<RichMarkdownFeature> = []

        if rendersMermaid {
            features.insert(.mermaid)
        }
        if rendersMath {
            features.insert(.math)
        }
        if rendersGitHubCallouts {
            features.insert(.gitHubCallouts)
        }
        if validatesLocalLinks {
            features.insert(.localLinkValidation)
        }
        if validatesHeadingFragments {
            features.insert(.headingLinkValidation)
        }
        if validatesRemoteLinks {
            features.insert(.remoteLinkValidation)
        }

        return features
    }

    public func isEnabled(_ feature: RichMarkdownFeature) -> Bool {
        enabledFeatures.contains(feature)
    }

    private enum CodingKeys: String, CodingKey {
        case rendersMermaid
        case rendersMath
        case rendersGitHubCallouts
        case validatesLocalLinks
        case validatesHeadingFragments
        case validatesRemoteLinks
    }

    public init(from decoder: Decoder) throws {
        let defaults = RichMarkdownOptions.default
        let container = try decoder.container(keyedBy: CodingKeys.self)

        rendersMermaid = try container.decodeIfPresent(Bool.self, forKey: .rendersMermaid) ?? defaults.rendersMermaid
        rendersMath = try container.decodeIfPresent(Bool.self, forKey: .rendersMath) ?? defaults.rendersMath
        rendersGitHubCallouts = try container.decodeIfPresent(Bool.self, forKey: .rendersGitHubCallouts) ?? defaults.rendersGitHubCallouts
        validatesLocalLinks = try container.decodeIfPresent(Bool.self, forKey: .validatesLocalLinks) ?? defaults.validatesLocalLinks
        validatesHeadingFragments = try container.decodeIfPresent(Bool.self, forKey: .validatesHeadingFragments) ?? defaults.validatesHeadingFragments
        validatesRemoteLinks = try container.decodeIfPresent(Bool.self, forKey: .validatesRemoteLinks) ?? defaults.validatesRemoteLinks
    }
}

public struct RichMarkdownDocumentFeatures: Codable, Equatable, Sendable {
    public var features: Set<RichMarkdownFeature>

    public init(features: Set<RichMarkdownFeature> = []) {
        self.features = features
    }

    public var containsMermaid: Bool {
        features.contains(.mermaid)
    }

    public var containsMath: Bool {
        features.contains(.math)
    }

    public var containsGitHubCallouts: Bool {
        features.contains(.gitHubCallouts)
    }

    public var containsLocalLinks: Bool {
        features.contains(.localLinkValidation)
    }

    public var containsHeadingLinks: Bool {
        features.contains(.headingLinkValidation)
    }

    public var containsRemoteLinks: Bool {
        features.contains(.remoteLinkValidation)
    }

    public static func detect(in document: MarkdownDocument) -> RichMarkdownDocumentFeatures {
        detect(in: document.bodyText)
    }

    public static func detect(in markdown: String) -> RichMarkdownDocumentFeatures {
        var detected: Set<RichMarkdownFeature> = []

        if containsMermaidFence(in: markdown) {
            detected.insert(.mermaid)
        }
        if containsMathDelimiter(in: markdown) {
            detected.insert(.math)
        }
        if containsGitHubCallout(in: markdown) {
            detected.insert(.gitHubCallouts)
        }

        for destination in markdownLinkDestinations(in: markdown) {
            detected.formUnion(features(forLinkDestination: destination))
        }

        return RichMarkdownDocumentFeatures(features: detected)
    }

    private static func containsMermaidFence(in markdown: String) -> Bool {
        markdown
            .split(whereSeparator: \.isNewline)
            .contains { rawLine in
                let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedLine.hasPrefix("```") || trimmedLine.hasPrefix("~~~") else {
                    return false
                }

                let infoString = trimmedLine
                    .dropFirst(3)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(whereSeparator: \.isWhitespace)
                    .first?
                    .lowercased()

                return infoString == "mermaid" || infoString == "mmd"
            }
    }

    private static func containsGitHubCallout(in markdown: String) -> Bool {
        let supportedMarkers: Set<String> = ["NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION"]
        return markdown
            .split(whereSeparator: \.isNewline)
            .contains { rawLine in
                let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedLine.hasPrefix(">") else {
                    return false
                }

                let marker = trimmedLine
                    .dropFirst()
                    .trimmingCharacters(in: .whitespaces)
                    .uppercased()

                return supportedMarkers.contains { marker.hasPrefix("[!\($0)]") }
            }
    }

    private static func containsMathDelimiter(in markdown: String) -> Bool {
        MathDelimiterRules.containsMath(in: markdown)
    }

    private static func markdownLinkDestinations(in markdown: String) -> [String] {
        let pattern = #"!?\[[^\]]+\]\(([^)\s]+)(?:\s+["'][^)]*["'])?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsMarkdown = markdown as NSString
        return regex.matches(in: markdown, range: NSRange(location: 0, length: nsMarkdown.length)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: markdown) else {
                return nil
            }

            return String(markdown[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func features(forLinkDestination destination: String) -> Set<RichMarkdownFeature> {
        guard !destination.isEmpty else {
            return []
        }

        var features: Set<RichMarkdownFeature> = []
        let linkWithoutTitle = destination
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? destination

        if linkWithoutTitle.hasPrefix("#") {
            features.insert(.headingLinkValidation)
            return features
        }

        if linkWithoutTitle.contains("#") {
            features.insert(.headingLinkValidation)
        }

        if let components = URLComponents(string: linkWithoutTitle),
           let scheme = components.scheme?.lowercased() {
            switch scheme {
            case "http", "https":
                features.insert(.remoteLinkValidation)
            case "file":
                features.insert(.localLinkValidation)
            case "mailto", "tel":
                break
            default:
                features.insert(.localLinkValidation)
            }

            return features
        }

        features.insert(.localLinkValidation)
        return features
    }
}

public struct RichMarkdownRenderState: Equatable, Sendable {
    public let options: RichMarkdownOptions
    public let documentFeatures: RichMarkdownDocumentFeatures

    public init(
        options: RichMarkdownOptions = .default,
        documentFeatures: RichMarkdownDocumentFeatures = RichMarkdownDocumentFeatures()
    ) {
        self.options = options
        self.documentFeatures = documentFeatures
    }

    public static let empty = RichMarkdownRenderState()

    public var enabledDocumentFeatures: Set<RichMarkdownFeature> {
        documentFeatures.features.intersection(options.enabledFeatures)
    }

    public var disabledDocumentFeatures: Set<RichMarkdownFeature> {
        documentFeatures.features.subtracting(options.enabledFeatures)
    }

    public var requiresRemoteValidation: Bool {
        documentFeatures.containsRemoteLinks && options.validatesRemoteLinks
    }

    public var requiresMermaidRuntime: Bool {
        documentFeatures.containsMermaid && options.rendersMermaid
    }

    public var requiresMathRuntime: Bool {
        documentFeatures.containsMath && options.rendersMath
    }

    public var requiresRichContentRuntime: Bool {
        requiresMermaidRuntime || requiresMathRuntime
    }

    public var requiresRichContentStyles: Bool {
        requiresMermaidRuntime || requiresMathRuntime
    }

    public var richContentRuntimeFeatures: Set<RichMarkdownFeature> {
        enabledDocumentFeatures.intersection([.mermaid, .math])
    }

    public var disabledFeatureDiagnostics: [RenderDiagnostic] {
        disabledDocumentFeatures
            .filter { feature in
                switch feature {
                case .mermaid, .math, .gitHubCallouts:
                    return true
                case .localLinkValidation, .headingLinkValidation, .remoteLinkValidation:
                    return false
                }
            }
            .sorted { $0.rawValue < $1.rawValue }
            .map { feature in
                RenderDiagnostic(
                    severity: .info,
                    kind: .richContentDisabled,
                    message: "\(feature.displayName) is present but disabled in settings.",
                    source: feature.rawValue
                )
            }
    }
}
