@testable import OpenMarkedApp
@testable import OpenMarkedCore
import Foundation

#if canImport(PDFKit) && canImport(WebKit)
import PDFKit

#if canImport(Testing)
import Testing

@Test("PDF export writes a readable PDF file")
@MainActor
func pdfExportWritesReadablePDFFile() async throws {
    let smokeResult = try await makePDFExportSmokeResult()
    #expect(smokeResult.data.starts(with: Data("%PDF-".utf8)))
    #expect(smokeResult.hasTrailingEOFMarker)
    #expect(smokeResult.pageCount > 0)
}
#endif

private struct PDFExportSmokeResult {
    let data: Data
    let hasTrailingEOFMarker: Bool
    let pageCount: Int
}

@MainActor
private func makePDFExportSmokeResult() async throws -> PDFExportSmokeResult {
    let destinationURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("openmarked-pdf-export-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: destinationURL) }

    let html = HTMLDocumentAssembler.assemble(
        title: "PDF Export Smoke",
        bodyHTML: """
        <h1>PDF Export Smoke</h1>
        <p>This document verifies that the app-facing WebKit PDF exporter writes valid PDF data.</p>
        <h2>Second Section</h2>
        <p>OpenMarked should complete the export and release the offscreen WebView after writing.</p>
        """,
        printConfiguration: PrintConfiguration(
            pageSize: .letter,
            margins: PrintMargins(top: 0.5, right: 0.5, bottom: 0.5, left: 0.5),
            includesDocumentTitle: true
        )
    )

    let exporter = WebKitPrintExporter()
    let result = await withCheckedContinuation { continuation in
        exporter.exportPDF(
            html: html,
            baseURL: FileManager.default.temporaryDirectory,
            destinationURL: destinationURL
        ) { result in
            continuation.resume(returning: result)
        }
    }

    switch result {
    case .success:
        break
    case .failure(let error):
        throw PDFExportSmokeError.exportFailed(error.localizedDescription)
    }

    let data = try Data(contentsOf: destinationURL)
    let trailingRange = data.index(data.endIndex, offsetBy: -min(data.count, 1024))..<data.endIndex
    guard let document = PDFDocument(data: data) else {
        throw PDFExportSmokeError.unreadablePDF
    }

    return PDFExportSmokeResult(
        data: data,
        hasTrailingEOFMarker: data.range(of: Data("%%EOF".utf8), options: [], in: trailingRange) != nil,
        pageCount: document.pageCount
    )
}

private enum PDFExportSmokeError: Error, LocalizedError {
    case exportFailed(String)
    case unreadablePDF

    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return message
        case .unreadablePDF:
            return "The generated PDF could not be reopened by PDFKit."
        }
    }
}
#endif
