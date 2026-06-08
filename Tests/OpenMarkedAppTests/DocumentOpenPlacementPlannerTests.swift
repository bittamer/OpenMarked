@testable import OpenMarkedApp
import Foundation

#if canImport(XCTest)
import XCTest

final class DocumentOpenPlacementPlannerTests: XCTestCase {
    func testEmptyDocumentListHasNoPlacements() {
        XCTAssertEqual(
            DocumentOpenPlacementPlanner.plan(
                documentCount: 0,
                preferredWindow: nil,
                activeWindow: nil
            ),
            []
        )
    }

    func testEmptyActiveWindowIsReplacedForSingleDocument() {
        let activeID = UUID()

        XCTAssertEqual(
            DocumentOpenPlacementPlanner.plan(
                documentCount: 1,
                preferredWindow: nil,
                activeWindow: descriptor(id: activeID, canReplace: true)
            ),
            [.replace(activeID)]
        )
    }

    func testEmptyActiveWindowIsReplacedThenUsedAsTabAnchor() {
        let activeID = UUID()

        XCTAssertEqual(
            DocumentOpenPlacementPlanner.plan(
                documentCount: 3,
                preferredWindow: nil,
                activeWindow: descriptor(id: activeID, canReplace: true)
            ),
            [
                .replace(activeID),
                .newTab(anchor: .existing(activeID)),
                .newTab(anchor: .existing(activeID))
            ]
        )
    }

    func testLoadedActiveWindowReceivesNewTabs() {
        let activeID = UUID()

        XCTAssertEqual(
            DocumentOpenPlacementPlanner.plan(
                documentCount: 2,
                preferredWindow: nil,
                activeWindow: descriptor(id: activeID, canReplace: false)
            ),
            [
                .newTab(anchor: .existing(activeID)),
                .newTab(anchor: .existing(activeID))
            ]
        )
    }

    func testNoWindowCreatesStandaloneThenTabsAgainstFirstOpenedWindow() {
        XCTAssertEqual(
            DocumentOpenPlacementPlanner.plan(
                documentCount: 3,
                preferredWindow: nil,
                activeWindow: nil
            ),
            [
                .newStandaloneWindow,
                .newTab(anchor: .firstOpenedWindow),
                .newTab(anchor: .firstOpenedWindow)
            ]
        )
    }

    func testPreferredWindowOverridesActiveWindowForDropTargets() {
        let preferredID = UUID()
        let activeID = UUID()

        XCTAssertEqual(
            DocumentOpenPlacementPlanner.plan(
                documentCount: 1,
                preferredWindow: descriptor(id: preferredID, canReplace: false),
                activeWindow: descriptor(id: activeID, canReplace: true)
            ),
            [.newTab(anchor: .existing(preferredID))]
        )
    }
}
#endif

#if canImport(Testing)
import Testing

@Test("Empty document list has no open placements")
func emptyDocumentListHasNoOpenPlacements() {
    #expect(
        DocumentOpenPlacementPlanner.plan(
            documentCount: 0,
            preferredWindow: nil,
            activeWindow: nil
        ) == []
    )
}

@Test("Empty active window is replaced for a single document")
func emptyActiveWindowIsReplacedForSingleDocument() {
    let activeID = UUID()

    #expect(
        DocumentOpenPlacementPlanner.plan(
            documentCount: 1,
            preferredWindow: nil,
            activeWindow: descriptor(id: activeID, canReplace: true)
        ) == [.replace(activeID)]
    )
}

@Test("Empty active window is replaced, then anchors later tabs")
func emptyActiveWindowIsReplacedThenAnchorsLaterTabs() {
    let activeID = UUID()

    #expect(
        DocumentOpenPlacementPlanner.plan(
            documentCount: 3,
            preferredWindow: nil,
            activeWindow: descriptor(id: activeID, canReplace: true)
        ) == [
            .replace(activeID),
            .newTab(anchor: .existing(activeID)),
            .newTab(anchor: .existing(activeID))
        ]
    )
}

@Test("Loaded active window receives new tabs")
func loadedActiveWindowReceivesNewTabs() {
    let activeID = UUID()

    #expect(
        DocumentOpenPlacementPlanner.plan(
            documentCount: 2,
            preferredWindow: nil,
            activeWindow: descriptor(id: activeID, canReplace: false)
        ) == [
            .newTab(anchor: .existing(activeID)),
            .newTab(anchor: .existing(activeID))
        ]
    )
}

@Test("No window creates standalone first, then tabs against it")
func noWindowCreatesStandaloneThenTabsAgainstIt() {
    #expect(
        DocumentOpenPlacementPlanner.plan(
            documentCount: 3,
            preferredWindow: nil,
            activeWindow: nil
        ) == [
            .newStandaloneWindow,
            .newTab(anchor: .firstOpenedWindow),
            .newTab(anchor: .firstOpenedWindow)
        ]
    )
}

@Test("Preferred window overrides active window for drop target routing")
func preferredWindowOverridesActiveWindowForDropTargetRouting() {
    let preferredID = UUID()
    let activeID = UUID()

    #expect(
        DocumentOpenPlacementPlanner.plan(
            documentCount: 1,
            preferredWindow: descriptor(id: preferredID, canReplace: false),
            activeWindow: descriptor(id: activeID, canReplace: true)
        ) == [.newTab(anchor: .existing(preferredID))]
    )
}
#endif

private func descriptor(id: UUID, canReplace: Bool) -> DocumentWindowDescriptor {
    DocumentWindowDescriptor(id: id, canReplaceWithOpenedDocument: canReplace)
}
