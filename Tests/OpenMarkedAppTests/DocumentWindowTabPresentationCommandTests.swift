@testable import OpenMarkedApp
import AppKit

#if canImport(XCTest)
import XCTest

final class DocumentWindowTabPresentationCommandTests: XCTestCase {
    func testCommandsUseNativeWindowSelectors() {
        for command in DocumentWindowTabPresentationCommand.allCases {
            XCTAssertTrue(
                NSWindow.instancesRespond(to: command.selector),
                "\(command.title) should map to a native NSWindow selector."
            )
        }
    }
}
#endif

#if canImport(Testing)
import Testing

@Test("Document window tab presentation commands use native window selectors")
func documentWindowTabPresentationCommandsUseNativeWindowSelectors() {
    for command in DocumentWindowTabPresentationCommand.allCases {
        #expect(NSWindow.instancesRespond(to: command.selector))
    }
}
#endif
