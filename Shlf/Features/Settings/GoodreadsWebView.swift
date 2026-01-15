//
//  GoodreadsWebView.swift
//  Shlf
//
//  Shared WKWebView container for Goodreads import
//

#if os(iOS) && !WIDGET_EXTENSION
import SwiftUI
import WebKit

struct GoodreadsWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif
