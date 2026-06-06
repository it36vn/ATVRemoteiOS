import SwiftUI

enum AppTheme {
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.02, blue: 0.03),
            Color(red: 0.08, green: 0.08, blue: 0.10),
            Color(red: 0.02, green: 0.02, blue: 0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassRow = Color.white.opacity(0.06)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.78)
    static let iconPrimary = Color(red: 0.39, green: 0.86, blue: 1.0)
}
