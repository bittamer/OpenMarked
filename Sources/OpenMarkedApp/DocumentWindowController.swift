import AppKit
import Foundation
import OpenMarkedCore

@MainActor
final class DocumentWindowController: ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var state = DocumentWindowState()
    weak var window: NSWindow? {
        didSet {
            updateWindowTitle()
        }
    }

    var shouldReplaceWithOpenedDocument: Bool {
        if case .empty = state.content {
            return true
        }
        return false
    }

    func open(url: URL) {
        state.beginOpening(url: url)
        updateWindowTitle()

        do {
            let document = try DocumentOpenValidator.validate(url: url)
            state.finishOpening(document: document)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        } catch let error as DocumentOpenError {
            state.failOpening(error)
        } catch {
            state.failOpening(
                DocumentOpenError(
                    kind: .unreadable,
                    url: url,
                    message: "\(url.lastPathComponent) could not be opened."
                )
            )
        }

        updateWindowTitle()
    }

    func showNoSupportedFilesError() {
        state.failOpening(
            DocumentOpenError(
                kind: .noSupportedFiles,
                message: "No supported Markdown or text files were selected."
            )
        )
        updateWindowTitle()
    }

    func reloadPreviewPlaceholder() {
        guard state.canReloadPreview else {
            return
        }
        state.notePlaceholderAction("Preview reload is ready for the renderer phase")
    }

    func toggleOutline() {
        state.toggleOutline()
    }

    func setTheme(id: String) {
        state.setTheme(id: id)
    }

    func zoomIn() {
        state.zoomIn()
    }

    func zoomOut() {
        state.zoomOut()
    }

    func resetZoom() {
        state.resetZoom()
    }

    func exportHTMLPlaceholder() {
        guard state.canExport else {
            return
        }
        state.notePlaceholderAction("HTML export lands in Phase 8")
    }

    func exportPDFPlaceholder() {
        guard state.canExport else {
            return
        }
        state.notePlaceholderAction("PDF export lands in Phase 8")
    }

    func printPlaceholder() {
        guard state.canExport else {
            return
        }
        state.notePlaceholderAction("Print support lands in Phase 8")
    }

    func searchPlaceholder() {
        guard state.hasDocument else {
            return
        }
        state.notePlaceholderAction("Search lands in Phase 7")
    }

    func helpPlaceholder() {
        state.notePlaceholderAction("Help documentation lands after the core MVP")
    }

    func updateWindowTitle() {
        window?.title = state.windowTitle
    }
}
