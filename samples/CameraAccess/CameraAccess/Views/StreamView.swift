/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamView.swift
//
// Main UI for video streaming. Extended with Gemini Live AI assistant.
//

import MWDATCore
import SwiftUI

struct StreamView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var wearablesVM: WearablesViewModel
  @ObservedObject var geminiVM: GeminiSessionViewModel
  @ObservedObject var webrtcVM: WebRTCSessionViewModel
  @Binding var isMenuOpen: Bool
  @State private var showPiP = true
  @State private var pipPosition = CGPoint(x: UIScreen.main.bounds.width - 90, y: 150)
  @State private var messageInput: String = ""

  var body: some View {
    ZStack {
      backgroundLayers

      VStack(spacing: 0) {
        topBar
        chatHistory
        Spacer()
        bottomControls
      }

      floatingPiP
      pipToggleButton
    }
    .onDisappear { cleanupSessions() }
    .sheet(isPresented: $viewModel.showPhotoPreview) { photoPreviewSheet }
    .alert("AI Assistant", isPresented: alertBinding(for: $geminiVM.errorMessage)) {
      Button("OK") { geminiVM.errorMessage = nil }
    } message: { Text(geminiVM.errorMessage ?? "") }
    .alert("Live Stream", isPresented: alertBinding(for: $webrtcVM.errorMessage)) {
      Button("OK") { webrtcVM.errorMessage = nil }
    } message: { Text(webrtcVM.errorMessage ?? "") }
  }

  // MARK: - Subviews

  private var backgroundLayers: some View {
    ZStack {
      AnimatedBackground()
      ParticleEffect(particleCount: 30).opacity(0.5)
    }
  }

  /// Top bar: hamburger grande a la izquierda, + a la derecha, status al centro
  private var topBar: some View {
    HStack(spacing: 8) {
      // Hamburger menu — más grande, siempre arriba a la izquierda
      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          isMenuOpen.toggle()
        }
      } label: {
        Image(systemName: "line.horizontal.3")
          .foregroundColor(.white)
          .font(.system(size: 20, weight: .medium))
          .padding(10)
          .background(
            Circle()
              .fill(.ultraThinMaterial)
              .overlay(Circle().stroke(DS.Color.borderCyan, lineWidth: 1))
          )
      }
      .buttonStyle(.plain)

      // Stop button (only when active)
      if viewModel.isStreaming || geminiVM.isGeminiActive {
        Button {
          geminiVM.stopSession()
          Task { await viewModel.stopSession() }
        } label: {
          Image(systemName: "stop.circle.fill")
            .foregroundColor(.red)
            .font(.system(size: 22))
            .padding(6)
        }
        .buttonStyle(.plain)
      }

      Spacer()

      // Status dot
      if geminiVM.isGeminiActive {
        GeminiStatusBar(geminiVM: geminiVM)
      } else if viewModel.isStreaming {
        Text("Streaming")
          .font(.caption)
          .foregroundColor(.red.opacity(0.8))
      }

      Spacer()

      // + New chat button (top right)
      Button {
        // Save current session and start new one
        let historyManager = ChatHistoryManager.shared
        if let session = historyManager.currentSession, !session.messages.isEmpty {
          historyManager.saveSession(session)
        }
        historyManager.startNewSession(title: "Nueva Charla")
        geminiVM.messages = []
        geminiVM.userTranscript = ""
        geminiVM.aiTranscript = ""
      } label: {
        Image(systemName: "plus.circle.fill")
          .foregroundColor(DS.Color.accentCyan)
          .font(.system(size: 22))
          .neonCyan(radius: 6, intensity: 0.4)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal)
    .padding(.top, 8)
  }

  private var chatHistory: some View {
    ScrollViewReader { proxy in
      ScrollView {
        if SettingsManager.shared.showTranscripts {
          LazyVStack(spacing: 12) {
            ForEach(geminiVM.messages) { message in
              ChatMessageBubble(text: message.text, isUser: message.role == .user)
            }

            if !geminiVM.userTranscript.isEmpty {
              ChatMessageBubble(text: geminiVM.userTranscript, isUser: true)
            }
            if !geminiVM.aiTranscript.isEmpty {
              ChatMessageBubble(text: geminiVM.aiTranscript, isUser: false)
            }
            Color.clear.frame(height: 1).id("bottomSpacer")
          }
          .padding()
        }
      }
      .onChange(of: geminiVM.messages.count) {
          withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
      }
      .onChange(of: geminiVM.userTranscript) {
          withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
      }
      .onChange(of: geminiVM.aiTranscript) {
          withAnimation { proxy.scrollTo("bottomSpacer", anchor: .bottom) }
      }
    }
  }

  private var bottomControls: some View {
    VStack(spacing: 8) {
        if geminiVM.isGeminiActive {
            if geminiVM.toolCallStatus != .idle {
                ToolCallStatusView(status: geminiVM.toolCallStatus)
            }

            // Speaking indicator minimal (sin wave flotante)
            if geminiVM.isModelSpeaking {
                SpeakingIndicator()
                    .glassmorphismPill()
            }
        }

        ControlsView(viewModel: viewModel, geminiVM: geminiVM, webrtcVM: webrtcVM, messageInput: $messageInput)
    }
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var floatingPiP: some View {
    if showPiP {
        if webrtcVM.isActive && webrtcVM.connectionState == .connected {
            DraggablePiPView(position: $pipPosition, isShowing: $showPiP) {
                PiPVideoView(
                    localFrame: viewModel.currentVideoFrame,
                    remoteVideoTrack: webrtcVM.remoteVideoTrack,
                    hasRemoteVideo: webrtcVM.hasRemoteVideo
                )
            }
        } else if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
            DraggablePiPView(position: $pipPosition, isShowing: $showPiP) {
                Image(uiImage: videoFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        }
    }
  }

  @ViewBuilder
  private var pipToggleButton: some View {
    if !showPiP && ((viewModel.currentVideoFrame != nil && viewModel.hasReceivedFirstFrame) || (webrtcVM.isActive && webrtcVM.connectionState == .connected)) {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { withAnimation { showPiP = true } }) {
                    Image(systemName: "video.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(.ultraThinMaterial))
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .padding()
            }
        }
    }
  }

  @ViewBuilder
  private var photoPreviewSheet: some View {
    if let photo = viewModel.capturedPhoto {
      PhotoPreviewView(photo: photo, onDismiss: { viewModel.dismissPhotoPreview() })
    }
  }

  private func alertBinding(for message: Binding<String?>) -> Binding<Bool> {
    Binding(
      get: { message.wrappedValue != nil },
      set: { if !$0 { message.wrappedValue = nil } }
    )
  }

  private func cleanupSessions() {
    Task {
      if viewModel.streamingStatus != .stopped { await viewModel.stopSession() }
      if geminiVM.isGeminiActive { geminiVM.stopSession() }
      if webrtcVM.isActive { webrtcVM.stopSession() }
    }
  }
}

// MARK: - ControlsView (bottom input area)

struct ControlsView: View {
  @ObservedObject var viewModel: StreamSessionViewModel
  @ObservedObject var geminiVM: GeminiSessionViewModel
  @ObservedObject var webrtcVM: WebRTCSessionViewModel
  @Binding var messageInput: String

  private var micColor: Color {
      if webrtcVM.isActive { return .gray }
      if !geminiVM.isGeminiActive { return .gray }

      switch geminiVM.connectionState {
      case .connecting: return .orange
      case .ready:
          if geminiVM.isModelSpeaking {
              return .green
          } else {
              return geminiVM.toolCallStatus != .idle ? DS.Color.accentPurple : DS.Color.accentCyan
          }
      default: return .gray
      }
  }

  var body: some View {
    VStack(spacing: 16) {
      HStack(spacing: 12) {
        // Text Input Box (left)
        HStack {
            TextField("Escribí un mensaje...", text: $messageInput)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .submitLabel(.send)
                .onSubmit { sendMessage() }

            if !messageInput.isEmpty {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(DS.Color.accentCyan)
                        .font(.system(size: 28))
                        .padding(.trailing, 6)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(DS.Color.borderCyan, lineWidth: 1))
        )
        .animation(.spring(), value: messageInput.isEmpty)

        // Mic button — derecha, con neon cyan
        Button(action: {
          let generator = UIImpactFeedbackGenerator(style: .medium)
          generator.impactOccurred()
          Task {
            if geminiVM.isGeminiActive {
              geminiVM.stopSession()
            } else {
              await geminiVM.startSession()
            }
          }
        }) {
            ZStack {
                Circle()
                    .fill(micColor)
                    .frame(width: 48, height: 48)

                Image(systemName: geminiVM.isGeminiActive ? "waveform" : "mic.fill")
                    .foregroundColor(.white)
                    .font(.title3)
            }
            .overlay(
                Circle()
                    .stroke(DS.Color.accentCyan.opacity(0.5), lineWidth: 1.5)
            )
            .neonCyan(radius: 10, intensity: micColor == DS.Color.accentCyan ? 0.6 : 0.2)
        }
        .opacity(webrtcVM.isActive ? 0.4 : 1.0)
        .disabled(webrtcVM.isActive)
      }
      .padding(.horizontal)
    }
  }

  private func sendMessage() {
      let text = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { return }
      messageInput = ""
      geminiVM.sendTextMessage(text)
  }
}

// MARK: - Draggable PiP

struct DraggablePiPView<Content: View>: View {
    @Binding var position: CGPoint
    @Binding var isShowing: Bool
    let content: Content

    init(position: Binding<CGPoint>, isShowing: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._position = position
        self._isShowing = isShowing
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .frame(width: 120, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            Button(action: { withAnimation { isShowing = false } }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(6)
        }
        .position(position)
        .gesture(
            DragGesture()
                .onChanged { value in position = value.location }
                .onEnded { value in
                    let screen = UIScreen.main.bounds
                    let newX = max(60, min(value.location.x, screen.width - 60))
                    let newY = max(100, min(value.location.y, screen.height - 100))
                    withAnimation(.spring()) { position = CGPoint(x: newX, y: newY) }
                }
        )
    }
}
