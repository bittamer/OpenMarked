import SwiftUI
import OpenMarkedCore

struct OpenMarkedCommands: Commands {
    @ObservedObject var appController: AppController

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppInfo.name)") {
                appController.showAboutPanel()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("Open...") {
                appController.presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Open in New Window...") {
                appController.presentOpenInNewWindowPanel()
            }
            .keyboardShortcut("o", modifiers: [.command, .option])
        }

        CommandGroup(after: .importExport) {
            Button("Export HTML...") {
                appController.exportHTML()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!appController.activeCanExport)

            Button("Export HTML Again") {
                appController.repeatHTMLExport()
            }
            .disabled(!appController.activeCanRepeatHTMLExport)

            Button("Copy Rendered HTML") {
                appController.copyRenderedHTML()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!appController.activeCanExport)

            Button("Export PDF...") {
                appController.exportPDF()
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            .disabled(!appController.activeCanExport)

            Button("Export PDF Again") {
                appController.repeatPDFExport()
            }
            .disabled(!appController.activeCanRepeatPDFExport)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print...") {
                appController.printDocument()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(!appController.activeCanExport)
        }

        CommandGroup(after: .toolbar) {
            Button("Reload Preview") {
                appController.reloadPreview()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!appController.activeCanReloadPreview)

            Button("Find...") {
                appController.showSearchPlaceholder()
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(!appController.activeHasDocument)

            Button("Find Next") {
                appController.findNext()
            }
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(!appController.activeHasDocument)

            Button("Find Previous") {
                appController.findPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(!appController.activeHasDocument)

            Divider()

            Button("Zoom In") {
                appController.zoomIn()
            }
            .keyboardShortcut("+", modifiers: [.command])

            Button("Zoom Out") {
                appController.zoomOut()
            }
            .keyboardShortcut("-", modifiers: [.command])

            Button("Actual Size") {
                appController.resetZoom()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])
        }

        CommandMenu("Theme") {
            ForEach(PreviewThemeStore.allBuiltInThemes) { theme in
                Button(theme.name) {
                    appController.setTheme(id: theme.id)
                }
            }

            if !appController.userPreviewThemes.isEmpty {
                Divider()

                ForEach(appController.userPreviewThemes) { theme in
                    Button(theme.name) {
                        appController.setTheme(id: theme.id)
                    }
                }
            }
        }

        CommandMenu("Source") {
            Button("Reveal in Finder") {
                appController.revealSourceInFinder()
            }
            .disabled(!appController.activeHasDocument)

            Button("Open in Default Editor") {
                appController.openSourceInDefaultEditor()
            }
            .disabled(!appController.activeHasDocument)

            Button("Copy File Path") {
                appController.copySourcePath()
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(!appController.activeHasDocument)

            Divider()

            Button("Reload from Disk") {
                appController.reloadPreview()
            }
            .disabled(!appController.activeCanReloadPreview)
        }

        CommandGroup(after: .sidebar) {
            Button("Toggle Outline") {
                appController.toggleOutline()
            }
            .keyboardShortcut("0", modifiers: [.command])

            Button(appController.activeIsInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                appController.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(!appController.activeHasWindow)

            Divider()

            ForEach(DocumentInspectorSection.allCases) { section in
                Button(section.title) {
                    appController.showInspector(section: section)
                }
                .disabled(!appController.activeHasDocument)
            }
        }

        CommandGroup(after: .windowArrangement) {
            Divider()

            Button(DocumentWindowTabCommand.showTabBar.title) {
                appController.performDocumentWindowTabCommand(.showTabBar)
            }
            .disabled(!appController.activeHasDocumentWindow)

            Button(DocumentWindowTabCommand.showAllTabs.title) {
                appController.performDocumentWindowTabCommand(.showAllTabs)
            }
            .disabled(!appController.activeHasDocumentWindow)

            Button(DocumentWindowTabCommand.mergeAllWindows.title) {
                appController.performDocumentWindowTabCommand(.mergeAllWindows)
            }
            .disabled(!appController.activeHasDocumentWindow)

            Button(DocumentWindowTabCommand.moveTabToNewWindow.title) {
                appController.performDocumentWindowTabCommand(.moveTabToNewWindow)
            }
            .disabled(!appController.activeHasDocumentWindow)

            Divider()

            Button(DocumentWindowTabCommand.selectNextTab.title) {
                appController.performDocumentWindowTabCommand(.selectNextTab)
            }
            .keyboardShortcut(.tab, modifiers: [.control])
            .disabled(!appController.activeHasDocumentWindow)

            Button(DocumentWindowTabCommand.selectPreviousTab.title) {
                appController.performDocumentWindowTabCommand(.selectPreviousTab)
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])
            .disabled(!appController.activeHasDocumentWindow)
        }

        CommandGroup(replacing: .help) {
            Button("OpenMarked Help") {
                appController.showHelpPlaceholder()
            }
        }
    }
}
