//
//  KindleImportCoordinator.swift
//  Shlf
//
//  Automates Kindle library import via read.amazon.com
//

#if os(iOS) && !WIDGET_EXTENSION
import Foundation
import Combine
import WebKit

@MainActor
final class KindleImportCoordinator: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForLogin
        case scanning
        case finished
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var statusText: String = String(localized: "Loading Kindle...")
    @Published var items: [KindleImportItem] = []
    @Published var errorMessage: String?
    @Published var isConnected: Bool = false
    @Published var requiresLogin: Bool = false

    let webView: WKWebView

    private let landingURL = URL(string: "https://read.amazon.com/landing")!
    private let libraryURL = URL(string: "https://read.amazon.com/kindle-library")!
    private var didStartScrape = false
    private var isSyncOnly = false
    private var didRequestLibrary = false

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let contentController = WKUserContentController()
        config.userContentController = contentController
        self.webView = WKWebView(frame: .zero, configuration: config)

        super.init()

        contentController.add(self, name: "kindleImport")
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "kindleImport")
    }

    func start(syncOnly: Bool = false) {
        isSyncOnly = syncOnly
        requiresLogin = false
        phase = .idle
        statusText = String(localized: "Loading Kindle...")
        errorMessage = nil
        items = []
        didStartScrape = false
        didRequestLibrary = false

        let request = URLRequest(url: syncOnly ? libraryURL : landingURL)
        webView.load(request)
    }

    func disconnect() {
        isConnected = false
        requiresLogin = false
        phase = .idle
        statusText = String(localized: "Loading Kindle...")
        didStartScrape = false
        Task {
            await WebSessionCleaner.clear(domains: ["amazon"])
        }
    }

    func refreshConnectionStatus() async {
        isConnected = await Self.hasAmazonSession()
    }

    static func hasAmazonSession() async -> Bool {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let now = Date()
                let connected = cookies.contains { cookie in
                    let domain = cookie.domain.lowercased()
                    let isAmazon = domain.contains("amazon") || domain.contains("read.amazon")
                    let expires = cookie.expiresDate ?? now.addingTimeInterval(3600)
                    return isAmazon && expires > now
                }
                continuation.resume(returning: connected)
            }
        }
    }

    private func handleLibraryPage() {
        guard !didStartScrape else { return }
        didStartScrape = true
        phase = .scanning
        statusText = String(localized: "Scanning Kindle library...")
        runScrapeScript()
    }

    private func runScrapeScript() {
        let script = #"""
        (() => {
          const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));
          const getContainer = () => {
            return document.querySelector('main#library')
              || document.querySelector('#library')
              || document.scrollingElement
              || document.body;
          };

          const waitForList = async () => {
            for (let i = 0; i < 20; i++) {
              if (document.querySelector('ul#cover')) { return true; }
              await sleep(500);
            }
            return false;
          };

          const scrollToEnd = async (container) => {
            let sameCount = 0;
            let lastCount = 0;
            for (let i = 0; i < 60 && sameCount < 4; i++) {
              container.scrollTop = container.scrollHeight;
              window.scrollTo(0, document.body.scrollHeight);
              await sleep(700);
              const count = document.querySelectorAll('li[id^="library-item-option-"]').length;
              if (count === lastCount) {
                sameCount += 1;
              } else {
                sameCount = 0;
                lastCount = count;
              }
            }
          };

          const extractItems = () => {
            const nodes = document.querySelectorAll('li[id^="library-item-option-"]');
            const items = [];
            nodes.forEach(node => {
              const id = node.id || '';
              const asin = id.split('-').pop() || '';
              if (!asin) { return; }
              const isSample = id.includes('sample') || node.querySelector('[aria-label="sample"]') !== null;
              const titleEl = node.querySelector(`#title-${asin} p`) || node.querySelector(`[id^="title-${asin}"] p`);
              const authorEl = node.querySelector(`#author-${asin} p`) || node.querySelector(`[id^="author-${asin}"] p`);
              const coverEl = node.querySelector(`#cover-${asin}`) || node.querySelector(`img[id^="cover-${asin}"]`) || node.querySelector('img[id^="cover-"]');
              const title = titleEl ? titleEl.textContent.trim() : '';
              const author = authorEl ? authorEl.textContent.trim() : '';
              const coverURL = coverEl ? (coverEl.getAttribute('src') || '') : '';
              items.push({ asin, title, author, coverURL, isSample });
            });
            return items.filter(item => item.title);
          };

          const run = async () => {
            const listReady = await waitForList();
            if (!listReady) {
              window.webkit.messageHandlers.kindleImport.postMessage(JSON.stringify({ type: 'error', message: 'missing_list' }));
              return;
            }
            const container = getContainer();
            await scrollToEnd(container);
            const items = extractItems();
            window.webkit.messageHandlers.kindleImport.postMessage(JSON.stringify({ type: 'books', items }));
          };
          run();
        })();
        """#

        webView.evaluateJavaScript(script) { [weak self] _, error in
            guard let self else { return }
            if error != nil {
                self.phase = .failed(String(localized: "We couldn't read your Kindle library. Please try again."))
                self.errorMessage = String(localized: "We couldn't read your Kindle library. Please try again.")
            }
        }
    }
}

extension KindleImportCoordinator: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let path = url.path.lowercased()

        if path.contains("landing") || path.contains("signin") || path.contains("sign-in") {
            phase = .waitingForLogin
            statusText = String(localized: "Sign in to Amazon")
            isConnected = false
            didStartScrape = false
            if isSyncOnly {
                requiresLogin = true
            }
            return
        }

        if path.contains("kindle-library") {
            isConnected = true
            requiresLogin = false
            handleLibraryPage()
            return
        }

        if url.host?.contains("read.amazon.com") == true, !didRequestLibrary {
            didRequestLibrary = true
            webView.load(URLRequest(url: libraryURL))
        }
    }
}

extension KindleImportCoordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "kindleImport" else { return }
        guard let body = message.body as? String,
              let data = body.data(using: .utf8) else { return }

        struct Payload: Decodable {
            let type: String
            let items: [KindleImportItem]?
            let message: String?
        }

        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            if payload.type == "books", let items = payload.items {
                self.items = items
                self.phase = .finished
                self.statusText = String.localizedStringWithFormat(String(localized: "Found %lld books"), items.count)
            } else {
                let errorMessage = String(localized: "We couldn't read your Kindle library. Please try again.")
                self.phase = .failed(errorMessage)
                self.errorMessage = errorMessage
            }
        } catch {
            let errorMessage = String(localized: "We couldn't read your Kindle library. Please try again.")
            phase = .failed(errorMessage)
            self.errorMessage = errorMessage
        }
    }
}
#endif
