import SwiftUI

/// Animated gradient background optimized for performance.
/// Uses Metal-accelerated `AngularGradient` with slow, subtle animation
/// instead of particle systems that drain battery on glasses-connected devices.
struct AnimatedBackground: View {
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base color
            Color(red: 0.02, green: 0.02, blue: 0.04)
                .ignoresSafeArea()

            // Subtle animated gradient overlay (much cheaper than particles)
            AngularGradient(
                colors: [
                    Color(red: 0.04, green: 0.01, blue: 0.08).opacity(0.6),
                    Color(red: 0.01, green: 0.02, blue: 0.06).opacity(0.3),
                    Color(red: 0.06, green: 0.01, blue: 0.10).opacity(0.5),
                    Color(red: 0.04, green: 0.01, blue: 0.08).opacity(0.6),
                ],
                center: .center,
                angle: .degrees(animateGradient ? 360 : 0)
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.linear(duration: 18.0).repeatForever(autoreverses: false)) {
                    animateGradient.toggle()
                }
            }
        }
    }
}
