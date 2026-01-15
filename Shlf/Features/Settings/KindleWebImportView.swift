//
//  KindleWebImportView.swift
//  Shlf
//
//  Web import flow for Kindle
//

#if os(iOS) && !WIDGET_EXTENSION
import SwiftUI

struct KindleWebImportView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var coordinator: KindleImportCoordinator

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
                    Text(String(localized: "Import from Kindle"))
                        .font(.headline)

                    Text(String(localized: "Sign in with your Amazon account and we'll import your Kindle library."))
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
            .navigationTitle(String(localized: "Kindle"))
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
            .onChange(of: coordinator.phase) { _, newPhase in
                switch newPhase {
                case .scanning, .finished, .failed:
                    dismiss()
                case .idle, .waitingForLogin:
                    break
                }
            }
        }
    }
}
#endif
