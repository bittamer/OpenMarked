@testable import OpenMarkedApp
import Foundation

#if canImport(Testing)
import Testing

@Test("First registered window becomes active")
func firstRegisteredWindowBecomesActive() {
    var registry = DocumentWindowActivityRegistry()
    let controllerID = UUID()
    let window = NSObject()

    registry.register(controllerID: controllerID, windowID: ObjectIdentifier(window))

    #expect(registry.activeControllerID == controllerID)
}

@Test("Activating a registered window updates active controller")
func activatingRegisteredWindowUpdatesActiveController() {
    var registry = DocumentWindowActivityRegistry()
    let firstControllerID = UUID()
    let secondControllerID = UUID()
    let firstWindow = NSObject()
    let secondWindow = NSObject()

    registry.register(controllerID: firstControllerID, windowID: ObjectIdentifier(firstWindow))
    registry.register(controllerID: secondControllerID, windowID: ObjectIdentifier(secondWindow))
    registry.activate(windowID: ObjectIdentifier(secondWindow))

    #expect(registry.activeControllerID == secondControllerID)
}

@Test("Activity order tracks recent activation")
func activityOrderTracksRecentActivation() {
    var registry = DocumentWindowActivityRegistry()
    let firstControllerID = UUID()
    let secondControllerID = UUID()
    let firstWindow = NSObject()
    let secondWindow = NSObject()

    registry.register(controllerID: firstControllerID, windowID: ObjectIdentifier(firstWindow))
    registry.register(controllerID: secondControllerID, windowID: ObjectIdentifier(secondWindow))
    registry.activate(windowID: ObjectIdentifier(firstWindow))

    #expect(registry.controllerIDsInActivityOrder == [secondControllerID, firstControllerID])
}

@Test("Closing active window falls back to previous controller")
func closingActiveWindowFallsBackToPreviousController() {
    var registry = DocumentWindowActivityRegistry()
    let firstControllerID = UUID()
    let secondControllerID = UUID()
    let firstWindow = NSObject()
    let secondWindow = NSObject()

    registry.register(controllerID: firstControllerID, windowID: ObjectIdentifier(firstWindow))
    registry.register(controllerID: secondControllerID, windowID: ObjectIdentifier(secondWindow))
    registry.activate(windowID: ObjectIdentifier(secondWindow))
    let closeResult = registry.close(windowID: ObjectIdentifier(secondWindow))

    #expect(closeResult?.closedControllerID == secondControllerID)
    #expect(closeResult?.fallbackActiveControllerID == firstControllerID)
    #expect(registry.activeControllerID == firstControllerID)
}

@Test("Closing inactive window preserves active controller")
func closingInactiveWindowPreservesActiveController() {
    var registry = DocumentWindowActivityRegistry()
    let firstControllerID = UUID()
    let secondControllerID = UUID()
    let firstWindow = NSObject()
    let secondWindow = NSObject()

    registry.register(controllerID: firstControllerID, windowID: ObjectIdentifier(firstWindow))
    registry.register(controllerID: secondControllerID, windowID: ObjectIdentifier(secondWindow))
    let closeResult = registry.close(windowID: ObjectIdentifier(secondWindow))

    #expect(closeResult?.closedControllerID == secondControllerID)
    #expect(closeResult?.fallbackActiveControllerID == firstControllerID)
    #expect(registry.activeControllerID == firstControllerID)
}
#endif
