import Foundation

final class SettingsManager: ObservableObject {
  static let shared = SettingsManager()

  private let defaults = UserDefaults.standard

  private enum Key: String {
    case geminiAPIKey
    case hermesHost
    case hermesPort
    case hermesHookToken
    case hermesGatewayToken
    case geminiSystemPrompt
    case webrtcSignalingURL
    case activeAIBackend
    case autoReconnect
    case showTranscripts
    case enableWakeWord
    case wakePhrase
    case autoEndTimeout
    case ttsVoice
    case activationSound
    case offlineModelURL
    case isOfflineModelInstalled
    case memories
  }

  private init() {}

  // MARK: - Gemini

  var geminiAPIKey: String {
    get { defaults.string(forKey: Key.geminiAPIKey.rawValue) ?? Secrets.geminiAPIKey }
    set { defaults.set(newValue, forKey: Key.geminiAPIKey.rawValue) }
  }

  var geminiSystemPrompt: String {
    get { defaults.string(forKey: Key.geminiSystemPrompt.rawValue) ?? GeminiConfig.defaultSystemInstruction }
    set { defaults.set(newValue, forKey: Key.geminiSystemPrompt.rawValue) }
  }

  // MARK: - Hermes

  var hermesHost: String {
    get { defaults.string(forKey: Key.hermesHost.rawValue) ?? Secrets.hermesHost }
    set { defaults.set(newValue, forKey: Key.hermesHost.rawValue) }
  }

  var hermesPort: Int {
    get {
      let stored = defaults.integer(forKey: Key.hermesPort.rawValue)
      return stored != 0 ? stored : Secrets.hermesPort
    }
    set { defaults.set(newValue, forKey: Key.hermesPort.rawValue) }
  }

  var hermesHookToken: String {
    get { defaults.string(forKey: Key.hermesHookToken.rawValue) ?? Secrets.hermesHookToken }
    set { defaults.set(newValue, forKey: Key.hermesHookToken.rawValue) }
  }

  var hermesGatewayToken: String {
    get { defaults.string(forKey: Key.hermesGatewayToken.rawValue) ?? Secrets.hermesGatewayToken }
    set { defaults.set(newValue, forKey: Key.hermesGatewayToken.rawValue) }
  }

  // MARK: - WebRTC

  var webrtcSignalingURL: String {
    get { defaults.string(forKey: Key.webrtcSignalingURL.rawValue) ?? Secrets.webrtcSignalingURL }
    set { defaults.set(newValue, forKey: Key.webrtcSignalingURL.rawValue) }
  }

  var activeAIBackend: String {
    get { defaults.string(forKey: Key.activeAIBackend.rawValue) ?? "Gemini Live" }
    set { defaults.set(newValue, forKey: Key.activeAIBackend.rawValue) }
  }

  var autoReconnect: Bool {
    get { defaults.object(forKey: Key.autoReconnect.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.autoReconnect.rawValue) }
  }

  var showTranscripts: Bool {
    get { defaults.object(forKey: Key.showTranscripts.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.showTranscripts.rawValue) }
  }

  var enableWakeWord: Bool {
    get { defaults.object(forKey: Key.enableWakeWord.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.enableWakeWord.rawValue) }
  }

  var wakePhrase: String {
    get { defaults.string(forKey: Key.wakePhrase.rawValue) ?? "Ok Vision" }
    set { defaults.set(newValue, forKey: Key.wakePhrase.rawValue) }
  }

  var autoEndTimeout: Double {
    get {
        let stored = defaults.double(forKey: Key.autoEndTimeout.rawValue)
        return stored != 0 ? stored : 30.0
    }
    set { defaults.set(newValue, forKey: Key.autoEndTimeout.rawValue) }
  }

  var ttsVoice: String {
    get { defaults.string(forKey: Key.ttsVoice.rawValue) ?? "System Default" }
    set { defaults.set(newValue, forKey: Key.ttsVoice.rawValue) }
  }

  var activationSound: Bool {
    get { defaults.object(forKey: Key.activationSound.rawValue) as? Bool ?? true }
    set { defaults.set(newValue, forKey: Key.activationSound.rawValue) }
  }

  var offlineModelURL: String {
    get { defaults.string(forKey: Key.offlineModelURL.rawValue) ?? "https://huggingface.co/bartowski/Llama..." }
    set { defaults.set(newValue, forKey: Key.offlineModelURL.rawValue) }
  }

  var isOfflineModelInstalled: Bool {
    get { defaults.bool(forKey: Key.isOfflineModelInstalled.rawValue) }
    set { defaults.set(newValue, forKey: Key.isOfflineModelInstalled.rawValue) }
  }

  var memories: [String] {
    get { defaults.stringArray(forKey: Key.memories.rawValue) ?? [] }
    set { defaults.set(newValue, forKey: Key.memories.rawValue) }
  }

  // MARK: - Reset

  func resetAll() {
    for key in [Key.geminiAPIKey, .geminiSystemPrompt, .hermesHost, .hermesPort,
                .hermesHookToken, .hermesGatewayToken, .webrtcSignalingURL,
                .activeAIBackend, .autoReconnect, .showTranscripts, .enableWakeWord,
                .wakePhrase, .autoEndTimeout, .ttsVoice, .activationSound, .offlineModelURL,
                .isOfflineModelInstalled, .memories] {
      defaults.removeObject(forKey: key.rawValue)
    }
  }
}
