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
  @Published var activeToolCall: ActiveToolCallInfo? = nil
  private(set) var latestFrame: UIImage? = nil
  @Published var hermesConnectionState: HermesConnectionState = .notConfigured
  @Published var isSpeakerOn: Bool = false
  let geminiService = GeminiLiveService()
  let hermesBridge = HermesBridge()
  let wakeWordDetector = WakeWordDetector()
  private var toolCallRouter: HermesToolCallRouter?
  private let audioManager = AudioManager()
  private var lastVideoFrameTime: Date = .distantPast
  private var lastSentThumbnail: [UInt8]?
  private var stateObservation: Task<Void, Never>?

  var streamingMode: StreamingMode = .glasses

  init() {
    wakeWordDetector.onWakeWordDetected = { [weak self] in
      Task { @MainActor in
        guard let self = self, !self.isGeminiActive else { return }
        await self.startSession()
      }
    }
    wakeWordDetector.onStopDetected = { [weak self] in
      Task { @MainActor in
        guard let self = self, self.isGeminiActive else { return }
        self.handleStopCommand(isExit: false)
      }
    }
    wakeWordDetector.onStopVideoDetected = { [weak self] in
      Task { @MainActor in
        guard let self = self, self.isGeminiActive else { return }
        self.handleStopCommand(isExit: true)
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
        let lower = text.lowercased()
        // Real-time stop command interception via word boundaries
        if self.wakeWordDetector.matchesStopVideo(text: lower) {
          NSLog("[Gemini] Stop video command detected — exiting session")
          self.stopSession()
          return
        } else if self.wakeWordDetector.matchesStop(text: lower) {
          NSLog("[Gemini] Stop command detected — silencing audio playback, staying live")
          self.audioManager.stopPlayback()
          self.geminiService.interruptPlayback()
          self.isModelSpeaking = false
          return
        }

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
            chatHistoryManager: historyManager,
            snapshot: self.latestFrame
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
        self.activeToolCall = self.hermesBridge.activeToolCall
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

    // Trigger GPS location update for spatial context
    LocationManager.shared.requestLocation()

    // Hermes Handshake: verify Cloudflare tunnel & pre-fetch session status in background
    Task { [weak self] in
      guard let self else { return }
      await self.hermesBridge.checkConnection()
      if let summary = await self.hermesBridge.fetchQuickStatusSummary() {
        NSLog("[Gemini] Hermes initial status handshake: %@", summary)
      }
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

  func handleStopCommand(isExit: Bool) {
    if isExit {
      NSLog("[Gemini] handleStopCommand: full exit")
      stopSession()
    } else {
      NSLog("[Gemini] handleStopCommand: silence audio, stay live")
      audioManager.stopPlayback()
      geminiService.interruptPlayback()
      isModelSpeaking = false
    }
  }

  func sendVideoFrameIfThrottled(image: UIImage) {
    guard isGeminiActive, connectionState == .ready else { return }
    let now = Date()
    let currentThumb = FrameChange.grayThumbnail(image)
    let isNew = lastSentThumbnail.map { FrameChange.isNewScene(currentThumb, $0) } ?? true

    // When the user turns their head or the scene changes significantly,
    // bypass the long 1s throttle interval (use 250ms floor) so Gemini gets fresh eyes immediately!
    let elapsed = now.timeIntervalSince(lastVideoFrameTime)
    let minInterval = isNew ? 0.25 : GeminiConfig.videoFrameInterval

    guard elapsed >= minInterval else { return }

    if isNew && lastSentThumbnail != nil {
      NSLog("[FrameChange] New scene detected (diff: %.3f) — sending fresh eyes frame",
            FrameChange.difference(currentThumb, lastSentThumbnail ?? []))
    }

    lastVideoFrameTime = now
    lastSentThumbnail = currentThumb
    latestFrame = image
    TemporalVisualMemory.shared.recordFrameIfSignificant(image, locationContext: LocationManager.shared.contextString)
    geminiService.sendVideoFrame(image: image)
  }

  func sendTextMessage(_ text: String, currentFrame: UIImage? = nil) {
    guard isGeminiActive, connectionState == .ready else { return }
    // Visual context injection for text questions: send freshest frame immediately
    if let frame = currentFrame {
      lastSentThumbnail = FrameChange.grayThumbnail(frame)
      geminiService.sendVideoFrame(image: frame)
    }
    geminiService.sendTextMessage(text)
    
    // Update the message history immediately for text commands
    Task { @MainActor in
      let msg = ChatMessage(role: .user, text: text)
      self.messages.append(msg)
      self.userTranscript = ""
    }
  }
}
