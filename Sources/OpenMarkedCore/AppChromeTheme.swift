import Foundation

public struct AppChromePalette: Equatable, Sendable {
    public let windowBackgroundHex: String
    public let toolbarBackgroundHex: String
    public let sidebarBackgroundHex: String
    public let contentBackgroundHex: String
    public let elevatedBackgroundHex: String
    public let controlBackgroundHex: String
    public let separatorHex: String
    public let textHex: String
    public let secondaryTextHex: String
    public let tertiaryTextHex: String
    public let accentHex: String
    public let warningHex: String

    public init(
        windowBackgroundHex: String,
        toolbarBackgroundHex: String,
        sidebarBackgroundHex: String,
        contentBackgroundHex: String,
        elevatedBackgroundHex: String,
        controlBackgroundHex: String,
        separatorHex: String,
        textHex: String,
        secondaryTextHex: String,
        tertiaryTextHex: String,
        accentHex: String,
        warningHex: String
    ) {
        self.windowBackgroundHex = windowBackgroundHex
        self.toolbarBackgroundHex = toolbarBackgroundHex
        self.sidebarBackgroundHex = sidebarBackgroundHex
        self.contentBackgroundHex = contentBackgroundHex
        self.elevatedBackgroundHex = elevatedBackgroundHex
        self.controlBackgroundHex = controlBackgroundHex
        self.separatorHex = separatorHex
        self.textHex = textHex
        self.secondaryTextHex = secondaryTextHex
        self.tertiaryTextHex = tertiaryTextHex
        self.accentHex = accentHex
        self.warningHex = warningHex
    }
}

public struct AppChromeTheme: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let lightVariantName: String
    public let darkVariantName: String
    public let lightPalette: AppChromePalette
    public let darkPalette: AppChromePalette

    public init(
        id: String,
        name: String,
        lightVariantName: String,
        darkVariantName: String,
        lightPalette: AppChromePalette,
        darkPalette: AppChromePalette
    ) {
        self.id = id
        self.name = name
        self.lightVariantName = lightVariantName
        self.darkVariantName = darkVariantName
        self.lightPalette = lightPalette
        self.darkPalette = darkPalette
    }
}

public enum AppChromeThemeStore {
    public static let defaultThemeID = "default"

    public static var allBuiltInThemes: [AppChromeTheme] {
        [
            builtInTheme(id: defaultThemeID),
            builtInTheme(id: "catppuccin"),
            builtInTheme(id: "tokyo-night"),
            builtInTheme(id: "everforest"),
            builtInTheme(id: "nord"),
            builtInTheme(id: "rose-pine"),
            builtInTheme(id: "dracula"),
            builtInTheme(id: "gruvbox")
        ]
    }

    public static var defaultTheme: AppChromeTheme {
        builtInTheme(id: defaultThemeID)
    }

    public static func theme(id: String) -> AppChromeTheme {
        let knownIDs = Set(allBuiltInThemes.map(\.id))
        guard knownIDs.contains(id) else {
            return defaultTheme
        }

        return builtInTheme(id: id)
    }

    public static func builtInTheme(id: String) -> AppChromeTheme {
        switch id {
        case "catppuccin":
            return AppChromeTheme(
                id: "catppuccin",
                name: "Catppuccin",
                lightVariantName: "Latte",
                darkVariantName: "Mocha",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#eff1f5",
                    toolbarBackgroundHex: "#e6e9ef",
                    sidebarBackgroundHex: "#e6e9ef",
                    contentBackgroundHex: "#eff1f5",
                    elevatedBackgroundHex: "#dce0e8",
                    controlBackgroundHex: "#ccd0da",
                    separatorHex: "#bcc0cc",
                    textHex: "#4c4f69",
                    secondaryTextHex: "#6c6f85",
                    tertiaryTextHex: "#8c8fa1",
                    accentHex: "#1e66f5",
                    warningHex: "#df8e1d"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#1e1e2e",
                    toolbarBackgroundHex: "#181825",
                    sidebarBackgroundHex: "#181825",
                    contentBackgroundHex: "#1e1e2e",
                    elevatedBackgroundHex: "#313244",
                    controlBackgroundHex: "#45475a",
                    separatorHex: "#313244",
                    textHex: "#cdd6f4",
                    secondaryTextHex: "#a6adc8",
                    tertiaryTextHex: "#9399b2",
                    accentHex: "#89b4fa",
                    warningHex: "#f9e2af"
                )
            )
        case "tokyo-night":
            return AppChromeTheme(
                id: "tokyo-night",
                name: "Tokyo Night",
                lightVariantName: "Day",
                darkVariantName: "Night",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#e1e2e7",
                    toolbarBackgroundHex: "#d4d6de",
                    sidebarBackgroundHex: "#d4d6de",
                    contentBackgroundHex: "#e1e2e7",
                    elevatedBackgroundHex: "#d9dbe3",
                    controlBackgroundHex: "#c4c8da",
                    separatorHex: "#b6bbcf",
                    textHex: "#343b58",
                    secondaryTextHex: "#6a6f87",
                    tertiaryTextHex: "#7d829b",
                    accentHex: "#2e7de9",
                    warningHex: "#8c6c3e"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#1a1b26",
                    toolbarBackgroundHex: "#16161e",
                    sidebarBackgroundHex: "#16161e",
                    contentBackgroundHex: "#1a1b26",
                    elevatedBackgroundHex: "#24283b",
                    controlBackgroundHex: "#2a2e42",
                    separatorHex: "#2a2e42",
                    textHex: "#c0caf5",
                    secondaryTextHex: "#a9b1d6",
                    tertiaryTextHex: "#787c99",
                    accentHex: "#7aa2f7",
                    warningHex: "#e0af68"
                )
            )
        case "everforest":
            return AppChromeTheme(
                id: "everforest",
                name: "Everforest",
                lightVariantName: "Light",
                darkVariantName: "Dark",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#fdf6e3",
                    toolbarBackgroundHex: "#f4f0d9",
                    sidebarBackgroundHex: "#f4f0d9",
                    contentBackgroundHex: "#fdf6e3",
                    elevatedBackgroundHex: "#efebd4",
                    controlBackgroundHex: "#e6e2cc",
                    separatorHex: "#d8d3ba",
                    textHex: "#5c6a72",
                    secondaryTextHex: "#829181",
                    tertiaryTextHex: "#9da9a0",
                    accentHex: "#3a94c5",
                    warningHex: "#dfa000"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#2d353b",
                    toolbarBackgroundHex: "#343f44",
                    sidebarBackgroundHex: "#343f44",
                    contentBackgroundHex: "#2d353b",
                    elevatedBackgroundHex: "#374247",
                    controlBackgroundHex: "#3d484d",
                    separatorHex: "#475258",
                    textHex: "#d3c6aa",
                    secondaryTextHex: "#9da9a0",
                    tertiaryTextHex: "#859289",
                    accentHex: "#7fbbb3",
                    warningHex: "#dbbc7f"
                )
            )
        case "nord":
            return AppChromeTheme(
                id: "nord",
                name: "Nord",
                lightVariantName: "Snow Storm",
                darkVariantName: "Polar Night",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#eceff4",
                    toolbarBackgroundHex: "#e5e9f0",
                    sidebarBackgroundHex: "#e5e9f0",
                    contentBackgroundHex: "#f6f8fb",
                    elevatedBackgroundHex: "#eef2f7",
                    controlBackgroundHex: "#d8dee9",
                    separatorHex: "#c9d2df",
                    textHex: "#2e3440",
                    secondaryTextHex: "#4c566a",
                    tertiaryTextHex: "#6c7688",
                    accentHex: "#5e81ac",
                    warningHex: "#b1832f"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#2e3440",
                    toolbarBackgroundHex: "#3b4252",
                    sidebarBackgroundHex: "#3b4252",
                    contentBackgroundHex: "#2e3440",
                    elevatedBackgroundHex: "#353c4a",
                    controlBackgroundHex: "#434c5e",
                    separatorHex: "#4c566a",
                    textHex: "#eceff4",
                    secondaryTextHex: "#abb6c9",
                    tertiaryTextHex: "#8f9aad",
                    accentHex: "#88c0d0",
                    warningHex: "#ebcb8b"
                )
            )
        case "rose-pine":
            return AppChromeTheme(
                id: "rose-pine",
                name: "Rose Pine",
                lightVariantName: "Dawn",
                darkVariantName: "Moon",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#faf4ed",
                    toolbarBackgroundHex: "#fffaf3",
                    sidebarBackgroundHex: "#fffaf3",
                    contentBackgroundHex: "#faf4ed",
                    elevatedBackgroundHex: "#f2e9e1",
                    controlBackgroundHex: "#dfdad9",
                    separatorHex: "#d2ced0",
                    textHex: "#575279",
                    secondaryTextHex: "#797593",
                    tertiaryTextHex: "#9893a5",
                    accentHex: "#286983",
                    warningHex: "#ea9d34"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#232136",
                    toolbarBackgroundHex: "#2a273f",
                    sidebarBackgroundHex: "#2a273f",
                    contentBackgroundHex: "#232136",
                    elevatedBackgroundHex: "#2f2b43",
                    controlBackgroundHex: "#393552",
                    separatorHex: "#44415a",
                    textHex: "#e0def4",
                    secondaryTextHex: "#908caa",
                    tertiaryTextHex: "#6e6a86",
                    accentHex: "#9ccfd8",
                    warningHex: "#f6c177"
                )
            )
        case "dracula":
            return AppChromeTheme(
                id: "dracula",
                name: "Dracula",
                lightVariantName: "Alucard",
                darkVariantName: "Dracula",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#fffbeb",
                    toolbarBackgroundHex: "#f6f1da",
                    sidebarBackgroundHex: "#f6f1da",
                    contentBackgroundHex: "#fffbeb",
                    elevatedBackgroundHex: "#f0ead0",
                    controlBackgroundHex: "#e4dfc8",
                    separatorHex: "#d7cfb0",
                    textHex: "#1f1f1f",
                    secondaryTextHex: "#6c664b",
                    tertiaryTextHex: "#8b8467",
                    accentHex: "#644ac9",
                    warningHex: "#846e15"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#282a36",
                    toolbarBackgroundHex: "#21222c",
                    sidebarBackgroundHex: "#21222c",
                    contentBackgroundHex: "#282a36",
                    elevatedBackgroundHex: "#2a2c38",
                    controlBackgroundHex: "#44475a",
                    separatorHex: "#44475a",
                    textHex: "#f8f8f2",
                    secondaryTextHex: "#9aa5d0",
                    tertiaryTextHex: "#70759a",
                    accentHex: "#bd93f9",
                    warningHex: "#f1fa8c"
                )
            )
        case "gruvbox":
            return AppChromeTheme(
                id: "gruvbox",
                name: "Gruvbox",
                lightVariantName: "Light",
                darkVariantName: "Dark",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#fbf1c7",
                    toolbarBackgroundHex: "#f2e5bc",
                    sidebarBackgroundHex: "#f2e5bc",
                    contentBackgroundHex: "#fbf1c7",
                    elevatedBackgroundHex: "#ece0b0",
                    controlBackgroundHex: "#ebdbb2",
                    separatorHex: "#d5c4a1",
                    textHex: "#3c3836",
                    secondaryTextHex: "#7c6f64",
                    tertiaryTextHex: "#928374",
                    accentHex: "#076678",
                    warningHex: "#b57614"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#282828",
                    toolbarBackgroundHex: "#32302f",
                    sidebarBackgroundHex: "#32302f",
                    contentBackgroundHex: "#282828",
                    elevatedBackgroundHex: "#3a3735",
                    controlBackgroundHex: "#3c3836",
                    separatorHex: "#504945",
                    textHex: "#ebdbb2",
                    secondaryTextHex: "#a89984",
                    tertiaryTextHex: "#928374",
                    accentHex: "#83a598",
                    warningHex: "#fabd2f"
                )
            )
        default:
            return AppChromeTheme(
                id: defaultThemeID,
                name: "Default",
                lightVariantName: "Light",
                darkVariantName: "Dark",
                lightPalette: AppChromePalette(
                    windowBackgroundHex: "#f5f5f7",
                    toolbarBackgroundHex: "#f0f0f2",
                    sidebarBackgroundHex: "#f4f4f6",
                    contentBackgroundHex: "#ffffff",
                    elevatedBackgroundHex: "#ffffff",
                    controlBackgroundHex: "#e9e9ec",
                    separatorHex: "#d7d7dc",
                    textHex: "#1d1d1f",
                    secondaryTextHex: "#62626a",
                    tertiaryTextHex: "#8e8e96",
                    accentHex: "#0a84ff",
                    warningHex: "#c47f00"
                ),
                darkPalette: AppChromePalette(
                    windowBackgroundHex: "#1f1f22",
                    toolbarBackgroundHex: "#2b2b2f",
                    sidebarBackgroundHex: "#26262a",
                    contentBackgroundHex: "#1c1c1f",
                    elevatedBackgroundHex: "#303034",
                    controlBackgroundHex: "#3a3a40",
                    separatorHex: "#4a4a50",
                    textHex: "#f5f5f7",
                    secondaryTextHex: "#b5b5bd",
                    tertiaryTextHex: "#868691",
                    accentHex: "#0a84ff",
                    warningHex: "#ffb340"
                )
            )
        }
    }
}
