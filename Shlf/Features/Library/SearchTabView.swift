import SwiftUI

struct SearchTabView: View {
    @Binding var selectedTab: Int
    @State private var resetID = UUID()

    var body: some View {
        BookSearchView(
            selectedTab: $selectedTab,
            onDismissAll: {
                resetID = UUID()
            }
        )
        .id(resetID)
    }
}

#Preview {
    SearchTabView(selectedTab: .constant(3))
}
