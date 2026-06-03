import SwiftUI

struct WebRTCStatusBar: View {
  @ObservedObject var webrtcVM: WebRTCSessionViewModel

  var body: some View {
    HStack(spacing: 8) {
      StatusPill(color: statusColor, text: statusText)

      if !webrtcVM.roomCode.isEmpty {
        RoomCodePill(code: webrtcVM.roomCode)
      }

      if webrtcVM.connectionState == .connected {
        // Mute Toggle
        Button(action: { webrtcVM.toggleMute() }) {
          HStack(spacing: 4) {
            Image(systemName: webrtcVM.isMuted ? "mic.slash.fill" : "mic.fill")
              .font(.system(size: 10))
            Text(webrtcVM.isMuted ? "Muted" : "Mic On")
              .font(.system(size: 12, weight: .bold))
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(webrtcVM.isMuted ? Color.red : Color.green)
          .foregroundColor(.white)
          .cornerRadius(16)
        }

        // Speaker Toggle
        Button(action: { webrtcVM.toggleSpeaker() }) {
          Image(systemName: webrtcVM.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.1")
            .font(.system(size: 12, weight: .bold))
            .padding(8)
            .background(webrtcVM.isSpeakerOn ? Color.blue : Color.black.opacity(0.6))
            .foregroundColor(.white)
            .clipShape(Circle())
        }
      }
    }
  }

  private var statusColor: Color {
    switch webrtcVM.connectionState {
    case .connected: return .green
    case .connecting, .waitingForPeer: return .yellow
    case .backgrounded: return .orange
    case .error: return .red
    case .disconnected: return .gray
    }
  }

  private var statusText: String {
    switch webrtcVM.connectionState {
    case .connected: return "Live"
    case .connecting: return "Connecting..."
    case .waitingForPeer: return "Waiting..."
    case .backgrounded: return "Paused"
    case .error: return "Error"
    case .disconnected: return "Off"
    }
  }
}

struct RoomCodePill: View {
  let code: String
  @State private var showCopied: Bool = false

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
        .font(.system(size: 10))
        .foregroundColor(showCopied ? .green : .white)
      Text(showCopied ? "Copied" : code)
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.black.opacity(0.6))
    .cornerRadius(16)
    .onTapGesture {
      UIPasteboard.general.string = code
      showCopied = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        showCopied = false
      }
    }
  }
}
