//
//  GoodreadsImportCoordinator.swift
//  Shlf
//
//  Automates Goodreads export flow
//

#if os(iOS) && !WIDGET_EXTENSION
import Combine
import Foundation
import SwiftUI
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
    @Published var statusText: LocalizedStringKey = "Loading Goodreads..."
    @Published var downloadedData: Data?
    @Published var errorMessage: String?
    @Published var isConnected: Bool = false
    @Published var requiresLogin: Bool = false

    let webView: WKWebView

    private var pollTimer: Timer?
    private var downloadURL: URL?
    private var didRequestExport = false
    private var didAutoClickExport = false
    private var exportPollCount = 0
    private var isSyncOnly = false

    private let signInURL = URL(string: "https://www.goodreads.com/user/sign_in")!
    private let exportPageURL = URL(string: "https://www.goodreads.com/review/import")!

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func start(syncOnly: Bool = false) {
        isSyncOnly = syncOnly
        requiresLogin = false
        phase = .idle
        statusText = "Loading Goodreads..."
        downloadedData = nil
        errorMessage = nil
        didRequestExport = false
        didAutoClickExport = false
        exportPollCount = 0
        let request = URLRequest(url: syncOnly ? exportPageURL : signInURL)
        webView.load(request)
    }

    func disconnect() {
        stop()
        isConnected = false
        requiresLogin = false
        phase = .idle
        statusText = "Loading Goodreads..."
        Task { [weak self] in
            await WebSessionCleaner.clear(domains: ["goodreads"])
            if let signInURL = self?.signInURL {
                _ = await MainActor.run {
                    self?.webView.load(URLRequest(url: signInURL))
                }
            }
        }
    }

    func refreshConnectionStatus() async {
        isConnected = await Self.hasGoodreadsSession()
    }

    static func hasGoodreadsSession() async -> Bool {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let now = Date()
                let connected = cookies.contains { cookie in
                    let domain = cookie.domain.lowercased()
                    let isGoodreads = domain.contains("goodreads.com")
                    let expires = cookie.expiresDate ?? now.addingTimeInterval(3600)
                    return isGoodreads && expires > now
                }
                continuation.resume(returning: connected)
            }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        exportPollCount = 0
    }

    private func handleExportPage() {
        let script = #"""
        (() => {
          if (document.readyState !== 'complete') { return 'loading'; }
          const bodyText = document.body ? document.body.innerText.toLowerCase() : '';
          const exportButton = document.querySelector('.js-LibraryExport') || [...document.querySelectorAll('input[type="submit"], button')].find(el => {
            const text = ((el.value || '') + ' ' + (el.textContent || '')).toLowerCase();
            return text.includes('export');
          });
          const statusEl = document.getElementById('exportStatusText');
          const fileList = document.getElementById('exportFile');
          const statusText = statusEl ? statusEl.textContent.toLowerCase() : '';
          const loginForm = document.querySelector('form#sign_in, form[action*="sign_in"], input[name="user[email]"], input[name="user[password]"]');
          if (loginForm) { return 'login_required'; }
          const loginLink = [...document.querySelectorAll('a')].find(el => {
            const href = (el.getAttribute('href') || '').toLowerCase();
            return href.includes('sign_in') || href.includes('signin');
          });
          if (!exportButton && loginLink) { return 'login_required'; }

          if (!window.__shlfExportClicked && exportButton) {
            exportButton.click();
            window.__shlfExportClicked = true;
            return 'export_clicked';
          }

          if (statusText.includes('generating') || statusText.includes('export is in progress') || statusText.includes('export in progress') || bodyText.includes('export is in progress')) {
            return 'export_pending';
          }

          const link = fileList ? fileList.querySelector('a[href*=\".csv\"], a[href*=\"goodreads_export.csv\"]') : null;
          if (link && link.href) { return link.href; }

          if (bodyText.includes('captcha') || bodyText.includes('robot')) {
            return 'captcha';
          }
          return 'waiting';
        })();
        """#

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }

            if error != nil {
                self.phase = .waitingForExport
                self.statusText = "Loading export page..."
                self.startPolling()
                return
            }

            if let link = result as? String, link.hasPrefix("http"), let url = URL(string: link) {
                self.phase = .downloading
                self.statusText = "Downloading CSV..."
                Task {
                    await self.downloadCSV(from: url)
                }
                return
            }

            if let resultString = result as? String {
                switch resultString {
                case "loading":
                    self.phase = .waitingForExport
                    self.statusText = "Loading export page..."
                    self.startPolling()
                case "login_required":
                    self.stop()
                    self.phase = .waitingForLogin
                    self.statusText = "Sign in to Goodreads"
                    if self.isSyncOnly {
                        self.requiresLogin = true
                    }
                    self.webView.load(URLRequest(url: self.signInURL))
                case "export_clicked":
                    self.didAutoClickExport = true
                    self.phase = .waitingForExport
                    self.statusText = "Export started. Waiting for file..."
                    self.startPolling()
                case "export_pending":
                    self.phase = .waitingForExport
                    self.statusText = "Waiting for export to finish..."
                    self.startPolling()
                case "captcha":
                    self.fail(with: "Goodreads blocked automated export. Please use manual CSV upload.")
                case "waiting":
                    self.phase = .waitingForExport
                    self.statusText = "Waiting for export to finish..."
                    self.startPolling()
                default:
                    self.fail(with: "We couldn't find the Export Library page. Goodreads may have changed something.")
                }
            } else {
                self.phase = .waitingForExport
                self.statusText = "Loading export page..."
                self.startPolling()
            }
        }
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.exportPollCount += 1
            if self.exportPollCount > 60 {
                self.fail(with: "Export is taking too long. Please try manual CSV upload.")
                return
            }
            self.handleExportPage()
        }
    }

    private func fail(with message: String) {
        stop()
        phase = .failed(message)
        errorMessage = message
    }

    private func triggerExportIfNeeded() {
        guard !didRequestExport else { return }
        didRequestExport = true
        phase = .exporting
        statusText = "Preparing export..."
        webView.load(URLRequest(url: exportPageURL))
    }

    private func downloadCSV(from url: URL) async {
        do {
            let cookies = await cookies(for: url)
            var request = URLRequest(url: url)
            let headerFields = HTTPCookie.requestHeaderFields(with: cookies)
            for (header, value) in headerFields {
                request.setValue(value, forHTTPHeaderField: header)
            }

            let session = URLSession(configuration: .ephemeral)
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw GoodreadsImportError.unreadableFile
            }

            phase = .finished
            statusText = "Export complete"
            downloadedData = data
            stop()
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    private func cookies(for url: URL) async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let host = url.host?.lowercased() ?? ""
                let filtered = cookies.filter { cookie in
                    let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
                    return host.hasSuffix(domain)
                }
                continuation.resume(returning: filtered)
            }
        }
    }
}

extension GoodreadsImportCoordinator: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let path = url.path.lowercased()

        if path.contains("sign_in") || path.contains("signin") || path.contains("sign_up") || path.contains("signup") {
            phase = .waitingForLogin
            statusText = "Sign in to Goodreads"
            didRequestExport = false
            didAutoClickExport = false
            isConnected = false
            if isSyncOnly {
                requiresLogin = true
            }
            return
        }

        if path.contains("/review/import") {
            isConnected = true
            phase = .exporting
            statusText = "Preparing export..."
            requiresLogin = false
            handleExportPage()
        } else {
            triggerExportIfNeeded()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse,
           let url = response.url {
            let mimeType = response.mimeType?.lowercased() ?? ""
            let disposition = (response.allHeaderFields["Content-Disposition"] as? String)?.lowercased() ?? ""
            let isCSV = mimeType.contains("text/csv") ||
                mimeType.contains("application/csv") ||
                url.path.lowercased().hasSuffix(".csv") ||
                disposition.contains(".csv") ||
                disposition.contains("csv")

            if isCSV {
                phase = .downloading
                statusText = "Downloading CSV..."
                decisionHandler(.cancel)
                Task {
                    await downloadCSV(from: url)
                }
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
        phase = .downloading
        statusText = "Downloading CSV..."
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
        phase = .downloading
        statusText = "Downloading CSV..."
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
            fail(with: "Could not read CSV file.")
            return
        }

        do {
            let data = try Data(contentsOf: downloadURL)
            phase = .finished
            statusText = "Export complete"
            downloadedData = data
            stop()
        } catch {
            fail(with: error.localizedDescription)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        fail(with: error.localizedDescription)
    }
}
#endif
