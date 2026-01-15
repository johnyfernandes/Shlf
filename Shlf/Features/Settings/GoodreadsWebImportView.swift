//
//  GoodreadsWebImportView.swift
//  Shlf
//
//  Web import flow for Goodreads
//

#if os(iOS) && !WIDGET_EXTENSION
import SwiftUI

struct GoodreadsWebImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coordinator: GoodreadsImportCoordinator

    private var showsWebView: Bool {
        switch coordinator.phase {
        case .idle, .waitingForLogin:
            return true
        default:
            return false
        }
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
                    .opacity(showsWebView ? 1 : 0.01)
                    .frame(height: showsWebView ? nil : 1)
                    .allowsHitTesting(showsWebView)
            }
            .padding(16)
            .navigationTitle(String(localized: "Goodreads"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Close")) {
                        coordinator.stop()
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
            .onChange(of: coordinator.phase) { _, newPhase in
                switch newPhase {
                case .exporting, .waitingForExport, .downloading, .finished, .failed:
                    dismiss()
                case .idle, .waitingForLogin:
                    break
                }
            }
        }
    }
}
#endif
