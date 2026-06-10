import AppKit
import SwiftUI
import OpenMarkedCore

struct ResolvedAppChromeTheme {
    let theme: AppChromeTheme
    let palette: AppChromePalette
    let colorScheme: ColorScheme
    private let resolvedPalette: ResolvedAppChromePalette

    var windowBackground: Color { resolvedPalette.windowBackground }
    var toolbarBackground: Color { resolvedPalette.toolbarBackground }
    var sidebarBackground: Color { resolvedPalette.sidebarBackground }
    var contentBackground: Color { resolvedPalette.contentBackground }
    var elevatedBackground: Color { resolvedPalette.elevatedBackground }
    var controlBackground: Color { resolvedPalette.controlBackground }
    var separator: Color { resolvedPalette.separator }
    var text: Color { resolvedPalette.text }
    var secondaryText: Color { resolvedPalette.secondaryText }
    var tertiaryText: Color { resolvedPalette.tertiaryText }
    var accent: Color { resolvedPalette.accent }
    var warning: Color { resolvedPalette.warning }
    var windowBackgroundNSColor: NSColor { resolvedPalette.windowBackgroundNSColor }

    init(themeID: String, colorScheme: ColorScheme) {
        let theme = AppChromeThemeStore.theme(id: themeID)
        if let cachedTheme = Self.builtInThemeCache[CacheKey(themeID: theme.id, colorScheme: colorScheme)] {
            self = cachedTheme
            return
        }

        self.init(theme: theme, colorScheme: colorScheme)
    }

    init(theme: AppChromeTheme, colorScheme: ColorScheme) {
        self.theme = theme
        self.colorScheme = colorScheme
        self.palette = colorScheme == .dark ? theme.darkPalette : theme.lightPalette
        self.resolvedPalette = ResolvedAppChromePalette(palette: palette)
    }

    private static let builtInThemeCache: [CacheKey: ResolvedAppChromeTheme] = {
        Dictionary(
            uniqueKeysWithValues: AppChromeThemeStore.allBuiltInThemes.flatMap { theme in
                [
                    (CacheKey(themeID: theme.id, colorScheme: .light), ResolvedAppChromeTheme(theme: theme, colorScheme: .light)),
                    (CacheKey(themeID: theme.id, colorScheme: .dark), ResolvedAppChromeTheme(theme: theme, colorScheme: .dark))
                ]
            }
        )
    }()

    private struct CacheKey: Hashable {
        let themeID: String
        let isDark: Bool

        init(themeID: String, colorScheme: ColorScheme) {
            self.themeID = themeID
            self.isDark = colorScheme == .dark
        }
    }
}

private struct ResolvedAppChromePalette {
    let windowBackground: Color
    let toolbarBackground: Color
    let sidebarBackground: Color
    let contentBackground: Color
    let elevatedBackground: Color
    let controlBackground: Color
    let separator: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accent: Color
    let warning: Color
    let windowBackgroundNSColor: NSColor

    init(palette: AppChromePalette) {
        let windowComponents = OMHexColorComponentsCache.components(for: palette.windowBackgroundHex)
        windowBackground = Color(omComponents: windowComponents)
        toolbarBackground = Color(omHexRGB: palette.toolbarBackgroundHex)
        sidebarBackground = Color(omHexRGB: palette.sidebarBackgroundHex)
        contentBackground = Color(omHexRGB: palette.contentBackgroundHex)
        elevatedBackground = Color(omHexRGB: palette.elevatedBackgroundHex)
        controlBackground = Color(omHexRGB: palette.controlBackgroundHex)
        separator = Color(omHexRGB: palette.separatorHex)
        text = Color(omHexRGB: palette.textHex)
        secondaryText = Color(omHexRGB: palette.secondaryTextHex)
        tertiaryText = Color(omHexRGB: palette.tertiaryTextHex)
        accent = Color(omHexRGB: palette.accentHex)
        warning = Color(omHexRGB: palette.warningHex)
        windowBackgroundNSColor = NSColor.omRGB(components: windowComponents)
    }
}

private struct AppChromeThemeKey: EnvironmentKey {
    static let defaultValue = ResolvedAppChromeTheme(
        theme: AppChromeThemeStore.defaultTheme,
        colorScheme: .light
    )
}

extension EnvironmentValues {
    var appChromeTheme: ResolvedAppChromeTheme {
        get { self[AppChromeThemeKey.self] }
        set { self[AppChromeThemeKey.self] = newValue }
    }
}

extension View {
    func appChromeTheme(_ themeID: String) -> some View {
        modifier(AppChromeThemeModifier(themeID: themeID))
    }
}

private struct AppChromeThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let themeID: String

    func body(content: Content) -> some View {
        let resolvedTheme = ResolvedAppChromeTheme(themeID: themeID, colorScheme: colorScheme)

        content
            .environment(\.appChromeTheme, resolvedTheme)
            .foregroundStyle(resolvedTheme.text)
            .tint(resolvedTheme.accent)
            .background(resolvedTheme.windowBackground)
            .background(WindowChromeBackgroundWriter(color: resolvedTheme.windowBackgroundNSColor))
    }
}

private struct WindowChromeBackgroundWriter: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
            DispatchQueue.main.async { [weak nsView] in
                guard let window = nsView?.window else {
                    return
                }
                if !window.backgroundColor.isEqual(color) {
                    window.backgroundColor = color
                }
            }
            return
        }

        if !window.backgroundColor.isEqual(color) {
            window.backgroundColor = color
        }
    }
}

extension Color {
    init(omHexRGB hex: String) {
        self.init(omComponents: OMHexColorComponentsCache.components(for: hex))
    }

    fileprivate init(omComponents components: OMHexColorComponents) {
        self.init(
            .sRGB,
            red: components.red,
            green: components.green,
            blue: components.blue,
            opacity: components.alpha
        )
    }
}

private extension NSColor {
    static func omRGB(components: OMHexColorComponents) -> NSColor {
        NSColor(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
    }
}

private enum OMHexColorComponentsCache {
    private static let builtInComponents: [String: OMHexColorComponents] = {
        let hexValues = Set(
            AppChromeThemeStore.allBuiltInThemes.flatMap { theme in
                theme.lightPalette.omHexValues + theme.darkPalette.omHexValues
            }
        )
        return Dictionary(uniqueKeysWithValues: hexValues.map { ($0, OMHexColorComponents($0)) })
    }()

    static func components(for hex: String) -> OMHexColorComponents {
        builtInComponents[hex] ?? OMHexColorComponents(hex)
    }
}

private extension AppChromePalette {
    var omHexValues: [String] {
        [
            windowBackgroundHex,
            toolbarBackgroundHex,
            sidebarBackgroundHex,
            contentBackgroundHex,
            elevatedBackgroundHex,
            controlBackgroundHex,
            separatorHex,
            textHex,
            secondaryTextHex,
            tertiaryTextHex,
            accentHex,
            warningHex
        ]
    }
}

private struct OMHexColorComponents {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(_ hex: String) {
        let cleanedHex = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        var value: UInt64 = 0
        guard Scanner(string: cleanedHex).scanHexInt64(&value) else {
            red = 0
            green = 0
            blue = 0
            alpha = 1
            return
        }

        switch cleanedHex.count {
        case 8:
            red = Double((value & 0xff00_0000) >> 24) / 255
            green = Double((value & 0x00ff_0000) >> 16) / 255
            blue = Double((value & 0x0000_ff00) >> 8) / 255
            alpha = Double(value & 0x0000_00ff) / 255
        case 6:
            red = Double((value & 0xff0000) >> 16) / 255
            green = Double((value & 0x00ff00) >> 8) / 255
            blue = Double(value & 0x0000ff) / 255
            alpha = 1
        default:
            red = 0
            green = 0
            blue = 0
            alpha = 1
        }
    }
}
