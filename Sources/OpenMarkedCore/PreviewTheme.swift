import Foundation

public struct PreviewTheme: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let screenCSS: String
    public let printCSS: String
    public let codeHighlightingCSS: String
    public let supportsDarkMode: Bool
    public let defaultMaxWidth: Int

    public init(
        id: String,
        name: String,
        screenCSS: String,
        printCSS: String,
        codeHighlightingCSS: String,
        supportsDarkMode: Bool,
        defaultMaxWidth: Int
    ) {
        self.id = id
        self.name = name
        self.screenCSS = screenCSS
        self.printCSS = printCSS
        self.codeHighlightingCSS = codeHighlightingCSS
        self.supportsDarkMode = supportsDarkMode
        self.defaultMaxWidth = defaultMaxWidth
    }
}

public enum PreviewThemeStore {
    public static let defaultThemeID = "default"

    public static var allBuiltInThemes: [PreviewTheme] {
        [
            builtInTheme(id: "default"),
            builtInTheme(id: "github"),
            builtInTheme(id: "minimal")
        ]
    }

    public static var defaultTheme: PreviewTheme {
        builtInTheme(id: defaultThemeID)
    }

    public static func builtInTheme(id: String) -> PreviewTheme {
        switch id {
        case "github":
            return loadTheme(id: "github", name: "GitHub", supportsDarkMode: true, defaultMaxWidth: 980)
        case "minimal":
            return loadTheme(id: "minimal", name: "Minimal", supportsDarkMode: true, defaultMaxWidth: 760)
        default:
            return loadTheme(id: "default", name: "Default", supportsDarkMode: true, defaultMaxWidth: 820)
        }
    }

    public static func theme(id: String) -> PreviewTheme {
        let knownIDs = Set(allBuiltInThemes.map(\.id))
        guard knownIDs.contains(id) else {
            return defaultTheme
        }

        return builtInTheme(id: id)
    }

    private static func loadTheme(id: String, name: String, supportsDarkMode: Bool, defaultMaxWidth: Int) -> PreviewTheme {
        PreviewTheme(
            id: id,
            name: name,
            screenCSS: loadCSS(named: id, fallback: fallbackScreenCSS),
            printCSS: loadCSS(named: "\(id)-print", fallback: fallbackPrintCSS),
            codeHighlightingCSS: loadCSS(named: "\(id)-code", fallback: fallbackCodeCSS),
            supportsDarkMode: supportsDarkMode,
            defaultMaxWidth: defaultMaxWidth
        )
    }

    private static func loadCSS(named name: String, fallback: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "css", subdirectory: "Themes")
            ?? Bundle.module.url(forResource: name, withExtension: "css")

        guard let url, let css = try? String(contentsOf: url, encoding: .utf8) else {
            return fallback
        }

        return css
    }

    private static let fallbackScreenCSS = """
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; color: #202124; background: #ffffff; }
    .om-document { max-width: var(--om-content-max-width); margin: 0 auto; padding: 48px; font-size: calc(17px * var(--om-font-scale)); line-height: 1.65; }
    pre, code { font-family: ui-monospace, SFMono-Regular, SF Mono, Menlo, monospace; }
    """

    private static let fallbackPrintCSS = """
    @page { margin: 0.75in; }
    body { background: #ffffff; color: #000000; }
    .om-document { max-width: none; padding: 0; }
    """

    private static let fallbackCodeCSS = """
    pre { padding: 16px; overflow: auto; background: #f6f8fa; border-radius: 6px; }
    code { background: #f6f8fa; border-radius: 4px; padding: 0.1em 0.25em; }
    pre code { padding: 0; background: transparent; }
    """
}
