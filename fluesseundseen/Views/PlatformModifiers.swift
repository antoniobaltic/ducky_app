import SwiftUI

// MARK: - iOS Navigation Bar Modifier

struct IOSNavigationBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        content
        #endif
    }
}

struct IOSNavigationBarInline: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.navigationBarTitleDisplayMode(.inline)
        #else
        content
        #endif
    }
}

extension View {
    func iOSNavigationBarStyle() -> some View {
        modifier(IOSNavigationBarStyle())
    }

    func iOSNavigationBarInline() -> some View {
        modifier(IOSNavigationBarInline())
    }
}

// MARK: - Toolbar placement compat

extension ToolbarItemPlacement {
    static var iOSTopBarLeading: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .navigation
        #endif
    }

    static var iOSTopBarTrailing: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .primaryAction
        #endif
    }
}
