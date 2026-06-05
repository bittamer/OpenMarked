import AppKit
import Foundation
import OpenMarkedCore

@MainActor
final class DocumentWindowController: ObservableObject, Identifiable {
    let id = UUID()

    @Published private(set) var state = DocumentWindowState()
    private let stateStore = DocumentWindowStateStore.shared

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
            let markdownDocument = try MarkdownDocumentLoader.load(url: url)
            let document = OpenedDocument(markdownDocument: markdownDocument)
            state.finishOpening(document: document)
            if let restoredState = stateStore.restore(forDocumentID: markdownDocument.id) {
                state.applyRestoredLayout(restoredState.layout)
            }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            persistCurrentWindowState()
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
        persistCurrentWindowState()
    }

    func setTheme(id: String) {
        state.setTheme(id: id)
        persistCurrentWindowState()
    }

    func zoomIn() {
        state.zoomIn()
        persistCurrentWindowState()
    }

    func zoomOut() {
        state.zoomOut()
        persistCurrentWindowState()
    }

    func resetZoom() {
        state.resetZoom()
        persistCurrentWindowState()
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

    func persistCurrentWindowState() {
        guard let markdownDocument = state.currentMarkdownDocument else {
            return
        }

        stateStore.save(
            document: markdownDocument,
            layout: state.layout,
            frame: window.map {
                DocumentWindowFrame(
                    x: Double($0.frame.origin.x),
                    y: Double($0.frame.origin.y),
                    width: Double($0.frame.size.width),
                    height: Double($0.frame.size.height)
                )
            }
        )
    }
}
