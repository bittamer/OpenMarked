@testable import OpenMarkedApp
import Foundation

#if canImport(Testing)
import Testing

@MainActor
@Test("Rapid opens publish only the newest loaded document")
func rapidOpensPublishOnlyNewestLoadedDocument() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("OpenMarkedBackgroundTaskTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let firstURL = directory.appendingPathComponent("first.md")
    let secondURL = directory.appendingPathComponent("second.md")
    try "# First\n\nThis document should be superseded.\n".write(to: firstURL, atomically: true, encoding: .utf8)
    try "# Second\n\nThis document should win.\n".write(to: secondURL, atomically: true, encoding: .utf8)

    let controller = DocumentWindowController()
    controller.open(url: firstURL)
    controller.open(url: secondURL)

    try await waitForController(controller) {
        controller.state.currentMarkdownDocument?.sourceURL.standardizedFileURL == secondURL.standardizedFileURL
            && controller.state.currentRenderResult != nil
    }

    #expect(controller.state.currentMarkdownDocument?.sourceURL.standardizedFileURL == secondURL.standardizedFileURL)
    #expect(controller.state.currentRenderResult?.bodyHTML.contains("Second") == true)

    controller.close()
}

private func waitForController(
    _ controller: DocumentWindowController,
    _ predicate: @escaping @MainActor () -> Bool
) async throws {
    for _ in 0..<120 {
        if await predicate() {
            return
        }
        try await Task.sleep(nanoseconds: 50_000_000)
    }

    Issue.record("Timed out waiting for controller state")
}
#endif
