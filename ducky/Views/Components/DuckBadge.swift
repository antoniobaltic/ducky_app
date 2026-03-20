import SwiftUI

// MARK: - Small Badge

struct DuckBadge: View {
    let state: DuckState
    var size: CGFloat = 40

    var body: some View {
        DuckView(state: state, size: size)
    }
}
