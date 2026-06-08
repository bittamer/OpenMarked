import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        DocumentWindowTabbing.enableAutomaticWindowTabbing()
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        if let icon = OpenMarkedAppIcon.image() {
            NSApplication.shared.applicationIconImage = icon
        }
        NSApplication.shared.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            AppController.shared.restoreLastSessionIfNeeded()
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        AppController.shared.openURLsFromExternalEvent([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppController.shared.openURLsFromExternalEvent(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        !flag
    }
}
