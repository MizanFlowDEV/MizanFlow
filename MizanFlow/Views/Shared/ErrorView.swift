import SwiftUI

/// Reusable error view component
struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text(NSLocalizedString("Error", comment: "Error title"))
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Label(NSLocalizedString("Retry", comment: "Retry button"), systemImage: "arrow.clockwise")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(NSLocalizedString("Retry", comment: "Retry accessibility"))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// Error overlay modifier
struct ErrorOverlay: ViewModifier {
    let error: Error?
    let retryAction: (() -> Void)?
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if let error = error {
                ErrorView(error: error, retryAction: retryAction)
            }
        }
    }
}

extension View {
    func errorOverlay(error: Error?, retryAction: (() -> Void)? = nil) -> some View {
        modifier(ErrorOverlay(error: error, retryAction: retryAction))
    }
}



