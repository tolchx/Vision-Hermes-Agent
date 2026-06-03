import Foundation

enum HermesConnectionState: Equatable {
  case notConfigured
  case checking
  case connected
  case unreachable(String)
}

struct ToolCallHistoryEntry: Identifiable, Equatable {
  let id = UUID()
  let timestamp: Date
  let toolName: String
  let status: String
  let detail: String

  var formattedTime: String {
    let df = DateFormatter()
    df.dateFormat = "HH:mm:ss"
    return df.string(from: timestamp)
  }
}

@MainActor
class HermesBridge: ObservableObject {
  @Published var lastToolCallStatus: ToolCallStatus = .idle
  @Published var connectionState: HermesConnectionState = .notConfigured
  @Published var latencyMs: Int? = nil
  @Published var toolCallHistory: [ToolCallHistoryEntry] = []

  private let session: URLSession
  private let pingSession: URLSession
  private var sessionKey: String
  private var conversationHistory: [[String: String]] = []
  private let maxHistoryTurns = 10
  private let maxToolCallHistory = 50

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 120
    self.session = URLSession(configuration: config)

    let pingConfig = URLSessionConfiguration.default
    pingConfig.timeoutIntervalForRequest = 5
    self.pingSession = URLSession(configuration: pingConfig)

    self.sessionKey = HermesBridge.newSessionKey()
  }

  func checkConnection() async {
    guard GeminiConfig.isHermesConfigured else {
      connectionState = .notConfigured
      return
    }
    connectionState = .checking
    AppLog("Checking Hermes connection...", level: .debug)
    let start = Date()
    let host = GeminiConfig.hermesHost.hasPrefix("http") ? GeminiConfig.hermesHost : "https://\(GeminiConfig.hermesHost)"
    let urlStr = host.hasSuffix("/") ? "\(host)v1/models" : "\(host)/v1/models"
    guard let url = URL(string: urlStr) else {
      AppLog("Invalid URL: \(urlStr)", level: .error)
      connectionState = .unreachable("Invalid URL")
      return
    }
    AppLog("Testing URL: \(url.absoluteString)", level: .debug)
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(GeminiConfig.hermesGatewayToken)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 15
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      let elapsed = Int(Date().timeIntervalSince(start) * 1000)
      latencyMs = elapsed
      if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
        connectionState = .connected
        AppLog("Hermes connected (HTTP \(http.statusCode)) [\(elapsed)ms]", level: .info)
      } else {
        let httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        connectionState = .unreachable("Unexpected response")
        AppLog("Hermes unexpected response: HTTP \(httpStatusCode)", level: .warn)
      }
    } catch {
      connectionState = .unreachable(error.localizedDescription)
      latencyMs = nil
      AppLog("Hermes connection failed: \(error.localizedDescription)", level: .error)
    }
  }

  func measureLatency() async {
    guard case .connected = connectionState else { return }
    let host = GeminiConfig.hermesHost.hasPrefix("http") ? GeminiConfig.hermesHost : "https://\(GeminiConfig.hermesHost)"
    let urlStr = host.hasSuffix("/") ? "\(host)v1/models" : "\(host)/v1/models"
    guard let url = URL(string: urlStr) else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(GeminiConfig.hermesGatewayToken)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 5
    let start = Date()
    do {
      let (_, response) = try await pingSession.data(for: request)
      let elapsed = Int(Date().timeIntervalSince(start) * 1000)
      if let http = response as? HTTPURLResponse, (200...499).contains(http.statusCode) {
        latencyMs = elapsed
      } else {
        latencyMs = nil
      }
    } catch {
      latencyMs = nil
    }
  }

  func resetSession() {
    sessionKey = HermesBridge.newSessionKey()
    conversationHistory = []
    NSLog("[Hermes] New session: %@", sessionKey)
  }

  private static func newSessionKey() -> String {
    let ts = ISO8601DateFormatter().string(from: Date())
    return "agent:main:glass:\(ts)"
  }

  // MARK: - Agent Chat (session continuity via Hermes)

  func delegateTask(
    task: String,
    toolName: String = "execute"
  ) async -> ToolResult {
    lastToolCallStatus = .executing(toolName)
    AppLog("delegateTask: \(task.prefix(80))...", level: .debug)

    let host = GeminiConfig.hermesHost.hasPrefix("http") ? GeminiConfig.hermesHost : "https://\(GeminiConfig.hermesHost)"
    let urlStr = host.hasSuffix("/") ? "\(host)v1/chat/completions" : "\(host)/v1/chat/completions"
    guard let url = URL(string: urlStr) else {
      AppLog("delegateTask: Invalid URL: \(urlStr)", level: .error)
      lastToolCallStatus = .failed(toolName, "Invalid URL")
      addToolCallHistory(toolName: toolName, status: "failed", detail: "Invalid URL")
      return .failure("Invalid gateway URL")
    }
    AppLog("delegateTask URL: \(url.absoluteString)", level: .debug)

    // Append the new user message to conversation history
    conversationHistory.append(["role": "user", "content": task])

    // Trim history to keep only the most recent turns (user+assistant pairs)
    if conversationHistory.count > maxHistoryTurns * 2 {
      conversationHistory = Array(conversationHistory.suffix(maxHistoryTurns * 2))
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(GeminiConfig.hermesGatewayToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
      "model": "deepseek-chat",
      "messages": conversationHistory,
      "stream": false
    ]

    NSLog("[Hermes] Sending %d messages in conversation", conversationHistory.count)

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      AppLog("delegateTask: Sending POST...", level: .debug)
      let (data, response) = try await session.data(for: request)
      let httpResponse = response as? HTTPURLResponse
      AppLog("delegateTask: Response HTTP \(httpResponse?.statusCode ?? 0)", level: .debug)

      guard let statusCode = httpResponse?.statusCode, (200...299).contains(statusCode) else {
        let code = httpResponse?.statusCode ?? 0
        let bodyStr = String(data: data, encoding: .utf8) ?? "no body"
        AppLog("delegateTask: HTTP error \(code): \(bodyStr.prefix(100))", level: .error)
        lastToolCallStatus = .failed(toolName, "HTTP \(code)")
        addToolCallHistory(toolName: toolName, status: "failed", detail: "HTTP \(code)")
        return .failure("Agent returned HTTP \(code)")
      }

      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let choices = json["choices"] as? [[String: Any]],
         let first = choices.first,
         let message = first["message"] as? [String: Any],
         let content = message["content"] as? String {
        conversationHistory.append(["role": "assistant", "content": content])
        AppLog("delegateTask: Success - \(content.prefix(80))...", level: .info)
        
        let safeContent = content.count > 8000 ? String(content.prefix(8000)) + "\n[Response truncated to fit WebSocket limit]" : content
        NSLog("[Hermes] Agent result: %@", String(safeContent.prefix(200)))
        lastToolCallStatus = .completed(toolName)
        addToolCallHistory(toolName: toolName, status: "completed", detail: content.prefix(60).replacingOccurrences(of: "\n", with: " ") + "...")
        return .success(safeContent)
      }

      let raw = String(data: data, encoding: .utf8) ?? "OK"
      conversationHistory.append(["role": "assistant", "content": raw])
      let safeRaw = raw.count > 8000 ? String(raw.prefix(8000)) + "\n[Response truncated to fit WebSocket limit]" : raw
      NSLog("[Hermes] Agent raw: %@", String(safeRaw.prefix(200)))
      lastToolCallStatus = .completed(toolName)
      addToolCallHistory(toolName: toolName, status: "completed", detail: "Raw response received")
      return .success(safeRaw)
    } catch {
      NSLog("[Hermes] Agent error: %@", error.localizedDescription)
      lastToolCallStatus = .failed(toolName, error.localizedDescription)
      addToolCallHistory(toolName: toolName, status: "failed", detail: error.localizedDescription)
      return .failure("Agent error: \(error.localizedDescription)")
    }
  }

  // MARK: - Tool Call History

  private func addToolCallHistory(toolName: String, status: String, detail: String) {
    let entry = ToolCallHistoryEntry(
      timestamp: Date(),
      toolName: toolName,
      status: status,
      detail: detail
    )
    toolCallHistory.append(entry)
    if toolCallHistory.count > maxToolCallHistory {
      toolCallHistory.removeFirst(toolCallHistory.count - maxToolCallHistory)
    }
  }
}
