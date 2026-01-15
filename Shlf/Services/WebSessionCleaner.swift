#if os(iOS) && !WIDGET_EXTENSION
import WebKit

enum WebSessionCleaner {
    static func clear(domains: [String]) async {
        await clearCookies(domains: domains)
        await clearWebsiteData(domains: domains)
    }

    private static func clearCookies(domains: [String]) async {
        let store = WKWebsiteDataStore.default()
        await withCheckedContinuation { continuation in
            store.httpCookieStore.getAllCookies { cookies in
                for cookie in cookies where matches(cookie.domain, domains: domains) {
                    store.httpCookieStore.delete(cookie)
                }
                continuation.resume(returning: ())
            }
        }
    }

    private static func clearWebsiteData(domains: [String]) async {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await withCheckedContinuation { continuation in
            store.fetchDataRecords(ofTypes: types) { records in
                let targets = records.filter { matches($0.displayName, domains: domains) }
                guard !targets.isEmpty else {
                    continuation.resume(returning: ())
                    return
                }
                store.removeData(ofTypes: types, for: targets) {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func matches(_ value: String, domains: [String]) -> Bool {
        let lower = value.lowercased()
        return domains.contains { lower.contains($0) }
    }
}
#endif
