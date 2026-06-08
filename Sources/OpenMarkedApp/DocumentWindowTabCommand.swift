import AppKit

enum DocumentWindowTabCommand: String, CaseIterable, Identifiable {
    case showTabBar
    case showAllTabs
    case mergeAllWindows
    case moveTabToNewWindow
    case selectNextTab
    case selectPreviousTab

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .showTabBar:
            return "Show Tab Bar"
        case .showAllTabs:
            return "Show All Tabs"
        case .mergeAllWindows:
            return "Merge All Windows"
        case .moveTabToNewWindow:
            return "Move Tab to New Window"
        case .selectNextTab:
            return "Select Next Tab"
        case .selectPreviousTab:
            return "Select Previous Tab"
        }
    }

    var selector: Selector {
        switch self {
        case .showTabBar:
            return #selector(NSWindow.toggleTabBar(_:))
        case .showAllTabs:
            return #selector(NSWindow.toggleTabOverview(_:))
        case .mergeAllWindows:
            return #selector(NSWindow.mergeAllWindows(_:))
        case .moveTabToNewWindow:
            return #selector(NSWindow.moveTabToNewWindow(_:))
        case .selectNextTab:
            return #selector(NSWindow.selectNextTab(_:))
        case .selectPreviousTab:
            return #selector(NSWindow.selectPreviousTab(_:))
        }
    }
}
