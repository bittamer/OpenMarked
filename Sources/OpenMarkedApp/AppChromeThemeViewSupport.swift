import AppKit
import SwiftUI
import OpenMarkedCore

struct ResolvedAppChromeTheme {
    let theme: AppChromeTheme
    let palette: AppChromePalette
    let colorScheme: ColorScheme

    var windowBackground: Color { Color(omHexRGB: palette.windowBackgroundHex) }
    var toolbarBackground: Color { Color(omHexRGB: palette.toolbarBackgroundHex) }
    var sidebarBackground: Color { Color(omHexRGB: palette.sidebarBackgroundHex) }
    var contentBackground: Color { Color(omHexRGB: palette.contentBackgroundHex) }
    var elevatedBackground: Color { Color(omHexRGB: palette.elevatedBackgroundHex) }
    var controlBackground: Color { Color(omHexRGB: palette.controlBackgroundHex) }
    var separator: Color { Color(omHexRGB: palette.separatorHex) }
    var text: Color { Color(omHexRGB: palette.textHex) }
    var secondaryText: Color { Color(omHexRGB: palette.secondaryTextHex) }
    var tertiaryText: Color { Color(omHexRGB: palette.tertiaryTextHex) }
    var accent: Color { Color(omHexRGB: palette.accentHex) }
    var warning: Color { Color(omHexRGB: palette.warningHex) }

    var windowBackgroundNSColor: NSColor {
        NSColor.omHexRGB(palette.windowBackgroundHex)
    }

    init(themeID: String, colorScheme: ColorScheme) {
        let theme = AppChromeThemeStore.theme(id: themeID)
        self.init(theme: theme, colorScheme: colorScheme)
    }

    init(theme: AppChromeTheme, colorScheme: ColorScheme) {
        self.theme = theme
        self.colorScheme = colorScheme
        self.palette = colorScheme == .dark ? theme.darkPalette : theme.lightPalette
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
        DispatchQueue.main.async {
            nsView.window?.backgroundColor = color
        }
    }
}

extension Color {
    init(omHexRGB hex: String) {
        let components = OMHexColorComponents(hex)
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
    static func omHexRGB(_ hex: String) -> NSColor {
        let components = OMHexColorComponents(hex)
        return NSColor(
            srgbRed: components.red,
            green: components.green,
            blue: components.blue,
            alpha: components.alpha
        )
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
