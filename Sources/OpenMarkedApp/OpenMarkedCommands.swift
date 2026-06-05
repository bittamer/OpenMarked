import SwiftUI

struct OpenMarkedCommands: Commands {
    @ObservedObject var appController: AppController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open...") {
                appController.presentOpenPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }

        CommandGroup(after: .importExport) {
            Button("Export HTML...") {
                appController.exportHTML()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!appController.activeCanExport)

            Button("Export PDF...") {
                appController.exportPDF()
            }
            .keyboardShortcut("e", modifiers: [.command, .option])
            .disabled(!appController.activeCanExport)
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

        CommandGroup(after: .sidebar) {
            Button("Toggle Outline") {
                appController.toggleOutline()
            }
            .keyboardShortcut("0", modifiers: [.command])
        }

        CommandGroup(replacing: .help) {
            Button("OpenMarked Help") {
                appController.showHelpPlaceholder()
            }
        }
    }
}

