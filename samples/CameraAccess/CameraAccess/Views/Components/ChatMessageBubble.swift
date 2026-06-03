import SwiftUI

struct ChatMessageBubble: View {
    let text: String
    let isUser: Bool
    var timestamp: Date? = nil

    @State private var showContent = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if !isUser {
                // AI Icon (Sparkle) with glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: .purple.opacity(0.4), radius: 6)

                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.bottom, 4)
            } else {
                Spacer()
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Message text
                Text(text)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .background(
                        Group {
                            if isUser {
                                Color.blue.opacity(0.25)
                            } else {
                                Color.purple.opacity(0.15)
                                    .shadow(color: .purple.opacity(0.3), radius: 8)
                            }
                        }
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isUser ? Color.white.opacity(0.15) : Color.purple.opacity(0.3), lineWidth: 1)
                    )

                // Timestamp (if provided)
                if let ts = timestamp {
                    Text(ts, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 4)
                }
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.95, anchor: isUser ? .trailing : .leading)
            .animation(.spring(response: 0.35, dampingFraction: 0.8).delay(0.05), value: showContent)

            if isUser {
                // User icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 32, height: 32)

                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.bottom, 4)
            } else {
                Spacer()
            }
        }
        .onAppear { showContent = true }
    }
}
