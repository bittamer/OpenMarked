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
    private static let builtInThemeOrder = [
        "default",
        "github",
        "minimal",
        "catppuccin",
        "tokyo-night",
        "everforest",
        "nord",
        "rose-pine",
        "dracula",
        "gruvbox"
    ]
    private static let builtInThemeIDSet = Set(builtInThemeOrder)
    private static let builtInThemeCache: [String: PreviewTheme] = {
        Dictionary(
            uniqueKeysWithValues: builtInThemeOrder.map { id in
                (id, uncachedBuiltInTheme(id: id))
            }
        )
    }()

    public static var allBuiltInThemes: [PreviewTheme] {
        builtInThemeOrder.compactMap { builtInThemeCache[$0] }
    }

    public static var defaultTheme: PreviewTheme {
        builtInTheme(id: defaultThemeID)
    }

    public static func builtInTheme(id: String) -> PreviewTheme {
        builtInThemeCache[id] ?? builtInThemeCache[defaultThemeID] ?? uncachedBuiltInTheme(id: defaultThemeID)
    }

    public static var builtInThemeIDs: [String] {
        builtInThemeOrder
    }

    public static func isBuiltInThemeID(_ id: String) -> Bool {
        builtInThemeIDSet.contains(id)
    }

    private static func uncachedBuiltInTheme(id: String) -> PreviewTheme {
        switch id {
        case "github":
            return loadTheme(id: "github", name: "GitHub", supportsDarkMode: true, defaultMaxWidth: 980)
        case "minimal":
            return loadTheme(id: "minimal", name: "Minimal", supportsDarkMode: true, defaultMaxWidth: 760)
        case "catppuccin":
            return loadTheme(id: "catppuccin", name: "Catppuccin", supportsDarkMode: true, defaultMaxWidth: 880)
        case "tokyo-night":
            return loadTheme(id: "tokyo-night", name: "Tokyo Night", supportsDarkMode: true, defaultMaxWidth: 880)
        case "everforest":
            return loadTheme(id: "everforest", name: "Everforest", supportsDarkMode: true, defaultMaxWidth: 880)
        case "nord":
            return loadTheme(id: "nord", name: "Nord", supportsDarkMode: true, defaultMaxWidth: 880)
        case "rose-pine":
            return loadTheme(id: "rose-pine", name: "Rose Pine", supportsDarkMode: true, defaultMaxWidth: 880)
        case "dracula":
            return loadTheme(id: "dracula", name: "Dracula", supportsDarkMode: true, defaultMaxWidth: 880)
        case "gruvbox":
            return loadTheme(id: "gruvbox", name: "Gruvbox", supportsDarkMode: true, defaultMaxWidth: 880)
        default:
            return loadTheme(id: "default", name: "Default", supportsDarkMode: true, defaultMaxWidth: 820)
        }
    }

    public static func theme(id: String) -> PreviewTheme {
        guard isBuiltInThemeID(id) else {
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
        for bundle in resourceBundles {
            let url = bundle.url(forResource: name, withExtension: "css", subdirectory: "Themes")
                ?? bundle.url(forResource: name, withExtension: "css")

            if let url, let css = try? String(contentsOf: url, encoding: .utf8) {
                return css
            }
        }

        return fallback
    }

    private static var resourceBundles: [Bundle] {
        if let resourceURL = Bundle.main.resourceURL {
            let conventionalBundleURL = resourceURL.appendingPathComponent("OpenMarked_OpenMarkedCore.bundle")
            if let bundle = Bundle(url: conventionalBundleURL) {
                return [bundle]
            }
        }

        return [Bundle.module]
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
