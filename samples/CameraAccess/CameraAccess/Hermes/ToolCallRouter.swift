import Foundation
import UIKit

@MainActor
class HermesToolCallRouter {
  private let bridge: HermesBridge
  private var inFlightTasks: [String: Task<Void, Never>] = [:]

  init(bridge: HermesBridge) {
    self.bridge = bridge
  }

  /// Route a tool call from Gemini to the correct handler.
  /// Calls sendResponse with the JSON dictionary to send back as a toolResponse message.
  func handleToolCall(
    _ call: GeminiFunctionCall,
    chatHistoryManager: ChatHistoryManager? = nil,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let callId = call.id
    let callName = call.name

    NSLog("[HermesToolCall] Received: %@ (id: %@) args: %@",
          callName, callId, String(describing: call.args))

    switch callName {

    case "execute":
      routeExecute(call: call, callId: callId, sendResponse: sendResponse)

    case "gemelo_guardar_respuesta":
      routeGemelo(call: call, callId: callId, sendResponse: sendResponse)

    case "guardar_nota_rapida":
      routeNota(call: call, callId: callId, sendResponse: sendResponse)

    case "buscar_en_vault":
      routeBuscar(call: call, callId: callId, sendResponse: sendResponse)

    case "guardar_observacion":
      routeObservacion(call: call, callId: callId, sendResponse: sendResponse)

    case "exportar_chat_md":
      routeExportarChat(call: call, callId: callId,
                        chatHistoryManager: chatHistoryManager,
                        sendResponse: sendResponse)

    default:
      NSLog("[HermesToolCall] Unknown tool: %@, falling back to execute", callName)
      routeExecute(call: call, callId: callId, sendResponse: sendResponse)
    }
  }

  /// Cancel specific in-flight tool calls (from toolCallCancellation)
  func cancelToolCalls(ids: [String]) {
    for id in ids {
      if let task = inFlightTasks[id] {
        NSLog("[HermesToolCall] Cancelling in-flight call: %@", id)
        task.cancel()
        inFlightTasks.removeValue(forKey: id)
      }
    }
    bridge.lastToolCallStatus = .cancelled(ids.first ?? "unknown")
  }

  /// Cancel all in-flight tool calls (on session stop)
  func cancelAll() {
    for (id, task) in inFlightTasks {
      NSLog("[HermesToolCall] Cancelling in-flight call: %@", id)
      task.cancel()
    }
    inFlightTasks.removeAll()
  }

  // MARK: - Route Implementations

  private func routeExecute(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let taskDesc = call.args["task"] as? String ?? String(describing: call.args)
      let result = await bridge.delegateTask(task: taskDesc, toolName: "execute")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "execute", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeGemelo(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let categoria = call.args["categoria"] as? String ?? "General"
      let pregunta = call.args["pregunta"] as? String ?? ""
      let respuesta = call.args["respuesta"] as? String ?? ""
      let analisis = call.args["analisis_emocion"] as? String
      let frases = call.args["frases_clave"] as? [String]
      let rasgo = call.args["nuevo_rasgo"] as? String

      let taskDesc = ToolDeclarations.gemeloTask(
        categoria: categoria, pregunta: pregunta, respuesta: respuesta,
        analisis: analisis, frases: frases, rasgo: rasgo
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "gemelo_guardar_respuesta")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "gemelo_guardar_respuesta", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeNota(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let titulo = call.args["titulo"] as? String ?? "Nota rápida"
      let contenido = call.args["contenido"] as? String ?? ""
      let carpeta = call.args["carpeta"] as? String

      let taskDesc = ToolDeclarations.notaTask(titulo: titulo, contenido: contenido, carpeta: carpeta)
      let result = await bridge.delegateTask(task: taskDesc, toolName: "guardar_nota_rapida")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "guardar_nota_rapida", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeBuscar(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let consulta = call.args["consulta"] as? String ?? ""
      let limite = call.args["limite"] as? Int ?? 5

      let taskDesc = ToolDeclarations.busquedaTask(consulta: consulta, limite: limite)
      let result = await bridge.delegateTask(task: taskDesc, toolName: "buscar_en_vault")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "buscar_en_vault", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeObservacion(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let titulo = call.args["titulo"] as? String ?? "Observación"
      let descripcion = call.args["descripcion"] as? String ?? ""
      let contexto = call.args["contexto"] as? String
      let tags = call.args["tags"] as? [String]

      let taskDesc = ToolDeclarations.observacionTask(
        titulo: titulo, descripcion: descripcion, contexto: contexto, tags: tags
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "guardar_observacion")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "guardar_observacion", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeExportarChat(
    call: GeminiFunctionCall, callId: String,
    chatHistoryManager: ChatHistoryManager?,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let titulo = call.args["titulo"] as? String ?? "Chat exportado"
      let guardarEnVault = call.args["guardar_en_vault"] as? Bool ?? false

      // Generate markdown from the current session
      var mdContent = ""
      if let manager = chatHistoryManager {
        mdContent = manager.exportCurrentSessionAsMD(title: titulo)
      } else {
        mdContent = "# \(titulo)\n\n*Chat exportado desde VisionHermes*\n"
      }

      // Always share/save locally
      await self.shareMarkdown(content: mdContent, title: titulo)

      // Optionally send to vault via Hermes
      if guardarEnVault {
        let taskDesc = ToolDeclarations.exportarChatTask(titulo: titulo, contenidoMD: mdContent)
        let result = await bridge.delegateTask(task: taskDesc, toolName: "exportar_chat_md")
        guard !Task.isCancelled else { return }
        let response = buildToolResponse(callId: callId, name: "exportar_chat_md", result: result)
        sendResponse(response)
      } else {
        let response = buildToolResponse(
          callId: callId, name: "exportar_chat_md",
          result: .success("Chat exportado como MD. \(guardarEnVault ? "También se guardó en el vault." : "")")
        )
        sendResponse(response)
      }
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  // MARK: - Helpers

  private func shareMarkdown(content: String, title: String) async {
    // Save to temp file and present share sheet
    let tempDir = FileManager.default.temporaryDirectory
    let fileURL = tempDir.appendingPathComponent("\(title.replacingOccurrences(of: "/", with: "-")).md")

    do {
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
      // Present share sheet on main thread
      await MainActor.run {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }

        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
      }
    } catch {
      NSLog("[HermesToolCall] Failed to save MD: %@", error.localizedDescription)
    }
  }

  private func buildToolResponse(
    callId: String,
    name: String,
    result: ToolResult
  ) -> [String: Any] {
    return [
      "toolResponse": [
        "functionResponses": [
          [
            "id": callId,
            "name": name,
            "response": result.responseValue
          ]
        ]
      ]
    ]
  }
}
