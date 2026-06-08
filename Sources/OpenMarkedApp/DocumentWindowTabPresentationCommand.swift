import AppKit

enum DocumentWindowTabPresentationCommand: String, CaseIterable, Identifiable {
    case showTabBar
    case showAllTabs

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .showTabBar:
            return "Show Tab Bar"
        case .showAllTabs:
            return "Show All Tabs"
        }
    }

    var selector: Selector {
        switch self {
        case .showTabBar:
            return #selector(NSWindow.toggleTabBar(_:))
        case .showAllTabs:
            return #selector(NSWindow.toggleTabOverview(_:))
        }
    }
}
