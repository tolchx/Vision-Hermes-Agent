import SwiftUI

// MARK: - Design System Tokens
// Single source of truth for all visual constants.

enum DS {

    // MARK: - Colors
    enum Color {
        static let background = SwiftUI.Color(red: 0.02, green: 0.02, blue: 0.04)
        static let surface = SwiftUI.Color(red: 0.08, green: 0.08, blue: 0.12)
        static let surfaceLight = SwiftUI.Color.white.opacity(0.05)

        // VisionHermes accent palette
        static let accentCyan = SwiftUI.Color(red: 0.00, green: 0.95, blue: 1.00)       // #00f3ff
        static let accentCyanDim = SwiftUI.Color(red: 0.00, green: 0.95, blue: 1.00).opacity(0.6)
        static let accentPurple = SwiftUI.Color(red: 0.49, green: 0.24, blue: 0.93)     // #7c3aed
        static let accentPurpleDim = SwiftUI.Color(red: 0.49, green: 0.24, blue: 0.93).opacity(0.6)
        static let accentGradient = LinearGradient(
            colors: [accentCyan, accentPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Legacy aliases
        static let accent = accentCyan
        static let accentPurpleFull = accentPurple

        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color.white.opacity(0.6)
        static let textTertiary = SwiftUI.Color.white.opacity(0.35)
        static let destructive = SwiftUI.Color.red
        static let success = SwiftUI.Color.green
        static let warning = SwiftUI.Color.yellow
        static let border = SwiftUI.Color.white.opacity(0.1)
        static let borderSubtle = SwiftUI.Color.white.opacity(0.06)
        static let borderCyan = accentCyan.opacity(0.3)
    }

    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .default)
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)
        static let captionBold = Font.system(size: 11, weight: .bold)
        static let mono = Font.system(size: 10, design: .monospaced)
        static let pill = Font.system(size: 12, weight: .medium)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xxxs: CGFloat = 2
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let pill: CGFloat = 24
        static let full: CGFloat = 999
    }

    // MARK: - Shadows
    enum Shadow {
        static let soft = SwiftUI.Color.black.opacity(0.15)
        static let medium = SwiftUI.Color.black.opacity(0.25)
        static let strong = SwiftUI.Color.black.opacity(0.4)

        static func standard(radius: CGFloat = 8, y: CGFloat = 4) -> some ViewModifier {
            ShadowModifier(radius: radius, y: y)
        }
    }

    // MARK: - Animation
    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
    }
}

// MARK: - Shadow Modifier

struct ShadowModifier: ViewModifier {
    let radius: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: DS.Shadow.medium, radius: radius, x: 0, y: y)
    }
}

// MARK: - Neon Glow Modifier

struct NeonGlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity * 0.6), radius: radius)
            .shadow(color: color.opacity(intensity * 0.3), radius: radius * 2)
            .shadow(color: color.opacity(intensity * 0.15), radius: radius * 3)
    }
}

extension View {
    /// Apply a neon glow effect with the specified color
    func neonGlow(color: Color = DS.Color.accentCyan, radius: CGFloat = 8, intensity: CGFloat = 1.0) -> some View {
        self.modifier(NeonGlowModifier(color: color, radius: radius, intensity: intensity))
    }

    /// Cyan neon glow (default)
    func neonCyan(radius: CGFloat = 8, intensity: CGFloat = 1.0) -> some View {
        neonGlow(color: DS.Color.accentCyan, radius: radius, intensity: intensity)
    }

    /// Purple neon glow
    func neonPurple(radius: CGFloat = 8, intensity: CGFloat = 1.0) -> some View {
        neonGlow(color: DS.Color.accentPurple, radius: radius, intensity: intensity)
    }
}

// MARK: - Glassmorphism Modifiers (enhanced)

struct GlassmorphismModifier: ViewModifier {
    var borderColor: Color
    var borderWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base blur layer
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)

                    // Color tint
                    DS.Color.surface.opacity(0.3)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}

struct GlassmorphismPillModifier: ViewModifier {
    var borderColor: Color

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                ZStack {
                    VisualEffectBlur(blurStyle: .systemUltraThinMaterial)
                    DS.Color.surface.opacity(0.2)
                }
                .clipShape(Capsule())
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
    }
}

extension View {
    func dsBackground() -> some View {
        self.background(DS.Color.surfaceLight)
    }

    func dsCornerRadius(_ radius: CGFloat = DS.Radius.md) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius))
    }

    func dsBorder(_ color: Color = DS.Color.border, width: CGFloat = 1) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(color, lineWidth: width)
        )
    }

    func dsCard() -> some View {
        self
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(DS.Color.surfaceLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .stroke(DS.Color.borderSubtle, lineWidth: 1)
                    )
            )
    }

    func dsPill() -> some View {
        self
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule()
                    .fill(DS.Color.surfaceLight)
                    .overlay(
                        Capsule()
                            .stroke(DS.Color.border, lineWidth: 1)
                    )
            )
    }

    func dsSafeBottom() -> some View {
        self.padding(.bottom, DS.Spacing.xxl)
    }

    /// Enhanced glassmorphism with optional cyan border
    func glassmorphismCyan() -> some View {
        self.modifier(GlassmorphismModifier(borderColor: DS.Color.borderCyan, borderWidth: 1))
    }

    /// Glassmorphism pill with cyan border
    func glassmorphismPillCyan() -> some View {
        self.modifier(GlassmorphismPillModifier(borderColor: DS.Color.borderCyan))
    }
}

// MARK: - VisualEffectBlur (UIViewRepresentable wrapper)

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Section Header
struct DSSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(DS.Typography.captionBold)
            .foregroundColor(DS.Color.textTertiary)
            .padding(.leading, DS.Spacing.xs)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxs)
    }
}

// MARK: - Empty State
struct DSEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(DS.Color.textTertiary)

            Text(title)
                .font(DS.Typography.headline)
                .foregroundColor(DS.Color.textSecondary)

            if let msg = message {
                Text(msg)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
