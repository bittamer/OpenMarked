@testable import OpenMarkedApp
import Foundation

#if canImport(Testing)
import Testing

@Test("Loaded active window is preferred for external open")
func loadedActiveWindowIsPreferredForExternalOpen() {
    let loadedID = UUID()
    let emptyID = UUID()

    #expect(
        ExternalDocumentOpenPlanner.preferredWindow(
            activeWindow: descriptor(id: loadedID, canReplace: false, hasDocument: true),
            windowsInActivityOrder: [
                descriptor(id: emptyID, canReplace: true, hasDocument: false),
                descriptor(id: loadedID, canReplace: false, hasDocument: true)
            ]
        )?.id == loadedID
    )
}

@Test("Recent loaded window beats transient active empty window")
func recentLoadedWindowBeatsTransientActiveEmptyWindow() {
    let loadedID = UUID()
    let transientEmptyID = UUID()

    #expect(
        ExternalDocumentOpenPlanner.preferredWindow(
            activeWindow: descriptor(id: transientEmptyID, canReplace: true, hasDocument: false),
            windowsInActivityOrder: [
                descriptor(id: loadedID, canReplace: false, hasDocument: true),
                descriptor(id: transientEmptyID, canReplace: true, hasDocument: false)
            ]
        )?.id == loadedID
    )
}

@Test("Active empty window is used when no loaded window exists")
func activeEmptyWindowIsUsedWhenNoLoadedWindowExists() {
    let emptyID = UUID()

    #expect(
        ExternalDocumentOpenPlanner.preferredWindow(
            activeWindow: descriptor(id: emptyID, canReplace: true, hasDocument: false),
            windowsInActivityOrder: [descriptor(id: emptyID, canReplace: true, hasDocument: false)]
        )?.id == emptyID
    )
}

@Test("Only new empty windows are considered transient")
func onlyNewEmptyWindowsAreConsideredTransient() {
    let preservedEmptyID = UUID()
    let transientEmptyID = UUID()
    let loadedID = UUID()

    #expect(
        ExternalDocumentOpenPlanner.transientEmptyWindowIDs(
            windows: [
                descriptor(id: preservedEmptyID, canReplace: true, hasDocument: false),
                descriptor(id: transientEmptyID, canReplace: true, hasDocument: false),
                descriptor(id: loadedID, canReplace: false, hasDocument: true)
            ],
            preservedEmptyWindowIDs: [preservedEmptyID]
        ) == [transientEmptyID]
    )
}
#endif

private func descriptor(
    id: UUID,
    canReplace: Bool,
    hasDocument: Bool
) -> DocumentWindowDescriptor {
    DocumentWindowDescriptor(
        id: id,
        canReplaceWithOpenedDocument: canReplace,
        hasOpenedDocument: hasDocument
    )
}
