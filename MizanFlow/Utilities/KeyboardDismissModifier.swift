import SwiftUI

/// A ViewModifier that dismisses the keyboard when tapping outside text fields
/// Works with List, Form, and other scrollable views without interfering with scrolling
struct KeyboardDismissModifier<F: Hashable>: ViewModifier {
    @FocusState.Binding var focusedField: F?
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        // Dismiss keyboard by removing focus when tapping outside
                        // This works with List/Form because simultaneousGesture doesn't block other gestures
                        focusedField = nil
                    }
            )
    }
}

/// A ViewModifier that dismisses the keyboard when tapping outside text fields (for Bool FocusState)
/// Works with List, Form, and other scrollable views without interfering with scrolling
struct KeyboardDismissModifierBool: ViewModifier {
    @FocusState.Binding var focusedField: Bool
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        // Dismiss keyboard by removing focus when tapping outside
                        // This works with List/Form because simultaneousGesture doesn't block other gestures
                        focusedField = false
                    }
            )
    }
}

/// Extension to make it easy to apply the modifier
extension View {
    /// Dismisses keyboard when tapping outside text fields
    /// Works with List, Form, and other scrollable views without interfering with scrolling
    /// Uses simultaneousGesture so it doesn't block list scrolling or button taps
    /// - Parameter focusedField: The @FocusState binding that controls field focus
    /// - Returns: A view with keyboard dismiss functionality
    func dismissKeyboardOnTap<F: Hashable>(focusedField: FocusState<F?>.Binding) -> some View {
        self.modifier(KeyboardDismissModifier(focusedField: focusedField))
    }
    
    /// Dismisses keyboard when tapping outside text fields (for Bool FocusState)
    /// Works with List, Form, and other scrollable views without interfering with scrolling
    /// Uses simultaneousGesture so it doesn't block list scrolling or button taps
    /// - Parameter focusedField: The @FocusState binding that controls field focus
    /// - Returns: A view with keyboard dismiss functionality
    func dismissKeyboardOnTap(focusedField: FocusState<Bool>.Binding) -> some View {
        self.modifier(KeyboardDismissModifierBool(focusedField: focusedField))
    }
}

