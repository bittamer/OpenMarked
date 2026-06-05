import SwiftUI
import OpenMarkedCore

@main
struct OpenMarkedApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appController = AppController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appController)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            OpenMarkedCommands(appController: appController)
        }

        Settings {
            SettingsView()
                .environmentObject(appController)
                .appChromeTheme(appController.settings.appChromeThemeID)
        }
    }
}
