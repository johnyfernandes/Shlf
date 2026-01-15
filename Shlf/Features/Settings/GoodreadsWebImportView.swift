//
//  GoodreadsWebImportView.swift
//  Shlf
//
//  Web import flow for Goodreads
//

#if os(iOS) && !WIDGET_EXTENSION
import SwiftUI
import WebKit

struct GoodreadsWebImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator: GoodreadsImportCoordinator

    let onCSVData: (Data) -> Void
    let onError: (String) -> Void

    init(onCSVData: @escaping (Data) -> Void, onError: @escaping (String) -> Void) {
        self.onCSVData = onCSVData
        self.onError = onError
        _coordinator = StateObject(wrappedValue: GoodreadsImportCoordinator())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Import from Goodreads"))
                        .font(.headline)

                    Text(String(localized: "Sign in to Goodreads and we'll fetch your export automatically."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ProgressView()
                    Text(coordinator.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                GoodreadsWebView(webView: coordinator.webView)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(16)
            .navigationTitle(String(localized: "Goodreads"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Disconnect")) {
                        coordinator.disconnect()
                    }
                }
            }
            .onAppear {
                coordinator.start()
            }
            .onDisappear {
                coordinator.stop()
            }
            .onChange(of: coordinator.downloadedData) { _, data in
                guard let data else { return }
                onCSVData(data)
                dismiss()
            }
            .onChange(of: coordinator.errorMessage) { _, message in
                guard let message else { return }
                onError(message)
                dismiss()
            }
        }
    }
}

private struct GoodreadsWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif
