//
//  ShlfApp.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

@main
struct ShlfApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var modelError: Error?

    init() {
        do {
            // Use shared configuration for app group access (widget/Live Activity)
            let container = try SwiftDataConfig.createModelContainer()
            _modelContainer = State(initialValue: container)
        } catch {
            _modelError = State(initialValue: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let error = modelError {
                ErrorStateView(error: error)
            } else if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
                    .onAppear {
                        WatchConnectivityManager.shared.configure(modelContext: container.mainContext)
                        WatchConnectivityManager.shared.activate()
                        WidgetDataExporter.exportSnapshot(modelContext: container.mainContext)
                    }
            } else {
                ProgressView()
            }
        }
    }
}

struct ErrorStateView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Unable to Start")
                .font(.title)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Restart App") {
                exit(0)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
