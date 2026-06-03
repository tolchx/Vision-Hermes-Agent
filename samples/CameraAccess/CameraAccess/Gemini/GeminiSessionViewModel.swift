import Foundation
import SwiftUI
import AVFoundation

@MainActor
class GeminiSessionViewModel: ObservableObject {
  @Published var isGeminiActive: Bool = false
  @Published var connectionState: GeminiConnectionState = .disconnected
  @Published var isModelSpeaking: Bool = false
  @Published var errorMessage: String?
  @Published var userTranscript: String = ""
  @Published var aiTranscript: String = ""
  @Published var messages: [ChatMessage] = []
  @Published var currentSessionId = UUID()
  @Published var toolCallStatus: ToolCallStatus = .idle
  @Published var hermesConnectionState: HermesConnectionState = .notConfigured
  @Published var isSpeakerOn: Bool = false
  let geminiService = GeminiLiveService()
  let hermesBridge = HermesBridge()
  let wakeWordDetector = WakeWordDetector()
  private var toolCallRouter: HermesToolCallRouter?
  private let audioManager = AudioManager()
  private var lastVideoFrameTime: Date = .distantPast
  private var stateObservation: Task<Void, Never>?

  var streamingMode: StreamingMode = .glasses

  init() {
    wakeWordDetector.onWakeWordDetected = { [weak self] in
      Task { @MainActor in
        guard let self = self, !self.isGeminiActive else { return }
        await self.startSession()
      }
    }
  }

  func startWakeWordDetection() {
    guard SettingsManager.shared.enableWakeWord else { return }
    Task { [weak self] in
      guard let self = self else { return }
      let authorized = await wakeWordDetector.requestAuthorization()
      if authorized {
        wakeWordDetector.startListening()
      }
    }
  }

  func stopWakeWordDetection() {
    wakeWordDetector.stopListening()
  }

  func startSession() async {
    guard !isGeminiActive else { return }

    guard GeminiConfig.isConfigured else {
      errorMessage = "Gemini API key not configured. Open GeminiConfig.swift and replace YOUR_GEMINI_API_KEY with your key from https://aistudio.google.com/apikey"
      return
    }

    isGeminiActive = true

    // Wire audio callbacks
    audioManager.onAudioCaptured = { [weak self] data in
      guard let self else { return }
      Task { @MainActor in
        // iPhone mode: mute mic while model speaks to prevent echo feedback
        // (loudspeaker + co-located mic overwhelms iOS echo cancellation)
        if self.streamingMode == .iPhone && self.geminiService.isModelSpeaking { return }
        self.geminiService.sendAudio(data: data)
      }
    }

    geminiService.onAudioReceived = { [weak self] data in
      self?.audioManager.playAudio(data: data)
    }

    geminiService.onInterrupted = { [weak self] in
      self?.audioManager.stopPlayback()
    }

    geminiService.onTurnComplete = { [weak self] in
      guard let self else { return }
      Task { @MainActor in
        let historyManager = ChatHistoryManager.shared
        // When a turn is complete, if there's an AI transcript, push it as a completed message
        if !self.aiTranscript.isEmpty {
          let msg = ChatMessage(role: .ai, text: self.aiTranscript)
          self.messages.append(msg)
          historyManager.addMessage(role: .ai, text: self.aiTranscript)
          self.aiTranscript = ""
        }
        self.userTranscript = ""
      }
    }

    geminiService.onInputTranscription = { [weak self] text in
      guard let self else { return }
      Task { @MainActor in
        // For real-time streaming, we keep userTranscript for display
        // but when it's "committed" (usually by the model starting to speak or turn complete), we save it
        self.userTranscript += text
      }
    }

    geminiService.onOutputTranscription = { [weak self] text in
      guard let self else { return }
      Task { @MainActor in
        let historyManager = ChatHistoryManager.shared
        // If this is the start of a response and we have a user transcript, commit the user message
        if self.aiTranscript.isEmpty && !self.userTranscript.isEmpty {
          let userMsg = ChatMessage(role: .user, text: self.userTranscript)
          self.messages.append(userMsg)
          historyManager.addMessage(role: .user, text: self.userTranscript)
          self.userTranscript = ""
        }
        self.aiTranscript += text
      }
    }

    // Handle unexpected disconnection
    geminiService.onDisconnected = { [weak self] reason in
      guard let self else { return }
      Task { @MainActor in
        guard self.isGeminiActive else { return }
        self.stopSession()
        self.errorMessage = "Connection lost: \(reason ?? "Unknown error")"
      }
    }

    // Check Hermes connectivity and start fresh session
    await hermesBridge.checkConnection()
    hermesBridge.resetSession()

    // Wire tool call handling
    toolCallRouter = HermesToolCallRouter(bridge: hermesBridge)
    let historyManager = ChatHistoryManager.shared

    // Start a new session in ChatHistoryManager
    historyManager.startNewSession(title: "VisionHermes Chat")

    geminiService.onToolCall = { [weak self] toolCall in
      guard let self else { return }
      Task { @MainActor in
        for call in toolCall.functionCalls {
          self.toolCallRouter?.handleToolCall(call,
            chatHistoryManager: historyManager
          ) { [weak self] response in
            self?.geminiService.sendToolResponse(response)
          }
        }
      }
    }

    geminiService.onToolCallCancellation = { [weak self] cancellation in
      guard let self else { return }
      Task { @MainActor in
        self.toolCallRouter?.cancelToolCalls(ids: cancellation.ids)
      }
    }

    // Observe service state
    stateObservation = Task { [weak self] in
      guard let self else { return }
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        guard !Task.isCancelled else { break }
        self.connectionState = self.geminiService.connectionState
        self.isModelSpeaking = self.geminiService.isModelSpeaking
        self.toolCallStatus = self.hermesBridge.lastToolCallStatus
        self.hermesConnectionState = self.hermesBridge.connectionState
      }
    }

    // Start fresh session ID
    currentSessionId = UUID()
    messages = []
    
    // Setup audio
    do {
      try audioManager.setupAudioSession(useIPhoneMode: streamingMode == .iPhone)
    } catch {
      errorMessage = "Audio setup failed: \(error.localizedDescription)"
      isGeminiActive = false
      return
    }

    // Connect to Gemini and wait for setupComplete
    let setupOk = await geminiService.connect()

    if !setupOk {
      let msg: String
      if case .error(let err) = geminiService.connectionState {
        msg = err
      } else {
        msg = "Failed to connect to Gemini"
      }
      errorMessage = msg
      geminiService.disconnect()
      stateObservation?.cancel()
      stateObservation = nil
      isGeminiActive = false
      connectionState = .disconnected
      return
    }

    // Start mic capture
    do {
      try audioManager.startCapture()
    } catch {
      errorMessage = "Mic capture failed: \(error.localizedDescription)"
      geminiService.disconnect()
      stateObservation?.cancel()
      stateObservation = nil
      isGeminiActive = false
      connectionState = .disconnected
      return
    }
  }

  func stopSession() {
    // Save session before clearing
    if !messages.isEmpty {
      let title = messages.first(where: { $0.role == .user })?.text.prefix(30) ?? "New Chat"
      let session = ChatSession(id: currentSessionId, title: String(title), messages: messages)
      ChatHistoryManager.shared.saveSession(session)
    }
    
    toolCallRouter?.cancelAll()
    toolCallRouter = nil
    audioManager.stopCapture()
    geminiService.disconnect()
    stateObservation?.cancel()
    stateObservation = nil
    isGeminiActive = false
    connectionState = .disconnected
    isModelSpeaking = false
    isSpeakerOn = false
    userTranscript = ""
    aiTranscript = ""
    messages = []
    toolCallStatus = .idle
  }

  func toggleSpeaker() {
    isSpeakerOn.toggle()
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .defaultToSpeaker])
      try session.overrideOutputAudioPort(isSpeakerOn ? .speaker : .none)
      try session.setActive(true)
    } catch {
      NSLog("[Audio] Error toggling speaker: %@", error.localizedDescription)
    }
  }

  func sendVideoFrameIfThrottled(image: UIImage) {
    guard isGeminiActive, connectionState == .ready else { return }
    let now = Date()
    guard now.timeIntervalSince(lastVideoFrameTime) >= GeminiConfig.videoFrameInterval else { return }
    lastVideoFrameTime = now
    geminiService.sendVideoFrame(image: image)
  }

  func sendTextMessage(_ text: String) {
    guard isGeminiActive, connectionState == .ready else { return }
    geminiService.sendTextMessage(text)
    
    // Update the message history immediately for text commands
    Task { @MainActor in
      let msg = ChatMessage(role: .user, text: text)
      self.messages.append(msg)
      self.userTranscript = ""
    }
  }

}
