import AppKit
import SwiftUI
import UniformTypeIdentifiers
import OpenMarkedCore

@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    @Published private(set) var activeWindowController: DocumentWindowController?
    @Published private(set) var settings: ApplicationSettings
    @Published private(set) var userPreviewThemes: [UserPreviewTheme]

    private var documentWindows: [UUID: NSWindow] = [:]
    private var registeredWindowControllers: [UUID: DocumentWindowController] = [:]
    private var documentWindowActivity = DocumentWindowActivityRegistry()
    private var windowNotificationObservers: [NSObjectProtocol] = []
    private let settingsStore = ApplicationSettingsStore.shared
    private let userPreviewThemeStore = UserPreviewThemeStore.shared
    private var didAttemptSessionRestore = false

    private init() {
        self.settings = settingsStore.load()
        self.userPreviewThemes = userPreviewThemeStore.load()
        startDocumentWindowObservation()
    }

    var activeCanReloadPreview: Bool {
        activeWindowController?.state.canReloadPreview ?? false
    }

    var activeCanExport: Bool {
        activeWindowController?.state.canExport ?? false
    }

    var activeCanRepeatHTMLExport: Bool {
        activeWindowController?.canRepeatHTMLExport ?? false
    }

    var activeCanRepeatPDFExport: Bool {
        activeWindowController?.canRepeatPDFExport ?? false
    }

    var activeHasDocument: Bool {
        activeWindowController?.state.hasDocument ?? false
    }

    var activeHasWindow: Bool {
        activeWindowController != nil
    }

    var activeIsInspectorVisible: Bool {
        activeWindowController?.state.layout.isInspectorVisible ?? false
    }

    var availablePreviewThemes: [PreviewTheme] {
        PreviewThemeStore.allBuiltInThemes + userPreviewThemes.map(userPreviewThemeStore.previewTheme(for:))
    }

    var userPreviewThemesDirectoryURL: URL {
        userPreviewThemeStore.themesDirectoryURL
    }

    func previewTheme(id: String) -> PreviewTheme {
        if PreviewThemeStore.isBuiltInThemeID(id) {
            return PreviewThemeStore.builtInTheme(id: id)
        }

        return userPreviewThemeStore.previewTheme(id: id) ?? PreviewThemeStore.defaultTheme
    }

    func registerWindowController(_ controller: DocumentWindowController) {
        registeredWindowControllers[controller.id] = controller
        if activeWindowController == nil {
            activeWindowController = controller
        }
    }

    func registerDocumentWindow(_ window: NSWindow, controller: DocumentWindowController) {
        DocumentWindowTabbing.configureDocumentWindow(window)
        registeredWindowControllers[controller.id] = controller
        documentWindows[controller.id] = window

        if controller.window !== window {
            controller.window = window
        }

        documentWindowActivity.register(
            controllerID: controller.id,
            windowID: ObjectIdentifier(window)
        )

        if activeWindowController == nil || window.isKeyWindow || window.isMainWindow {
            setActiveWindowController(controller)
        }
    }

    func setActiveWindowController(_ controller: DocumentWindowController?) {
        activeWindowController = controller
        if let window = controller?.window {
            _ = documentWindowActivity.activate(windowID: ObjectIdentifier(window))
        }
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Markdown File"
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.message = "Choose Markdown or plain text files."

        guard panel.runModal() == .OK else {
            return
        }

        openURLs(panel.urls, preferredController: activeWindowController)
    }

    func openURLs(
        _ urls: [URL],
        preferredController: DocumentWindowController? = nil
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

        let originalPreferredController = controllerIfWindowIsAlive(preferredController)
        let originalActiveController = controllerIfWindowIsAlive(activeWindowController)
        let placements = DocumentOpenPlacementPlanner.plan(
            documentCount: supportedURLs.count,
            preferredWindow: descriptor(for: originalPreferredController),
            activeWindow: descriptor(for: originalActiveController)
        )
        var firstOpenedController: DocumentWindowController?

        for (url, placement) in zip(supportedURLs, placements) {
            switch placement {
            case .replace(let windowID):
                let controller = controller(
                    matching: windowID,
                    preferredController: originalPreferredController,
                    activeController: originalActiveController
                )

                if let controller {
                    controller.open(url: url)
                    setActiveAndFrontmost(controller)
                    if firstOpenedController == nil {
                        firstOpenedController = controller
                    }
                } else {
                    let controller = createDocumentWindow(opening: url)
                    if firstOpenedController == nil {
                        firstOpenedController = controller
                    }
                }

            case .newStandaloneWindow:
                let controller = createDocumentWindow(opening: url)
                if firstOpenedController == nil {
                    firstOpenedController = controller
                }

            case .newTab(let anchor):
                let anchorController = controller(
                    for: anchor,
                    preferredController: originalPreferredController,
                    activeController: originalActiveController,
                    firstOpenedController: firstOpenedController
                )
                let controller = createDocumentWindow(
                    opening: url,
                    tabbingAnchor: anchorController
                )
                if firstOpenedController == nil {
                    firstOpenedController = controller
                }
            }
        }
    }

    func openDroppedURLs(_ urls: [URL], into controller: DocumentWindowController) {
        openURLs(urls, preferredController: controller)
    }

    func reloadPreview() {
        activeWindowController?.reloadPreview()
    }

    func toggleOutline() {
        activeWindowController?.toggleOutline()
    }

    func toggleInspector() {
        activeWindowController?.toggleInspector()
    }

    func showInspector(section: DocumentInspectorSection) {
        activeWindowController?.showInspector(section: section)
    }

    func selectInspectorSection(_ section: DocumentInspectorSection) {
        activeWindowController?.selectInspectorSection(section)
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

    @discardableResult
    func importPreviewTheme() -> UserPreviewTheme? {
        let panel = NSOpenPanel()
        panel.title = "Import CSS Theme"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [UTType(filenameExtension: "css")].compactMap { $0 }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        do {
            let theme = try userPreviewThemeStore.importTheme(from: url)
            reloadUserPreviewThemes()
            setDefaultAndActivePreviewTheme(id: theme.id)
            return theme
        } catch {
            presentThemeError(error)
            return nil
        }
    }

    @discardableResult
    func duplicateBuiltInPreviewTheme(id: String) -> UserPreviewTheme? {
        do {
            let theme = try userPreviewThemeStore.duplicateBuiltInTheme(id: id)
            reloadUserPreviewThemes()
            setDefaultAndActivePreviewTheme(id: theme.id)
            return theme
        } catch {
            presentThemeError(error)
            return nil
        }
    }

    @discardableResult
    func renameUserPreviewTheme(id: String, name: String) -> UserPreviewTheme? {
        do {
            let theme = try userPreviewThemeStore.renameTheme(id: id, name: name)
            reloadUserPreviewThemes()
            return theme
        } catch {
            presentThemeError(error)
            return nil
        }
    }

    func deleteUserPreviewTheme(id: String) {
        do {
            try userPreviewThemeStore.deleteTheme(id: id)
            reloadUserPreviewThemes()

            if settings.defaultThemeID == id {
                updateSettings { settings in
                    settings.defaultThemeID = PreviewThemeStore.defaultThemeID
                }
            }

            if activeWindowController?.state.layout.selectedThemeID == id {
                setTheme(id: PreviewThemeStore.defaultThemeID)
            }
        } catch {
            presentThemeError(error)
        }
    }

    func revealUserPreviewThemesFolder() {
        do {
            try userPreviewThemeStore.ensureThemesDirectory()
            NSWorkspace.shared.activateFileViewerSelecting([userPreviewThemeStore.themesDirectoryURL])
        } catch {
            presentThemeError(error)
        }
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
        activeWindowController?.applySettings(settings, previousSettings: previousSettings)
    }

    func exportHTML() {
        activeWindowController?.exportHTML()
    }

    func repeatHTMLExport() {
        activeWindowController?.repeatHTMLExport()
    }

    func copyRenderedHTML() {
        activeWindowController?.copyRenderedHTML()
    }

    func exportPDF() {
        activeWindowController?.exportPDF()
    }

    func repeatPDFExport() {
        activeWindowController?.repeatPDFExport()
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

        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .version: "Build \(AppInfo.build)",
            .credits: credits
        ]
        if let icon = OpenMarkedAppIcon.image() {
            options[.applicationIcon] = icon
        }

        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
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

        openURLs(urls, preferredController: activeWindowController)
    }

    @discardableResult
    private func createDocumentWindow(
        opening url: URL,
        tabbingAnchor anchorController: DocumentWindowController? = nil
    ) -> DocumentWindowController {
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
        window.title = controller.state.windowTitle
        window.contentViewController = hostingController
        registerDocumentWindow(window, controller: controller)

        if let anchorWindow = anchorController?.window {
            DocumentWindowTabbing.addWindow(window, asTabTo: anchorWindow)
        } else {
            window.center()
        }

        documentWindows[windowID] = window

        setActiveAndFrontmost(controller)
        controller.open(url: url)
        return controller
    }

    private func controllerIfWindowIsAlive(_ controller: DocumentWindowController?) -> DocumentWindowController? {
        guard let controller, controller.window != nil else {
            return nil
        }

        return controller
    }

    private func descriptor(for controller: DocumentWindowController?) -> DocumentWindowDescriptor? {
        guard let controller = controllerIfWindowIsAlive(controller) else {
            return nil
        }

        return DocumentWindowDescriptor(
            id: controller.id,
            canReplaceWithOpenedDocument: controller.shouldReplaceWithOpenedDocument
        )
    }

    private func controller(
        matching id: UUID,
        preferredController: DocumentWindowController?,
        activeController: DocumentWindowController?
    ) -> DocumentWindowController? {
        if preferredController?.id == id {
            return preferredController
        }

        if activeController?.id == id {
            return activeController
        }

        return nil
    }

    private func controller(
        for anchor: DocumentOpenAnchor,
        preferredController: DocumentWindowController?,
        activeController: DocumentWindowController?,
        firstOpenedController: DocumentWindowController?
    ) -> DocumentWindowController? {
        switch anchor {
        case .existing(let id):
            return controller(
                matching: id,
                preferredController: preferredController,
                activeController: activeController
            )
        case .firstOpenedWindow:
            return firstOpenedController
        }
    }

    private func setActiveAndFrontmost(_ controller: DocumentWindowController) {
        setActiveWindowController(controller)
        guard let window = controller.window else {
            return
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startDocumentWindowObservation() {
        let notificationCenter = NotificationCenter.default
        let activeNotifications: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification
        ]

        for notificationName in activeNotifications {
            let observer = notificationCenter.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let window = notification.object as? NSWindow else {
                    return
                }

                Task { @MainActor in
                    self?.noteDocumentWindowBecameActive(window)
                }
            }
            windowNotificationObservers.append(observer)
        }

        let closeObserver = notificationCenter.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else {
                return
            }

            Task { @MainActor in
                self?.noteDocumentWindowWillClose(window)
            }
        }
        windowNotificationObservers.append(closeObserver)
    }

    func noteDocumentWindowBecameActive(_ window: NSWindow) {
        guard let controllerID = documentWindowActivity.activate(windowID: ObjectIdentifier(window)),
              let controller = registeredWindowControllers[controllerID] else {
            return
        }

        activeWindowController = controller
    }

    func noteDocumentWindowWillClose(_ window: NSWindow) {
        guard let closeResult = documentWindowActivity.close(windowID: ObjectIdentifier(window)) else {
            return
        }

        let closedController = registeredWindowControllers.removeValue(forKey: closeResult.closedControllerID)
        documentWindows.removeValue(forKey: closeResult.closedControllerID)
        closedController?.close()

        if activeWindowController?.id == closeResult.closedControllerID {
            activeWindowController = controller(for: closeResult.fallbackActiveControllerID)
        }

        Task { @MainActor in
            reconcileActiveWindowController()
        }
    }

    private func reconcileActiveWindowController() {
        if let keyWindow = NSApp.keyWindow,
           documentWindowActivity.controllerID(for: ObjectIdentifier(keyWindow)) != nil {
            noteDocumentWindowBecameActive(keyWindow)
            return
        }

        if let mainWindow = NSApp.mainWindow,
           documentWindowActivity.controllerID(for: ObjectIdentifier(mainWindow)) != nil {
            noteDocumentWindowBecameActive(mainWindow)
            return
        }

        if let activeControllerID = documentWindowActivity.activeControllerID,
           let controller = controller(for: activeControllerID) {
            activeWindowController = controller
            return
        }

        activeWindowController = nil
    }

    private func controller(for controllerID: UUID?) -> DocumentWindowController? {
        guard let controllerID else {
            return nil
        }
        return registeredWindowControllers[controllerID]
    }

    private func reloadUserPreviewThemes() {
        userPreviewThemes = userPreviewThemeStore.load()
    }

    private func setDefaultAndActivePreviewTheme(id: String) {
        updateSettings { settings in
            settings.defaultThemeID = id
        }
        setTheme(id: id)
    }

    private func presentThemeError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Theme Error"
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
