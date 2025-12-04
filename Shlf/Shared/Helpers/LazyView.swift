//
//  LazyView.swift
//  Shlf
//
//  Performance optimization helper for deferred view initialization
//  Used with sheets, navigation, and full-screen covers to prevent
//  expensive views from loading until they're actually presented
//

import SwiftUI

/// LazyView defers view initialization until the view body is actually rendered.
/// This prevents expensive computations, API calls, or side effects from running
/// when views are placed in sheets or navigation destinations before being shown.
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showSheet) {
///     LazyView(ExpensiveDetailView())
/// }
/// ```
struct LazyView<Content: View>: View {
    let build: () -> Content

    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }

    var body: Content {
        build()
    }
}
