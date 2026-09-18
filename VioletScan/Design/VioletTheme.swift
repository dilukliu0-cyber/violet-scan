import SwiftUI

enum VioletTheme {
    static let deepBlack = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let graphite = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let graphiteSoft = Color(red: 0.16, green: 0.16, blue: 0.20)
    static let electricViolet = Color(red: 0.56, green: 0.27, blue: 1.0)
    static let violetGlow = Color(red: 0.72, green: 0.45, blue: 1.0)
    static let softWhite = Color(red: 0.92, green: 0.92, blue: 0.95)
    static let muted = Color(red: 0.62, green: 0.62, blue: 0.68)
    static let greenOK = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let yellowWarn = Color(red: 0.95, green: 0.78, blue: 0.25)
    static let redBad = Color(red: 0.95, green: 0.35, blue: 0.40)

    static func guidance(_ c: GuidanceColor) -> Color {
        switch c {
        case .green: return greenOK
        case .yellow: return yellowWarn
        case .red: return redBad
        case .purple: return electricViolet
        case .unknown: return muted
        }
    }
}

struct GlassPanel: ViewModifier {
    var corner: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(VioletTheme.graphite.opacity(0.72))
                    .background(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(VioletTheme.electricViolet.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: VioletTheme.electricViolet.opacity(0.18), radius: 16, y: 4)
            )
    }
}

extension View {
    func glassPanel(corner: CGFloat = 18) -> some View {
        modifier(GlassPanel(corner: corner))
    }
}

struct VioletPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                VioletTheme.electricViolet,
                                VioletTheme.violetGlow.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: VioletTheme.electricViolet.opacity(configuration.isPressed ? 0.2 : 0.45), radius: configuration.isPressed ? 6 : 18)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct VioletGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(VioletTheme.softWhite)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(VioletTheme.graphiteSoft.opacity(0.9))
                    .overlay(Capsule().stroke(VioletTheme.electricViolet.opacity(0.4), lineWidth: 1))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
