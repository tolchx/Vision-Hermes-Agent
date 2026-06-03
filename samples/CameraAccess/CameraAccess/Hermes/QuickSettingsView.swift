import SwiftUI

// MARK: - Quick Settings Panel

struct QuickSettingsView: View {
  @ObservedObject var geminiVM: GeminiSessionViewModel
  @ObservedObject var streamVM: StreamSessionViewModel
  @Binding var isPresented: Bool

  @State private var dragOffset: CGFloat = 0
  @State private var showToolCallHistory = false

  var body: some View {
    ZStack(alignment: .top) {
      // Dimmed background
      Color.black.opacity(0.3)
        .ignoresSafeArea()
        .onTapGesture { dismiss() }

      // Panel
      VStack(spacing: 0) {
        // Drag handle
        RoundedRectangle(cornerRadius: 2.5)
          .fill(Color.white.opacity(0.4))
          .frame(width: 36, height: 5)
          .padding(.top, 12)
          .padding(.bottom, 8)

        // Title
        HStack {
          Text("Quick Settings")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
          Spacer()
          Button(action: dismiss) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 22))
              .foregroundColor(.white.opacity(0.6))
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)

        // Settings content
        VStack(spacing: 12) {
          // Mic toggle
          settingRow(
            icon: geminiVM.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.slash.fill",
            iconColor: geminiVM.isSpeakerOn ? .blue : .gray,
            label: "Speaker",
            description: geminiVM.isSpeakerOn ? "On" : "Off"
          ) {
            geminiVM.toggleSpeaker()
          }

          Divider().background(Color.white.opacity(0.15))

          // Streaming mode toggle
          settingRow(
            icon: "video.fill",
            iconColor: .green,
            label: "Streaming Mode",
            description: streamVM.streamingMode == .glasses ? "Glasses" : "iPhone"
          ) {
            withAnimation {
              streamVM.streamingMode = streamVM.streamingMode == .glasses ? .iPhone : .glasses
              geminiVM.streamingMode = streamVM.streamingMode
            }
          }

          Divider().background(Color.white.opacity(0.15))

          // Connection status row
          VStack(spacing: 8) {
            HStack {
              Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 14))
                .foregroundColor(hermesStatusColor)
              Text("Hermes Gateway")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
              Spacer()
              ConnectionHealthIndicator(
                latencyMs: nil,
                connectionState: geminiVM.hermesConnectionState
              )
            }

            // Latency indicator (separate from the pill shown above)
            ConnectionHealthIndicator(
              latencyMs: geminiVM.hermesBridge.latencyMs,
              connectionState: geminiVM.hermesBridge.connectionState
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(hermesStatusDescription)
              .font(.system(size: 11))
              .foregroundColor(.white.opacity(0.5))
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .padding(.vertical, 4)

          Divider().background(Color.white.opacity(0.15))

          // Tool call history button
          Button(action: { withAnimation { showToolCallHistory.toggle() } }) {
            HStack {
              Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 14))
                .foregroundColor(.purple)
              Text("Tool Call History")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .rotationEffect(.degrees(showToolCallHistory ? 90 : 0))
            }
          }

          if showToolCallHistory {
            ToolCallHistoryView(bridge: geminiVM.hermesBridge)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
      }
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(Color.white.opacity(0.1), lineWidth: 1)
          )
      )
      .padding(.horizontal, 16)
      .offset(y: dragOffset)
      .gesture(
        DragGesture()
          .onChanged { value in
            guard value.translation.height > 0 else { return }
            dragOffset = value.translation.height
          }
          .onEnded { value in
            if value.translation.height > 100 {
              dismiss()
            } else {
              withAnimation(.spring()) { dragOffset = 0 }
            }
          }
      )
      .transition(.move(edge: .top).combined(with: .opacity))
    }
    .ignoresSafeArea()
  }

  private func dismiss() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
      isPresented = false
      dragOffset = 0
    }
  }

  @ViewBuilder
  private func settingRow(
    icon: String,
    iconColor: Color,
    label: String,
    description: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
          .font(.system(size: 14))
          .foregroundColor(iconColor)
          .frame(width: 24)
        Text(label)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.white)
        Spacer()
        Text(description)
          .font(.system(size: 13))
          .foregroundColor(.white.opacity(0.5))
      }
    }
  }

  private var hermesStatusColor: Color {
    switch geminiVM.hermesConnectionState {
    case .connected: return .green
    case .checking: return .yellow
    case .unreachable: return .red
    case .notConfigured: return .gray
    }
  }

  private var hermesStatusDescription: String {
    switch geminiVM.hermesConnectionState {
    case .connected: return "Connected to Hermes agent gateway"
    case .checking: return "Checking Hermes connection..."
    case .unreachable(let err): return "Unreachable: \(err)"
    case .notConfigured: return "Not configured — set up in Settings"
    }
  }
}
