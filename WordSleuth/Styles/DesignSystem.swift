import SwiftUI
import AudioToolbox

public struct Theme {
    // Elegant Dark Theme Palette
    public static let background = Color(hex: "0D0E15")      // Deep space black
    public static let surface = Color(hex: "171926")         // Soft slate navy
    public static let surfaceSecondary = Color(hex: "23263B") // Lighter navy for cards
    
    // Vibrant Neon Accents
    public static let primary = Color(hex: "6366F1")         // Digital Indigo
    public static let secondary = Color(hex: "A855F7")       // Electric Purple
    public static let accent = Color(hex: "EC4899")          // Hot Pink
    public static let success = Color(hex: "10B981")         // Emerald Green
    
    // Texts
    public static let textPrimary = Color(hex: "F8FAFC")     // Pure white-gray
    public static let textSecondary = Color(hex: "94A3B8")   // Muted slate gray
    public static let textMuted = Color(hex: "64748B")       // Darker slate
    
    // Solved Highlighter Colors
    public static let solvedColors = [
        Color(hex: "10B981"), // Emerald Green
        Color(hex: "6366F1"), // Indigo
        Color(hex: "A855F7"), // Purple
        Color(hex: "F59E0B"), // Amber Yellow
        Color(hex: "EC4899"), // Pink
        Color(hex: "3B82F6"), // Blue
        Color(hex: "EF4444")  // Coral Red
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Glassmorphism modifier
public struct GlassModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 10)
    }
}

extension View {
    public func glassmorphic() -> some View {
        modifier(GlassModifier())
    }
}


// Interactive Premium Button
public struct PremiumButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.headline)
                }
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Theme.primary, Theme.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Theme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
        }
    }
}

// Haptic feedback manager for satisfying micro-interactions
public class HapticManager {
    public static let shared = HapticManager()
    private init() {}
    
    public func impact(_ feedback: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: feedback)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
