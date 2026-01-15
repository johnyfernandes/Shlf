#if os(iOS)
import SwiftUI
import Combine

@MainActor
final class QuickActionRouter: ObservableObject {
    @Published var activeBook: Book?
}
#endif
