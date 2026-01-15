//
//  GoodreadsImportCoordinator.swift
//  Shlf
//
//  Automates Goodreads export flow
//

#if os(iOS) && !WIDGET_EXTENSION
import Combine
import Foundation
import WebKit

@MainActor
final class GoodreadsImportCoordinator: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForLogin
        case exporting
        case waitingForExport
        case downloading
        case finished
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var statusText: String = String(localized: "Loading Goodreads...")
    @Published var downloadedData: Data?
    @Published var errorMessage: String?

    let webView: WKWebView

    private var pollTimer: Timer?
    private var downloadURL: URL?

    private let exportPageURL = URL(string: "https://www.goodreads.com/review/import")!

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func start() {
        phase = .idle
        statusText = String(localized: "Loading Goodreads...")
        downloadedData = nil
        errorMessage = nil
        let request = URLRequest(url: exportPageURL)
        webView.load(request)
    }

    func disconnect() {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        webView.configuration.websiteDataStore.fetchDataRecords(ofTypes: types) { [weak self] records in
            self?.webView.configuration.websiteDataStore.removeData(ofTypes: types, for: records) {
                GoodreadsImportCoordinator.clearWebsiteData()
                self?.webView.load(URLRequest(url: self?.exportPageURL ?? URL(string: "https://www.goodreads.com")!))
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    static func clearWebsiteData(completion: (() -> Void)? = nil) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let store = WKWebsiteDataStore.default()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) {
                completion?()
            }
        }
    }

    private func handleExportPage() {
        let script = #"""
        (() => {
          const link = [...document.querySelectorAll('a')].find(a => {
            if (!a.href) return false;
            const href = a.href.toLowerCase();
            const text = (a.textContent || '').toLowerCase();
            return (href.includes('export') || href.includes('review/import')) && (href.includes('.csv') || text.includes('csv'));
          });
          if (link) { return link.href; }

          const exportButton = [...document.querySelectorAll('input[type="submit"], button')].find(el => {
            const text = ((el.value || '') + ' ' + (el.textContent || '')).toLowerCase();
            return text.includes('export');
          });
          if (exportButton) { exportButton.click(); return 'export_clicked'; }

          const bodyText = document.body ? document.body.innerText.toLowerCase() : '';
          if (bodyText.includes('export is in progress') || bodyText.includes('export in progress') || bodyText.includes('exporting')) {
            return 'export_pending';
          }
          if (bodyText.includes('captcha') || bodyText.includes('robot')) {
            return 'captcha';
          }
          return 'no_action';
        })();
        """#

        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self else { return }

            if let link = result as? String, link.hasPrefix("http"), let url = URL(string: link) {
                self.phase = .downloading
                self.statusText = String(localized: "Downloading CSV...")
                self.webView.load(URLRequest(url: url))
                return
            }

            if let resultString = result as? String {
                switch resultString {
                case "export_clicked":
                    self.phase = .waitingForExport
                    self.statusText = String(localized: "Export started. Waiting for file...")
                    self.startPolling()
                case "export_pending":
                    self.phase = .waitingForExport
                    self.statusText = String(localized: "Waiting for export to finish...")
                    self.startPolling()
                case "captcha":
                    self.fail(with: String(localized: "Goodreads blocked automated export. Please use manual CSV upload."))
                default:
                    self.fail(with: String(localized: "We couldn't find the Export Library page. Goodreads may have changed something."))
                }
            }
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.handleExportPage()
        }
    }

    private func fail(with message: String) {
        stop()
        phase = .failed(message)
        errorMessage = message
    }
}

extension GoodreadsImportCoordinator: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let path = url.path.lowercased()

        if path.contains("sign_in") || path.contains("signin") {
            phase = .waitingForLogin
            statusText = String(localized: "Sign in to Goodreads")
            return
        }

        if path.contains("/review/import") {
            phase = .exporting
            statusText = String(localized: "Preparing export...")
            handleExportPage()
        }
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
        phase = .downloading
        statusText = String(localized: "Downloading CSV...")
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
        phase = .downloading
        statusText = String(localized: "Downloading CSV...")
    }
}

extension GoodreadsImportCoordinator: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let filename = suggestedFilename.isEmpty ? "goodreads_library_export.csv" : suggestedFilename
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        downloadURL = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let downloadURL else {
            fail(with: String(localized: "Could not read CSV file."))
            return
        }

        do {
            let data = try Data(contentsOf: downloadURL)
            phase = .finished
            statusText = String(localized: "Export complete")
            downloadedData = data
            stop()
            Self.clearWebsiteData()
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        fail(with: error.localizedDescription)
    }
}
#endif
