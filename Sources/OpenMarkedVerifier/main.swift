import Foundation
import OpenMarkedCore

func verify(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data("Verification failed: \(message)\n".utf8))
        exit(1)
    }
}

verify(AppInfo.supportsFileExtension("md"), "md should be supported")
verify(AppInfo.supportsFileExtension("MARKDOWN"), "MARKDOWN should be supported case-insensitively")
verify(AppInfo.supportsFileExtension("txt"), "txt should be supported")
verify(!AppInfo.supportsFileExtension("pdf"), "pdf should not be supported in the MVP skeleton")
verify(!AppInfo.supportsFileExtension("docx"), "docx should not be supported in the MVP skeleton")
verify(AppInfo.version == "0.1.0-alpha.1", "version should be 0.1.0-alpha.1")

var state = DocumentWindowState()
verify(!state.hasDocument, "new window state should not have a document")
verify(state.windowTitle == AppInfo.name, "empty window should use app title")

let fixtureURL = URL(fileURLWithPath: "Fixtures/Markdown/readme.md").standardizedFileURL
state.beginOpening(url: fixtureURL)
verify(state.preview == .loading, "beginOpening should put preview into loading state")

let document = try DocumentOpenValidator.validate(url: fixtureURL, openedAt: Date(timeIntervalSince1970: 0))
state.finishOpening(document: document)
verify(state.hasDocument, "loaded window state should have a document")
verify(state.windowTitle == "readme.md", "loaded window should use document title")
verify(state.canReloadPreview, "loaded window should be reloadable")
verify(state.canExport, "loaded window should be exportable")

state.toggleOutline()
verify(!state.layout.isOutlineVisible, "toggleOutline should hide the outline")
state.zoomIn()
verify(state.layout.fontScale > 1.0, "zoomIn should increase font scale")
state.resetZoom()
verify(state.layout.fontScale == 1.0, "resetZoom should restore default font scale")

do {
    _ = try DocumentOpenValidator.validate(url: URL(fileURLWithPath: "Package.swift"))
    verify(false, "Package.swift should not be accepted as a Markdown file")
} catch let error as DocumentOpenError {
    verify(error.kind == .unsupportedFileType, "unsupported files should produce unsupportedFileType")
}

print("OpenMarked Phase 1 verifier passed.")
