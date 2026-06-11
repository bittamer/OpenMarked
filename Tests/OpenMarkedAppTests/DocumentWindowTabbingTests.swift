@testable import OpenMarkedApp
import AppKit

#if canImport(Testing)
import Testing

@Test("Document windows are configured for native tabbing")
@MainActor
func documentWindowsAreConfiguredForNativeTabbing() {
    let window = makeWindow()
    defer { window.close() }

    DocumentWindowTabbing.configureDocumentWindow(window)

    #expect(window.tabbingIdentifier == DocumentWindowTabbing.identifier)
    #expect(window.tabbingMode == .preferred)
}

@Test("Document window tabbing configuration is idempotent")
@MainActor
func documentWindowTabbingConfigurationIsIdempotent() {
    let window = makeWindow()
    defer { window.close() }

    DocumentWindowTabbing.configureDocumentWindow(window)
    DocumentWindowTabbing.configureDocumentWindow(window)

    #expect(window.tabbingIdentifier == DocumentWindowTabbing.identifier)
    #expect(window.tabbingMode == .preferred)
}
#endif

@MainActor
private func makeWindow() -> NSWindow {
    NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
}
