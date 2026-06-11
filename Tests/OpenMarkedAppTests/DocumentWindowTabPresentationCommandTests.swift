@testable import OpenMarkedApp
import AppKit

#if canImport(Testing)
import Testing

@Test("Document window tab presentation commands use native window selectors")
func documentWindowTabPresentationCommandsUseNativeWindowSelectors() {
    for command in DocumentWindowTabPresentationCommand.allCases {
        #expect(NSWindow.instancesRespond(to: command.selector))
    }
}
#endif
