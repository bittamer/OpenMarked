@testable import OpenMarkedApp
import AppKit

#if canImport(XCTest)
import XCTest

final class DocumentWindowTabCommandTests: XCTestCase {
    func testCommandsUseNativeWindowSelectors() {
        for command in DocumentWindowTabCommand.allCases {
            XCTAssertTrue(
                NSWindow.instancesRespond(to: command.selector),
                "\(command.title) should map to a native NSWindow selector."
            )
        }
    }

    func testCommandTitlesAreUserFacingWindowMenuTitles() {
        XCTAssertEqual(DocumentWindowTabCommand.showTabBar.title, "Show Tab Bar")
        XCTAssertEqual(DocumentWindowTabCommand.showAllTabs.title, "Show All Tabs")
        XCTAssertEqual(DocumentWindowTabCommand.mergeAllWindows.title, "Merge All Windows")
        XCTAssertEqual(DocumentWindowTabCommand.moveTabToNewWindow.title, "Move Tab to New Window")
        XCTAssertEqual(DocumentWindowTabCommand.selectNextTab.title, "Select Next Tab")
        XCTAssertEqual(DocumentWindowTabCommand.selectPreviousTab.title, "Select Previous Tab")
    }
}
#endif

#if canImport(Testing)
import Testing

@Test("Document window tab commands use native window selectors")
func documentWindowTabCommandsUseNativeWindowSelectors() {
    for command in DocumentWindowTabCommand.allCases {
        #expect(NSWindow.instancesRespond(to: command.selector))
    }
}

@Test("Document window tab commands expose expected menu titles")
func documentWindowTabCommandsExposeExpectedMenuTitles() {
    #expect(DocumentWindowTabCommand.showTabBar.title == "Show Tab Bar")
    #expect(DocumentWindowTabCommand.showAllTabs.title == "Show All Tabs")
    #expect(DocumentWindowTabCommand.mergeAllWindows.title == "Merge All Windows")
    #expect(DocumentWindowTabCommand.moveTabToNewWindow.title == "Move Tab to New Window")
    #expect(DocumentWindowTabCommand.selectNextTab.title == "Select Next Tab")
    #expect(DocumentWindowTabCommand.selectPreviousTab.title == "Select Previous Tab")
}
#endif
