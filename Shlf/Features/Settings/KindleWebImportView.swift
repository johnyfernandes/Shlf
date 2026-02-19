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
    @Environment(\.themeColor) private var themeColor
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
                    Text("KindleImport.Web.Title")
                        .font(.headline)

                    Text("KindleImport.Web.Description")
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
            .navigationTitle("KindleImport.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Common.Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }

                if coordinator.isConnected {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                coordinator.disconnect()
                            } label: {
                                Label("KindleImport.Disconnect", systemImage: "link.badge.minus")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(themeColor.color)
                        }
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
