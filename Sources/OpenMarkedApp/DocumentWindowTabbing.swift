import AppKit

@MainActor
enum DocumentWindowTabbing {
    static let identifier = "OpenMarkedDocument"

    static func enableAutomaticWindowTabbing() {
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    static func configureDocumentWindow(_ window: NSWindow) {
        guard window.tabbingIdentifier != identifier || window.tabbingMode != .preferred else {
            return
        }

        window.tabbingIdentifier = identifier
        window.tabbingMode = .preferred
    }

    static func addWindow(_ window: NSWindow, asTabTo anchorWindow: NSWindow) {
        configureDocumentWindow(anchorWindow)
        configureDocumentWindow(window)
        anchorWindow.addTabbedWindow(window, ordered: .above)
    }
}
