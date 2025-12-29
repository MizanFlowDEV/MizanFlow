import SwiftUI

/// Centralized design tokens for MizanFlow
/// Provides consistent colors, typography, spacing, and other design elements
struct DesignTokens {
    
    // MARK: - Colors
    
    struct Color {
        /// Primary action color - used for main actions and highlights
        static var primary: SwiftUI.Color {
            SwiftUI.Color.accentColor
        }
        
        /// Secondary color - used for secondary actions
        static var secondary: SwiftUI.Color {
            SwiftUI.Color.secondary
        }
        
        /// Success state color - used for positive indicators
        static var success: SwiftUI.Color {
            SwiftUI.Color(light: .green, dark: .green)
        }
        
        /// Warning state color - used for warnings and cautions
        static var warning: SwiftUI.Color {
            SwiftUI.Color(light: .orange, dark: .orange)
        }
        
        /// Error state color - used for errors and destructive actions
        static var error: SwiftUI.Color {
            SwiftUI.Color(light: .red, dark: .red)
        }
        
        /// Background color - main app background
        static var background: SwiftUI.Color {
            SwiftUI.Color(.systemBackground)
        }
        
        /// Surface color - for cards and elevated surfaces
        static var surface: SwiftUI.Color {
            SwiftUI.Color(.secondarySystemBackground)
        }
        
        /// Separator color - for dividers and borders
        static var separator: SwiftUI.Color {
            SwiftUI.Color(.separator)
        }
        
        /// Text primary - main text color
        static var textPrimary: SwiftUI.Color {
            SwiftUI.Color(.label)
        }
        
        /// Text secondary - secondary text color
        static var textSecondary: SwiftUI.Color {
            SwiftUI.Color(.secondaryLabel)
        }
        
        // Day type specific colors (light/dark aware)
        static var workday: SwiftUI.Color {
            SwiftUI.Color(light: .green, dark: .green)
        }
        
        static var offDay: SwiftUI.Color {
            SwiftUI.Color(light: .gray, dark: .gray)
        }
        
        static var vacation: SwiftUI.Color {
            SwiftUI.Color(light: .yellow, dark: .yellow)
        }
        
        static var training: SwiftUI.Color {
            SwiftUI.Color(light: .orange, dark: .orange)
        }
        
        static var holiday: SwiftUI.Color {
            SwiftUI.Color(light: .blue, dark: .blue)
        }
        
        static var override: SwiftUI.Color {
            SwiftUI.Color(light: .red, dark: .red)
        }
    }
    
    // MARK: - Typography
    
    struct Typography {
        /// Screen Title - for main screen titles
        static var screenTitle: Font {
            .system(size: 28, weight: .bold, design: .default)
        }
        
        /// Section Title - for section headers
        static var sectionTitle: Font {
            .system(size: 17, weight: .semibold, design: .default)
        }
        
        /// Body - for main content text
        static var body: Font {
            .system(size: 17, weight: .regular, design: .default)
        }
        
        /// Caption - for secondary text and labels
        static var caption: Font {
            .system(size: 13, weight: .regular, design: .default)
        }
    }
    
    // MARK: - Spacing (8pt grid system)
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }
    
    // MARK: - Icon Sizes
    
    struct Icon {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xlarge: CGFloat = 24
        
        /// Standard icon weight for outline style
        static var weight: Font.Weight {
            .regular
        }
    }
    
    // MARK: - Calendar Specific
    
    struct Calendar {
        /// Minimum cell size for calendar day cells
        static let minCellSize: CGFloat = 44
        
        /// Spacing between calendar cells
        static let cellSpacing: CGFloat = Spacing.sm
        
        /// Indicator dot size for calendar cells
        static let indicatorSize: CGFloat = 4
        
        /// Indicator bar height for calendar cells
        static let indicatorBarHeight: CGFloat = 2
        
        /// Border width for today/selected states
        static let borderWidth: CGFloat = 2
    }
}

// MARK: - Color Extension for Light/Dark Support

extension SwiftUI.Color {
    /// Creates a color that adapts to light and dark mode
    init(light: SwiftUI.Color, dark: SwiftUI.Color) {
        #if os(iOS)
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
        #else
        // Fallback for other platforms
        self = light
        #endif
    }
}
