import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResolve: onResolve)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.resolve(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if context.coordinator.resolve(window: nsView.window) {
            return
        }

        DispatchQueue.main.async { [weak nsView] in
            context.coordinator.resolve(window: nsView?.window)
        }
    }

    final class Coordinator {
        private let onResolve: (NSWindow) -> Void
        private var resolvedWindowID: ObjectIdentifier?

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
        }

        @discardableResult
        func resolve(window: NSWindow?) -> Bool {
            guard let window else {
                return false
            }

            let windowID = ObjectIdentifier(window)
            guard resolvedWindowID != windowID else {
                return true
            }

            resolvedWindowID = windowID
            onResolve(window)
            return true
        }
    }
}
