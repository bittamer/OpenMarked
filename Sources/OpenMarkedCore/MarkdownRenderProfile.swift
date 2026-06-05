import Foundation

public enum HeadingSlugStyle: String, Codable, Equatable, Sendable {
    case openMarked
    case gitHub
}

public enum MarkdownRenderProfile: String, CaseIterable, Codable, Identifiable, Sendable {
    case openMarked
    case gitHubReadme

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .openMarked:
            return "OpenMarked"
        case .gitHubReadme:
            return "GitHub README"
        }
    }

    public var headingSlugStyle: HeadingSlugStyle {
        switch self {
        case .openMarked:
            return .openMarked
        case .gitHubReadme:
            return .gitHub
        }
    }

    public var defaultRichMarkdownOptions: RichMarkdownOptions {
        switch self {
        case .openMarked, .gitHubReadme:
            return RichMarkdownOptions.default
        }
    }

    public var supportsGitHubCallouts: Bool {
        true
    }

    public var validatesHeadingLinksByDefault: Bool {
        defaultRichMarkdownOptions.validatesHeadingFragments
    }
}
