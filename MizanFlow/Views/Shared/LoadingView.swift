import SwiftUI

/// Reusable loading view component
struct LoadingView: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message ?? NSLocalizedString("Loading...", comment: "Loading message")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel(NSLocalizedString("Loading", comment: "Loading accessibility label"))
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).opacity(0.8))
    }
}

/// Loading overlay modifier
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    let message: String?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                LoadingView(message: message)
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}



