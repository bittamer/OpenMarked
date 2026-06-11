@testable import OpenMarkedApp
@testable import OpenMarkedCore
import AppKit
import SwiftUI

#if canImport(Testing)
import Testing

@Test("Resolved app chrome theme uses cached theme and resolved colors")
func resolvedAppChromeThemeUsesCachedThemeAndResolvedColors() {
    let resolved = ResolvedAppChromeTheme(themeID: "missing", colorScheme: .dark)

    #expect(resolved.theme.id == AppChromeThemeStore.defaultThemeID)
    #expect(resolved.palette == AppChromeThemeStore.defaultTheme.darkPalette)
    #expect(resolved.nativeAppearanceName == .darkAqua)
    expectRGB(resolved.windowBackgroundNSColor, hex: resolved.palette.windowBackgroundHex)
    expectRGB(resolved.toolbarBackgroundNSColor, hex: resolved.palette.toolbarBackgroundHex)
    expectRGB(NSColor(resolved.accent), hex: resolved.palette.accentHex)
    expectRGB(NSColor(resolved.text), hex: resolved.palette.textHex)
}

@Test("App chrome styler applies native window appearance")
@MainActor
func appChromeStylerAppliesNativeWindowAppearance() {
    let previousAppearance = NSApplication.shared.appearance
    defer { NSApplication.shared.appearance = previousAppearance }

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    defer { window.close() }

    let theme = ResolvedAppChromeTheme(themeID: "everforest", colorScheme: .dark)
    AppChromeWindowStyler.apply(theme: theme, to: window)

    #expect(window.appearance?.name == .darkAqua)
    #expect(NSApplication.shared.appearance?.name == .darkAqua)
    #expect(window.titlebarAppearsTransparent)
    #expect(window.titlebarSeparatorStyle == .none)
    expectRGB(window.backgroundColor, hex: theme.palette.toolbarBackgroundHex)
}
#endif

#if canImport(Testing)
private func expectRGB(_ color: NSColor, hex: String) {
    let components = rgbComponents(for: color)
    let expected = rgbComponents(for: hex)
    #expect(abs(components.red - expected.red) < 0.001)
    #expect(abs(components.green - expected.green) < 0.001)
    #expect(abs(components.blue - expected.blue) < 0.001)
    #expect(abs(components.alpha - expected.alpha) < 0.001)
}
#endif

private func rgbComponents(for color: NSColor) -> (red: Double, green: Double, blue: Double, alpha: Double) {
    let color = color.usingColorSpace(.sRGB) ?? color
    return (
        Double(color.redComponent),
        Double(color.greenComponent),
        Double(color.blueComponent),
        Double(color.alphaComponent)
    )
}

private func rgbComponents(for hex: String) -> (red: Double, green: Double, blue: Double, alpha: Double) {
    let cleanedHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    let value = UInt64(cleanedHex, radix: 16) ?? 0

    switch cleanedHex.count {
    case 8:
        return (
            Double((value & 0xff00_0000) >> 24) / 255,
            Double((value & 0x00ff_0000) >> 16) / 255,
            Double((value & 0x0000_ff00) >> 8) / 255,
            Double(value & 0x0000_00ff) / 255
        )
    default:
        return (
            Double((value & 0xff0000) >> 16) / 255,
            Double((value & 0x00ff00) >> 8) / 255,
            Double(value & 0x0000ff) / 255,
            1
        )
    }
}
