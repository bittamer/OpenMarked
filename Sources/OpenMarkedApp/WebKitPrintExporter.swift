import AppKit
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

    func exportPDF(html: String, baseURL: URL, destinationURL: URL, completion: @escaping (Result<Void, ExportError>) -> Void) {
        load(html: html, baseURL: baseURL, job: .pdf(destinationURL: destinationURL, completion: completion))
    }

    func print(html: String, baseURL: URL, completion: @escaping (Result<Void, ExportError>) -> Void) {
        load(html: html, baseURL: baseURL, job: .print(completion: completion))
    }

    private func load(html: String, baseURL: URL, job: Job) {
        self.job = job

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 612, height: 792), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
        completion: (Result<Void, ExportError>) -> Void
    ) {
        let printInfo = configuredPrintInfo()
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobDisposition] = NSPrintInfo.JobDisposition.save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = destinationURL

        let operation = webView.printOperation(with: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        if operation.run() {
            completion(.success(()))
        } else {
            completion(.failure(.pdfFailed(path: destinationURL.path, reason: "The print operation did not complete.")))
        }

        finish()
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
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 612, height: 792)
        printInfo.leftMargin = 54
        printInfo.rightMargin = 54
        printInfo.topMargin = 54
        printInfo.bottomMargin = 54
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        return printInfo
    }

    private func finishWithFailure(_ error: Error) {
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
    }
}
