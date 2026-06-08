@testable import OpenMarkedApp
import Foundation

#if canImport(XCTest)
import XCTest

final class SessionRestorationPlannerTests: XCTestCase {
    func testDisabledRestoreReturnsEmptyPlan() {
        let url = URL(fileURLWithPath: "/tmp/readme.md")

        let plan = SessionRestorationPlanner.plan(
            isEnabled: false,
            savedURLs: [url],
            fileExists: { _ in true }
        )

        XCTAssertFalse(plan.shouldRestore)
        XCTAssertEqual(plan.urls, [])
    }

    func testRestoreFiltersMissingAndUnsupportedURLs() {
        let readme = URL(fileURLWithPath: "/tmp/readme.md")
        let missing = URL(fileURLWithPath: "/tmp/missing.md")
        let unsupported = URL(fileURLWithPath: "/tmp/notes.pdf")

        let plan = SessionRestorationPlanner.plan(
            isEnabled: true,
            savedURLs: [readme, missing, unsupported],
            fileExists: { $0 == readme || $0 == unsupported }
        )

        XCTAssertTrue(plan.shouldRestore)
        XCTAssertEqual(plan.urls, [readme])
    }

    func testRestorePreservesSavedURLOrderAndDuplicates() {
        let first = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.markdown")

        let plan = SessionRestorationPlanner.plan(
            isEnabled: true,
            savedURLs: [first, second, first],
            fileExists: { _ in true }
        )

        XCTAssertEqual(plan.urls, [first, second, first])
    }
}
#endif

#if canImport(Testing)
import Testing

@Test("Disabled session restore returns an empty plan")
func disabledSessionRestoreReturnsEmptyPlan() {
    let url = URL(fileURLWithPath: "/tmp/readme.md")

    let plan = SessionRestorationPlanner.plan(
        isEnabled: false,
        savedURLs: [url],
        fileExists: { _ in true }
    )

    #expect(!plan.shouldRestore)
    #expect(plan.urls == [])
}

@Test("Session restore filters missing and unsupported URLs")
func sessionRestoreFiltersMissingAndUnsupportedURLs() {
    let readme = URL(fileURLWithPath: "/tmp/readme.md")
    let missing = URL(fileURLWithPath: "/tmp/missing.md")
    let unsupported = URL(fileURLWithPath: "/tmp/notes.pdf")

    let plan = SessionRestorationPlanner.plan(
        isEnabled: true,
        savedURLs: [readme, missing, unsupported],
        fileExists: { $0 == readme || $0 == unsupported }
    )

    #expect(plan.shouldRestore)
    #expect(plan.urls == [readme])
}

@Test("Session restore preserves saved URL order and duplicates")
func sessionRestorePreservesSavedURLOrderAndDuplicates() {
    let first = URL(fileURLWithPath: "/tmp/first.md")
    let second = URL(fileURLWithPath: "/tmp/second.markdown")

    let plan = SessionRestorationPlanner.plan(
        isEnabled: true,
        savedURLs: [first, second, first],
        fileExists: { _ in true }
    )

    #expect(plan.urls == [first, second, first])
}
#endif
