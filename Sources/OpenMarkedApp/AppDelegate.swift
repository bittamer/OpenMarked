import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            AppController.shared.restoreLastSessionIfNeeded()
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        AppController.shared.openURLs([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppController.shared.openURLs(urls)
    }
}
