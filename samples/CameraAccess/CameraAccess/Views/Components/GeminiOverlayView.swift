import SwiftUI
import Foundation

// MARK: - GeminiStatusBar (Rediseñada: punto único expandible)
// Muestra un solo punto de estado global. Al tocarlo, despliega detalles.

struct GeminiStatusBar: View {
  @ObservedObject var geminiVM: GeminiSessionViewModel
  @State private var isExpanded = false

  var body: some View {
    let state = overallState

    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        isExpanded.toggle()
      }
    } label: {
      HStack(spacing: 8) {
        // Círculo de estado principal
        Circle()
          .fill(state.color)
          .frame(width: 10, height: 10)
          .overlay(
            Circle()
              .stroke(state.color.opacity(0.3), lineWidth: 3)
              .scaleEffect(state.isPulsing ? 1.5 : 1.0)
              .opacity(state.isPulsing ? 0 : 0.6)
          )

        if isExpanded {
          // Detalles expandidos
          HStack(spacing: 10) {
            // Gemini
            HStack(spacing: 4) {
              Circle().fill(geminiColor).frame(width: 6, height: 6)
              Text(geminiLetter)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            // Hermes
            HStack(spacing: 4) {
              Circle().fill(hermesColor).frame(width: 6, height: 6)
              Text(hermesLetter)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            // Speaker toggle
            Button {
              geminiVM.toggleSpeaker()
            } label: {
              Image(systemName: geminiVM.isSpeakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 10))
                .foregroundColor(geminiVM.isSpeakerOn ? .cyan : .gray)
            }
            .buttonStyle(.plain)

            // Model speaking indicator
            if geminiVM.isModelSpeaking {
              Image(systemName: "waveform")
                .font(.system(size: 10))
                .foregroundColor(.cyan)
            }
          }
          .transition(.opacity.combined(with: .move(edge: .leading)))
        }
      }
      .padding(.horizontal, isExpanded ? 12 : 10)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(.ultraThinMaterial)
          .overlay(
            Capsule()
              .stroke(state.color.opacity(0.3), lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }

  // Estado global: peor estado entre Gemini + Hermes
  private var overallState: (color: Color, isPulsing: Bool) {
    // Prioridad: rojo > amarillo > verde > gris
    let gemState = (geminiVM.connectionState, geminiVM.hermesConnectionState)

    if case .error = gemState.0 { return (.red, false) }
    if case .unreachable = gemState.1 { return (.red, false) }
    if case .connecting = gemState.0 { return (.yellow, true) }
    if case .checking = gemState.1 { return (.yellow, true) }
    if case .settingUp = gemState.0 { return (.yellow, true) }
    if case .ready = gemState.0, case .connected = gemState.1 { return (.green, false) }
    if case .ready = gemState.0 { return (.green, false) }
    return (.gray, false)
  }

  private var geminiColor: Color {
    switch geminiVM.connectionState {
    case .ready: return .green
    case .connecting, .settingUp: return .yellow
    case .error: return .red
    case .disconnected: return .gray
    }
  }

  private var geminiLetter: String {
    switch geminiVM.connectionState {
    case .ready: return "G"
    case .connecting, .settingUp: return "~"
    case .error: return "!"
    case .disconnected: return "-"
    }
  }

  private var hermesColor: Color {
    switch geminiVM.hermesConnectionState {
    case .connected: return .green
    case .checking: return .yellow
    case .unreachable: return .red
    case .notConfigured: return .gray
    }
  }

  private var hermesLetter: String {
    switch geminiVM.hermesConnectionState {
    case .connected: return "H"
    case .checking: return "~"
    case .unreachable: return "!"
    case .notConfigured: return "-"
    }
  }
}

// MARK: - ToolCallStatusView (iconos + texto corto)

struct ToolCallStatusView: View {
  let status: ToolCallStatus

  var body: some View {
    if status != .idle {
      HStack(spacing: 8) {
 switch status {
        case .executing(let name):
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            .scaleEffect(0.7)
          Image(systemName: ToolIcon.icon(for: name))
            .font(.system(size: 14))
            .foregroundColor(.cyan)
          Text(ToolIcon.shortName(for: name))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)

        case .completed(let name):
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.system(size: 14))
          Image(systemName: ToolIcon.icon(for: name))
            .font(.system(size: 12))
            .foregroundColor(.green.opacity(0.8))
          Text(ToolIcon.shortName(for: name))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.green)

        case .failed(let name, let error):
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundColor(.red)
            .font(.system(size: 14))
          Image(systemName: ToolIcon.icon(for: name))
            .font(.system(size: 12))
            .foregroundColor(.red.opacity(0.8))
          Text(shortError(error))
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.red)
            .lineLimit(1)

        case .cancelled(let name):
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.yellow)
            .font(.system(size: 14))
          Text(ToolIcon.shortName(for: name))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.yellow)

        case .idle:
          EmptyView()
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(.ultraThinMaterial)
          .overlay(
            Capsule()
              .stroke(Color.white.opacity(0.1), lineWidth: 1)
          )
      )
      .transition(.scale.combined(with: .opacity))
    }
  }

  private func shortError(_ error: String) -> String {
    if error.hasPrefix("HTTP") { return error }
    if error.count > 30 { return String(error.prefix(28)) + "…" }
    return error
  }
}

// MARK: - StatusPill (mantenido para compatibilidad, pero ya no se usa directamente)

struct StatusPill: View {
  let color: Color
  let text: String
  var isPulsing: Bool = false

  @State private var pulseAnim = false

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
        .overlay(
          Circle()
            .stroke(color.opacity(0.4), lineWidth: 3)
            .scaleEffect(isPulsing && pulseAnim ? 1.6 : 1.0)
            .opacity(isPulsing && pulseAnim ? 0 : 0.6)
        )

      Text(text)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.black.opacity(0.6))
    .cornerRadius(16)
    .onAppear {
      guard isPulsing else { return }
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
        pulseAnim = true
      }
    }
    .onChange(of: isPulsing) {
      if isPulsing {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
          pulseAnim = true
        }
      } else {
        pulseAnim = false
      }
    }
  }
}

// MARK: - Legacy views (mantenidos para compatibilidad, no se renderizan en la nueva UI)

struct TranscriptView: View {
  let userText: String
  let aiText: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !userText.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "person.fill")
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.5))
          Text(userText)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.7))
        }
      }
      if !aiText.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "sparkles")
            .font(.system(size: 10))
            .foregroundColor(.purple.opacity(0.7))
          Text(aiText)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Color.black.opacity(0.6))
    .cornerRadius(12)
  }
}

struct SpeakingIndicator: View {
  @State private var animating = false

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<4, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1.5)
          .fill(
            LinearGradient(
              colors: [Color.cyan, Color.purple],
              startPoint: .bottom,
              endPoint: .top
            )
          )
          .frame(width: 3, height: animating ? height(for: index) : 4)
          .animation(
            .easeInOut(duration: 0.4)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.12),
            value: animating
          )
      }
    }
    .onAppear { animating = true }
    .onDisappear { animating = false }
  }

  private func height(for index: Int) -> CGFloat {
    let heights: [CGFloat] = [12, 20, 16, 10]
    return heights[index % heights.count]
  }
}

// MARK: - Voice Waveform Animation

struct VoiceWaveformView: View {
  let isActive: Bool

  @State private var phase: Double = 0
  private let barCount = 24
  private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      let totalWidth = geometry.size.width
      let barSpacing: CGFloat = 3
      let barWidth = max(3, (totalWidth - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount))

      HStack(spacing: barSpacing) {
        ForEach(0..<barCount, id: \.self) { index in
          RoundedRectangle(cornerRadius: barWidth / 2)
            .fill(
              LinearGradient(
                colors: [Color.cyan.opacity(0.8), Color.purple.opacity(0.9)],
                startPoint: .bottom,
                endPoint: .top
              )
            )
            .frame(width: barWidth, height: isActive ? barHeight(for: index) : 2)
            .animation(.interpolatingSpring(stiffness: 80, damping: 12), value: phase)
        }
      }
      .frame(maxHeight: .infinity, alignment: .center)
    }
    .frame(height: 48)
    .padding(.horizontal, 24)
    .onReceive(timer) { _ in
      guard isActive else { return }
      withAnimation(.linear(duration: 0.1)) {
        phase += 0.15
      }
    }
  }

  private func barHeight(for index: Int) -> CGFloat {
    guard isActive else { return 2 }
    let frequency = 0.4
    let amplitude: CGFloat = 18
    let offset: CGFloat = 6
    let normalizedIndex = CGFloat(index) / CGFloat(barCount)
    let value = Darwin.sin(Double(normalizedIndex) * .pi * 2 * frequency + Double(phase) * 2) +
                Darwin.sin(Double(normalizedIndex) * .pi * 3 + Double(phase) * 1.5) * 0.5
    return max(3, amplitude * (1 + value * 0.6) + offset)
  }
}

// MARK: - ConnectionHealthIndicator (eliminado de la UI, mantenido para compatibilidad)

struct ConnectionHealthIndicator: View {
  let latencyMs: Int?
  let connectionState: HermesConnectionState

  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(indicatorColor)
        .frame(width: 6, height: 6)

      if let latency = latencyMs {
        Text("\\(latency)ms")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundColor(indicatorColor)
      } else if case .connected = connectionState {
        Text("~ms")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundColor(.green)
      } else {
        Text(dotText)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(indicatorColor)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Capsule().fill(Color.black.opacity(0.5)))
  }

  private var indicatorColor: Color {
    if let latency = latencyMs {
      if latency < 500 { return .green }
      if latency < 2000 { return .yellow }
      return .red
    }
    switch connectionState {
    case .connected: return .green
    case .checking: return .yellow
    case .unreachable: return .red
    case .notConfigured: return .gray
    }
  }

  private var dotText: String {
    switch connectionState {
    case .notConfigured: return "N/A"
    case .checking: return "..."
    case .unreachable: return "ERR"
    case .connected: return "OK"
    }
  }
}
