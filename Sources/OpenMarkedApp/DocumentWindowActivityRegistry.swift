import Foundation

struct DocumentWindowActivityRegistry {
    struct CloseResult: Equatable {
        let closedControllerID: UUID
        let fallbackActiveControllerID: UUID?
    }

    private(set) var activeControllerID: UUID?
    private var controllerIDsByWindowID: [ObjectIdentifier: UUID] = [:]
    private var windowIDsByControllerID: [UUID: ObjectIdentifier] = [:]
    private var controllerOrder: [UUID] = []

    var isEmpty: Bool {
        controllerIDsByWindowID.isEmpty
    }

    var controllerIDsInActivityOrder: [UUID] {
        controllerOrder
    }

    mutating func register(controllerID: UUID, windowID: ObjectIdentifier) {
        if let previousControllerID = controllerIDsByWindowID[windowID],
           previousControllerID != controllerID {
            windowIDsByControllerID.removeValue(forKey: previousControllerID)
            removeFromOrder(previousControllerID)
            if activeControllerID == previousControllerID {
                activeControllerID = controllerOrder.last
            }
        }

        if let previousWindowID = windowIDsByControllerID[controllerID],
           previousWindowID != windowID {
            controllerIDsByWindowID.removeValue(forKey: previousWindowID)
        }

        controllerIDsByWindowID[windowID] = controllerID
        windowIDsByControllerID[controllerID] = windowID
        remember(controllerID)

        if activeControllerID == nil {
            activeControllerID = controllerID
            markRecentlyActive(controllerID)
        }
    }

    mutating func activate(windowID: ObjectIdentifier) -> UUID? {
        guard let controllerID = controllerIDsByWindowID[windowID] else {
            return nil
        }

        activeControllerID = controllerID
        markRecentlyActive(controllerID)
        return controllerID
    }

    mutating func close(windowID: ObjectIdentifier) -> CloseResult? {
        guard let controllerID = controllerIDsByWindowID.removeValue(forKey: windowID) else {
            return nil
        }

        windowIDsByControllerID.removeValue(forKey: controllerID)
        removeFromOrder(controllerID)

        if activeControllerID == controllerID {
            activeControllerID = controllerOrder.last
        }

        return CloseResult(
            closedControllerID: controllerID,
            fallbackActiveControllerID: activeControllerID
        )
    }

    func controllerID(for windowID: ObjectIdentifier) -> UUID? {
        controllerIDsByWindowID[windowID]
    }

    private mutating func remember(_ controllerID: UUID) {
        guard !controllerOrder.contains(controllerID) else {
            return
        }
        controllerOrder.append(controllerID)
    }

    private mutating func markRecentlyActive(_ controllerID: UUID) {
        removeFromOrder(controllerID)
        controllerOrder.append(controllerID)
    }

    private mutating func removeFromOrder(_ controllerID: UUID) {
        controllerOrder.removeAll { $0 == controllerID }
    }
}
