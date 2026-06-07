import AppKit
import PDFKit
import WebKit
import OpenMarkedCore

@MainActor
final class WebKitPrintExporter: NSObject, WKNavigationDelegate {
    enum Job {
        case pdf(destinationURL: URL, completion: (Result<Void, ExportError>) -> Void)
        case print(completion: (Result<Void, ExportError>) -> Void)
    }

    private var webView: WKWebView?
    private var job: Job?
    private var richMarkdownState: RichMarkdownRenderState = .empty
    private var printConfiguration: PrintConfiguration = .default
    private var isFinishingJob = false

    func exportPDF(
        html: String,
        baseURL: URL,
        richMarkdownState: RichMarkdownRenderState = .empty,
        printConfiguration: PrintConfiguration = .default,
        destinationURL: URL,
        completion: @escaping (Result<Void, ExportError>) -> Void
    ) {
        load(
            html: html,
            baseURL: baseURL,
            richMarkdownState: richMarkdownState,
            printConfiguration: printConfiguration,
            job: .pdf(destinationURL: destinationURL, completion: completion)
        )
    }

    func print(
        html: String,
        baseURL: URL,
        richMarkdownState: RichMarkdownRenderState = .empty,
        printConfiguration: PrintConfiguration = .default,
        completion: @escaping (Result<Void, ExportError>) -> Void
    ) {
        load(
            html: html,
            baseURL: baseURL,
            richMarkdownState: richMarkdownState,
            printConfiguration: printConfiguration,
            job: .print(completion: completion)
        )
    }

    private func load(
        html: String,
        baseURL: URL,
        richMarkdownState: RichMarkdownRenderState,
        printConfiguration: PrintConfiguration,
        job: Job
    ) {
        self.job = job
        self.richMarkdownState = richMarkdownState
        self.printConfiguration = printConfiguration.normalized()
        isFinishingJob = false

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = richMarkdownState.requiresRichContentRuntime
        let paperSize = self.printConfiguration.pageSize.paperSizePoints

        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: paperSize.width, height: paperSize.height),
            configuration: configuration
        )
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard richMarkdownState.requiresRichContentRuntime else {
            finishLoadedJob(webView)
            return
        }

        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else {
                return
            }

            do {
                let status = try await RichContentWebViewRuntime.installAndWait(for: self.richMarkdownState, in: webView)
                if status.hasFailure {
                    self.finishWithFailure(RichContentExportRuntimeError(message: status.userMessage))
                    return
                }

                self.finishLoadedJob(webView)
            } catch {
                self.finishWithFailure(error)
            }
        }
    }

    private func finishLoadedJob(_ webView: WKWebView) {
        switch job {
        case .pdf(let destinationURL, let completion):
            runPDFExport(webView: webView, destinationURL: destinationURL, completion: completion)
        case .print(let completion):
            runPrint(webView: webView, completion: completion)
        case nil:
            break
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishWithFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishWithFailure(error)
    }

    private func runPDFExport(
        webView: WKWebView,
        destinationURL: URL,
        completion: @escaping (Result<Void, ExportError>) -> Void
    ) {
        guard !isFinishingJob else {
            return
        }
        isFinishingJob = true

        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else {
                return
            }

            do {
                let data = try await self.pdfData(from: webView)
                try self.writePDFData(data, to: destinationURL)
                completion(.success(()))
            } catch let error as ExportError {
                completion(.failure(error))
            } catch {
                completion(.failure(.pdfFailed(path: destinationURL.path, reason: error.localizedDescription)))
            }

            self.finish()
        }
    }

    private func runPrint(webView: WKWebView, completion: (Result<Void, ExportError>) -> Void) {
        let operation = webView.printOperation(with: configuredPrintInfo())
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true

        if operation.run() {
            completion(.success(()))
        } else {
            completion(.failure(.printFailed(reason: "The print operation was cancelled or did not complete.")))
        }

        finish()
    }

    private func configuredPrintInfo() -> NSPrintInfo {
        let normalized = printConfiguration.normalized()
        let paperSize = normalized.pageSize.paperSizePoints
        let margins = normalized.margins
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: paperSize.width, height: paperSize.height)
        printInfo.leftMargin = margins.leftPoints
        printInfo.rightMargin = margins.rightPoints
        printInfo.topMargin = margins.topPoints
        printInfo.bottomMargin = margins.bottomPoints
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        return printInfo
    }

    private func pdfData(from webView: WKWebView) async throws -> Data {
        let pageRect = CGRect(origin: .zero, size: webView.bounds.size)
        let contentHeight = try await measuredContentHeight(in: webView)
        let pageCount = max(1, Int(ceil(contentHeight / pageRect.height)))
        let document = PDFDocument()

        for pageIndex in 0..<pageCount {
            let pageY = CGFloat(pageIndex) * pageRect.height
            let remainingHeight = max(1, contentHeight - pageY)
            let pageHeight = min(pageRect.height, remainingHeight)
            let configuration = WKPDFConfiguration()
            configuration.rect = CGRect(
                x: pageRect.minX,
                y: pageY,
                width: pageRect.width,
                height: pageHeight
            )
            let pageData = try await createPDFData(in: webView, configuration: configuration)
            guard let pageDocument = PDFDocument(data: pageData), pageDocument.pageCount > 0 else {
                throw PDFExportDataError.unreadablePage
            }

            for sourcePageIndex in 0..<pageDocument.pageCount {
                guard let page = pageDocument.page(at: sourcePageIndex) else {
                    continue
                }
                document.insert(page, at: document.pageCount)
            }
        }

        guard let data = document.dataRepresentation(), data.isOpenMarkedPDFData else {
            throw PDFExportDataError.unreadableDocument
        }

        return data
    }

    private func measuredContentHeight(in webView: WKWebView) async throws -> CGFloat {
        let script = """
        Math.max(
          document.body ? document.body.scrollHeight : 0,
          document.body ? document.body.offsetHeight : 0,
          document.documentElement ? document.documentElement.clientHeight : 0,
          document.documentElement ? document.documentElement.scrollHeight : 0,
          document.documentElement ? document.documentElement.offsetHeight : 0
        );
        """
        let result = try await webView.evaluateJavaScript(script)
        let measuredHeight: Double
        if let number = result as? NSNumber {
            measuredHeight = number.doubleValue
        } else if let value = result as? Double {
            measuredHeight = value
        } else {
            measuredHeight = Double(webView.bounds.height)
        }

        return max(webView.bounds.height, CGFloat(measuredHeight.rounded(.up)))
    }

    private func createPDFData(in webView: WKWebView, configuration: WKPDFConfiguration) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: configuration) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func writePDFData(_ data: Data, to destinationURL: URL) throws {
        guard data.isOpenMarkedPDFData else {
            throw ExportError.pdfFailed(path: destinationURL.path, reason: "The generated file was not valid PDF data.")
        }

        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            throw ExportError.pdfFailed(path: destinationURL.path, reason: error.localizedDescription)
        }

        guard
            let writtenData = try? Data(contentsOf: destinationURL),
            writtenData.isOpenMarkedPDFData,
            PDFDocument(data: writtenData)?.pageCount ?? 0 > 0
        else {
            throw ExportError.pdfFailed(path: destinationURL.path, reason: "The generated file could not be reopened as a PDF.")
        }
    }

    private func finishWithFailure(_ error: Error) {
        guard !isFinishingJob else {
            return
        }
        isFinishingJob = true

        switch job {
        case .pdf(let destinationURL, let completion):
            completion(.failure(.pdfFailed(path: destinationURL.path, reason: error.localizedDescription)))
        case .print(let completion):
            completion(.failure(.printFailed(reason: error.localizedDescription)))
        case nil:
            break
        }
        finish()
    }

    private func finish() {
        webView?.navigationDelegate = nil
        webView = nil
        job = nil
        richMarkdownState = .empty
        printConfiguration = .default
        isFinishingJob = false
    }
}

private extension Data {
    var isOpenMarkedPDFData: Bool {
        guard count >= 8 else {
            return false
        }

        return starts(with: Data("%PDF-".utf8)) && suffix(1024).contains(Data("%%EOF".utf8))
    }
}

private enum PDFExportDataError: Error, LocalizedError {
    case unreadablePage
    case unreadableDocument

    var errorDescription: String? {
        switch self {
        case .unreadablePage:
            return "WebKit produced an unreadable PDF page."
        case .unreadableDocument:
            return "WebKit produced unreadable PDF data."
        }
    }
}

private struct RichContentExportRuntimeError: Error, LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
