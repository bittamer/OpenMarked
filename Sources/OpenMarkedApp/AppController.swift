import AppKit
import SwiftUI
import UniformTypeIdentifiers
import OpenMarkedCore

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    @Published private(set) var activeWindowController: DocumentWindowController?
    @Published private(set) var settings: ApplicationSettings

    private var retainedWindows: [UUID: NSWindow] = [:]
    private var retainedWindowDelegates: [UUID: WindowLifecycleDelegate] = [:]
    private let settingsStore = ApplicationSettingsStore.shared
    private var didAttemptSessionRestore = false

    private init() {
        self.settings = settingsStore.load()
    }

    var activeCanReloadPreview: Bool {
        activeWindowController?.state.canReloadPreview ?? false
    }

    var activeCanExport: Bool {
        activeWindowController?.state.canExport ?? false
    }

    var activeHasDocument: Bool {
        activeWindowController?.state.hasDocument ?? false
    }

    func registerWindowController(_ controller: DocumentWindowController) {
        if activeWindowController == nil {
            activeWindowController = controller
        }
    }

    func setActiveWindowController(_ controller: DocumentWindowController) {
        activeWindowController = controller
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File"
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.allowedContentTypes = AppInfo.supportedFileExtensions.compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK else {
            return
        }

        openURLs(panel.urls, preferredController: activeWindowController, replacePreferredController: false)
    }

    func openURLs(
        _ urls: [URL],
        preferredController: DocumentWindowController? = nil,
        replacePreferredController: Bool = false
    ) {
        guard !urls.isEmpty else {
            preferredController?.showNoSupportedFilesError()
            return
        }

        let supportedURLs = urls.filter { AppInfo.supportsFileExtension($0.pathExtension) }
        guard !supportedURLs.isEmpty else {
            (preferredController ?? activeWindowController)?.showNoSupportedFilesError()
            return
        }

        if settings.restoresLastOpenedDocuments {
            settingsStore.saveLastDocumentURLs(supportedURLs)
        }

        let target = preferredController ?? activeWindowController
        var remaining = supportedURLs

        if let firstURL = remaining.first {
            if let target, replacePreferredController || target.shouldReplaceWithOpenedDocument {
                target.open(url: firstURL)
                remaining.removeFirst()
            }
        }

        for url in remaining {
            createDocumentWindow(opening: url)
        }
    }

    func openDroppedURLs(_ urls: [URL], into controller: DocumentWindowController) {
        openURLs(urls, preferredController: controller, replacePreferredController: true)
    }

    func reloadPreview() {
        activeWindowController?.reloadPreview()
    }

    func toggleOutline() {
        activeWindowController?.toggleOutline()
    }

    func zoomIn() {
        activeWindowController?.zoomIn()
    }

    func zoomOut() {
        activeWindowController?.zoomOut()
    }

    func resetZoom() {
        activeWindowController?.resetZoom()
    }

    func setTheme(id: String) {
        activeWindowController?.setTheme(id: id)
    }

    func updateSettings(_ transform: (inout ApplicationSettings) -> Void) {
        let previousSettings = settings
        var updatedSettings = settings
        transform(&updatedSettings)
        settings = updatedSettings.normalized()
        settingsStore.save(settings)
        if !settings.restoresLastOpenedDocuments {
            settingsStore.saveLastDocumentURLs([])
        } else if !previousSettings.restoresLastOpenedDocuments,
                  let currentURL = activeWindowController?.state.currentDocument?.url {
            settingsStore.saveLastDocumentURLs([currentURL])
        }
        activeWindowController?.applySettings(settings)
    }

    func exportHTML() {
        activeWindowController?.exportHTML()
    }

    func copyRenderedHTML() {
        activeWindowController?.copyRenderedHTML()
    }

    func exportPDF() {
        activeWindowController?.exportPDF()
    }

    func printDocument() {
        activeWindowController?.printDocument()
    }

    func showSearchPlaceholder() {
        activeWindowController?.showSearch()
    }

    func findNext() {
        activeWindowController?.findNext()
    }

    func findPrevious() {
        activeWindowController?.findPrevious()
    }

    func revealSourceInFinder() {
        activeWindowController?.revealSourceInFinder()
    }

    func openSourceInDefaultEditor() {
        activeWindowController?.openSourceInDefaultEditor()
    }

    func copySourcePath() {
        activeWindowController?.copySourcePath()
    }

    func showHelpPlaceholder() {
        activeWindowController?.helpPlaceholder()
    }

    func showAboutPanel() {
        let credits = NSAttributedString(
            string: """
            \(AppInfo.summary)

            \(AppInfo.licenseName)
            \(AppInfo.repositoryURL.absoluteString)
            """,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .version: "Build \(AppInfo.build)",
            .credits: credits
        ])
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func restoreLastSessionIfNeeded() {
        guard !didAttemptSessionRestore else {
            return
        }
        didAttemptSessionRestore = true

        guard settings.restoresLastOpenedDocuments else {
            return
        }

        let urls = settingsStore.loadLastDocumentURLs().filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else {
            return
        }

        openURLs(urls, preferredController: activeWindowController, replacePreferredController: true)
    }

    private func createDocumentWindow(opening url: URL) {
        let controller = DocumentWindowController()
        let contentView = ContentView(controller: controller)
            .environmentObject(self)
        let hostingController = NSHostingController(rootView: contentView)
        let windowID = controller.id
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        let delegate = WindowLifecycleDelegate { [weak self, weak controller] in
            controller?.close()
            self?.retainedWindows.removeValue(forKey: windowID)
            self?.retainedWindowDelegates.removeValue(forKey: windowID)
        }

        controller.window = window
        window.title = controller.state.windowTitle
        window.contentViewController = hostingController
        window.delegate = delegate
        window.center()

        retainedWindows[windowID] = window
        retainedWindowDelegates[windowID] = delegate

        setActiveWindowController(controller)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.open(url: url)
    }
}

private final class WindowLifecycleDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
