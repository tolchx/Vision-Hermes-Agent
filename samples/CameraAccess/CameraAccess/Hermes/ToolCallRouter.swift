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
    snapshot: UIImage? = nil,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let callId = call.id
    let callName = call.name

    NSLog("[HermesToolCall] Received: %@ (id: %@) args: %@",
          callName, callId, String(describing: call.args))

    bridge.setActiveToolCall(id: callId, toolName: callName, args: call.args, snapshot: snapshot)

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

    case "consultar_estado_hermes":
      routeConsultarEstado(call: call, callId: callId, sendResponse: sendResponse)

    case "controlar_tarea_hermes":
      routeControlarTarea(call: call, callId: callId, sendResponse: sendResponse)

    case "enviar_reporte_telegram":
      routeEnviarReporteTelegram(call: call, callId: callId, snapshot: snapshot, sendResponse: sendResponse)

    case "ejecutar_script_remoto":
      routeEjecutarScriptRemoto(call: call, callId: callId, sendResponse: sendResponse)

    case "resumen_walk_and_talk":
      routeResumenWalkAndTalk(call: call, callId: callId, sendResponse: sendResponse)

    case "guardar_referencia_visual":
      routeGuardarReferenciaVisual(call: call, callId: callId, snapshot: snapshot, sendResponse: sendResponse)

    case "consultar_briefing_diario":
      routeConsultarBriefingDiario(call: call, callId: callId, sendResponse: sendResponse)

    case "delegar_investigacion_profunda":
      routeDelegarInvestigacionProfunda(call: call, callId: callId, sendResponse: sendResponse)

    case "capturar_paleta_y_texturas":
      routeCapturarPaletaYTexturas(call: call, callId: callId, snapshot: snapshot, sendResponse: sendResponse)

    case "inspeccionar_pantalla_o_pizarra":
      routeInspeccionarPantallaOPizarra(call: call, callId: callId, snapshot: snapshot, sendResponse: sendResponse)

    case "recordar_contacto_o_networking":
      routeRecordarContactoONetworking(call: call, callId: callId, snapshot: snapshot, sendResponse: sendResponse)

    case "registrar_gasto_o_habito":
      routeRegistrarGastoOHabito(call: call, callId: callId, sendResponse: sendResponse)

    case "repasar_conceptos_vault":
      routeRepasarConceptosVault(call: call, callId: callId, sendResponse: sendResponse)

    case "monitorear_proceso_o_render":
      routeMonitorearProcesoORender(call: call, callId: callId, sendResponse: sendResponse)

    case "control_ambiente_pc":
      routeControlAmbientePC(call: call, callId: callId, sendResponse: sendResponse)

    case "donde_deje_mi_objeto":
      routeDondeDejeMiObjeto(call: call, callId: callId, sendResponse: sendResponse)

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
    bridge.activeToolCall?.state = .cancelled
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
      var contexto = call.args["contexto"] as? String
      let tags = call.args["tags"] as? [String]

      if let loc = LocationManager.shared.contextString {
        contexto = (contexto != nil && !contexto!.isEmpty) ? "\(contexto!) | \(loc)" : loc
      }

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

  private func routeConsultarEstado(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let tipo = call.args["tipo_consulta"] as? String ?? "sesiones_activas"
      let detalle = call.args["detalle"] as? String
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.estadoHermesTask(
        tipo: tipo,
        detalle: detalle,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "consultar_estado_hermes")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "consultar_estado_hermes", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeControlarTarea(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let accion = call.args["accion"] as? String ?? "cancelar"
      let objetivo = call.args["objetivo"] as? String

      let taskDesc = ToolDeclarations.controlarTareaTask(accion: accion, objetivo: objetivo)
      let result = await bridge.delegateTask(task: taskDesc, toolName: "controlar_tarea_hermes")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "controlar_tarea_hermes", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeEnviarReporteTelegram(
    call: GeminiFunctionCall, callId: String,
    snapshot: UIImage?,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let tipo = call.args["tipo_reporte"] as? String ?? "nota_rapida"
      let titulo = call.args["titulo"] as? String ?? "Reporte desde Gafas"
      let contenido = call.args["contenido_md"] as? String ?? ""
      let incluirFoto = call.args["incluir_foto_pov"] as? Bool ?? true
      let canal = call.args["canal_o_chat"] as? String
      let locationContext = LocationManager.shared.contextString

      var fotoBase64: String? = nil
      if incluirFoto, let snap = snapshot {
        fotoBase64 = self.encodeSnapshotForTransmission(snap)
      }

      let taskDesc = ToolDeclarations.telegramReporteTask(
        tipo: tipo,
        titulo: titulo,
        contenidoMD: contenido,
        fotoBase64: fotoBase64,
        canal: canal,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "enviar_reporte_telegram")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "enviar_reporte_telegram", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeEjecutarScriptRemoto(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let comando = call.args["comando_o_script"] as? String ?? ""
      let directorio = call.args["directorio_trabajo"] as? String
      let enviarLog = call.args["enviar_log_a_telegram"] as? Bool ?? true
      let modo = call.args["modo_ejecucion"] as? String ?? "sincrono"

      let taskDesc = ToolDeclarations.ejecutarScriptTask(
        comando: comando,
        directorio: directorio,
        enviarLogTelegram: enviarLog,
        modo: modo
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "ejecutar_script_remoto")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "ejecutar_script_remoto", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeResumenWalkAndTalk(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let titulo = call.args["titulo"] as? String ?? "Walk & Talk"
      let ideas = call.args["ideas_clave"] as? [String] ?? []
      let actions = call.args["action_items"] as? [String] ?? []
      let resumen = call.args["resumen_ejecutivo"] as? String ?? ""
      let guardarObsidian = call.args["guardar_en_obsidian"] as? Bool ?? true
      let enviarTelegram = call.args["enviar_a_telegram"] as? Bool ?? true
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.walkAndTalkTask(
        titulo: titulo,
        ideas: ideas,
        actions: actions,
        resumen: resumen,
        guardarObsidian: guardarObsidian,
        enviarTelegram: enviarTelegram,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "resumen_walk_and_talk")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "resumen_walk_and_talk", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeGuardarReferenciaVisual(
    call: GeminiFunctionCall, callId: String,
    snapshot: UIImage?,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let titulo = call.args["titulo"] as? String ?? "Referencia Visual"
      let descripcion = call.args["descripcion_visual"] as? String ?? ""
      let touchdesigner = call.args["sugerencia_touchdesigner"] as? String ?? ""
      let tags = call.args["tags"] as? [String]
      let enviarTelegram = call.args["enviar_a_telegram"] as? Bool ?? true
      let locationContext = LocationManager.shared.contextString

      var fotoBase64: String? = nil
      if let snap = snapshot {
        fotoBase64 = self.encodeSnapshotForTransmission(snap)
      }

      let taskDesc = ToolDeclarations.referenciaVisualTask(
        titulo: titulo,
        descripcion: descripcion,
        touchdesigner: touchdesigner,
        tags: tags,
        fotoBase64: fotoBase64,
        enviarTelegram: enviarTelegram,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "guardar_referencia_visual")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "guardar_referencia_visual", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeConsultarBriefingDiario(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let alcance = call.args["alcance"] as? String ?? "general"
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.briefingDiarioTask(alcance: alcance, locationContext: locationContext)
      let result = await bridge.delegateTask(task: taskDesc, toolName: "consultar_briefing_diario")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "consultar_briefing_diario", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeDelegarInvestigacionProfunda(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let tema = call.args["tema"] as? String ?? ""
      let objetivo = call.args["objetivo"] as? String ?? ""
      let entregarEn = call.args["entregar_en"] as? String
      let profundidad = call.args["profundidad"] as? String
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.investigacionProfundaTask(
        tema: tema,
        objetivo: objetivo,
        entregarEn: entregarEn,
        profundidad: profundidad,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "delegar_investigacion_profunda")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "delegar_investigacion_profunda", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeCapturarPaletaYTexturas(
    call: GeminiFunctionCall, callId: String,
    snapshot: UIImage?,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let titulo = call.args["titulo"] as? String ?? "Paleta de Color"
      let tipo = call.args["tipo"] as? String
      let paletaHex = call.args["paleta_hex"] as? [String] ?? []
      let analisisEstetico = call.args["analisis_estetico"] as? String
      let sugerenciaTD = call.args["sugerencia_touchdesigner"] as? String ?? ""
      let locationContext = LocationManager.shared.contextString

      var fotoBase64: String? = nil
      if let snap = snapshot {
        fotoBase64 = self.encodeSnapshotForTransmission(snap)
      }

      let taskDesc = ToolDeclarations.paletaTexturasTask(
        titulo: titulo,
        tipo: tipo,
        paletaHex: paletaHex,
        analisisEstetico: analisisEstetico,
        sugerenciaTD: sugerenciaTD,
        fotoBase64: fotoBase64,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "capturar_paleta_y_texturas")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "capturar_paleta_y_texturas", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeInspeccionarPantallaOPizarra(
    call: GeminiFunctionCall, callId: String,
    snapshot: UIImage?,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let contexto = call.args["contexto"] as? String ?? ""
      let accionRequerida = call.args["accion_requerida"] as? String ?? "explicar_error"
      let analisisVisual = call.args["analisis_visual"] as? String ?? ""
      let codigoODiagrama = call.args["codigo_o_diagrama"] as? String
      let locationContext = LocationManager.shared.contextString

      var fotoBase64: String? = nil
      if let snap = snapshot {
        fotoBase64 = self.encodeSnapshotForTransmission(snap)
      }

      let taskDesc = ToolDeclarations.inspeccionPantallaPizarraTask(
        contexto: contexto,
        accionRequerida: accionRequerida,
        analisisVisual: analisisVisual,
        codigoODiagrama: codigoODiagrama,
        fotoBase64: fotoBase64,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "inspeccionar_pantalla_o_pizarra")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "inspeccionar_pantalla_o_pizarra", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeRecordarContactoONetworking(
    call: GeminiFunctionCall, callId: String,
    snapshot: UIImage?,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let nombre = call.args["nombre"] as? String ?? ""
      let rolOEmpresa = call.args["rol_o_empresa"] as? String
      let contextoCharla = call.args["contexto_charla"] as? String ?? ""
      let compromiso = call.args["compromiso_o_proximo_paso"] as? String
      let tags = call.args["tags"] as? [String]
      let locationContext = LocationManager.shared.contextString

      var fotoBase64: String? = nil
      if let snap = snapshot {
        fotoBase64 = self.encodeSnapshotForTransmission(snap)
      }

      let taskDesc = ToolDeclarations.recordarContactoTask(
        nombre: nombre,
        rolOEmpresa: rolOEmpresa,
        contextoCharla: contextoCharla,
        compromisoOProximoPaso: compromiso,
        tags: tags,
        fotoBase64: fotoBase64,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "recordar_contacto_o_networking")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "recordar_contacto_o_networking", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeRegistrarGastoOHabito(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let tipoRegistro = call.args["tipo_registro"] as? String ?? "gasto"
      let valor = call.args["valor"] as? String ?? ""
      let concepto = call.args["concepto"] as? String ?? ""
      let categoria = call.args["categoria"] as? String
      let medioPago = call.args["medio_pago"] as? String
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.registroGastoHabitoTask(
        tipoRegistro: tipoRegistro,
        valor: valor,
        concepto: concepto,
        categoria: categoria,
        medioPago: medioPago,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "registrar_gasto_o_habito")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "registrar_gasto_o_habito", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeRepasarConceptosVault(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let temaOCarpeta = call.args["tema_o_carpeta"] as? String ?? ""
      let modo = call.args["modo"] as? String
      let conceptoEspecifico = call.args["concepto_especifico"] as? String
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.repasoConceptosVaultTask(
        temaOCarpeta: temaOCarpeta,
        modo: modo,
        conceptoEspecifico: conceptoEspecifico,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "repasar_conceptos_vault")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "repasar_conceptos_vault", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeMonitorearProcesoORender(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let proceso = call.args["proceso"] as? String ?? "todos"
      let accion = call.args["accion"] as? String ?? "consultar_progreso"
      let condicionAviso = call.args["condicion_aviso"] as? String
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.monitorearProcesoTask(
        proceso: proceso,
        accion: accion,
        condicionAviso: condicionAviso,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "monitorear_proceso_o_render")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "monitorear_proceso_o_render", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeControlAmbientePC(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let accion = call.args["accion"] as? String ?? ""
      let objetivo = call.args["objetivo"] as? String
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.controlAmbientePCTask(
        accion: accion,
        objetivo: objetivo,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "control_ambiente_pc")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "control_ambiente_pc", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  private func routeDondeDejeMiObjeto(
    call: GeminiFunctionCall, callId: String,
    sendResponse: @escaping ([String: Any]) -> Void
  ) {
    let task = Task { @MainActor in
      let objeto = call.args["objeto"] as? String ?? "objeto"
      let contextoLugar = call.args["contexto_lugar"] as? String
      let timelineContext = TemporalVisualMemory.shared.buildTimelineContext()
      let locationContext = LocationManager.shared.contextString

      let taskDesc = ToolDeclarations.dondeDejeObjetoTask(
        objeto: objeto,
        contextoLugar: contextoLugar,
        timelineContext: timelineContext,
        locationContext: locationContext
      )
      let result = await bridge.delegateTask(task: taskDesc, toolName: "donde_deje_mi_objeto")
      guard !Task.isCancelled else { return }
      let response = buildToolResponse(callId: callId, name: "donde_deje_mi_objeto", result: result)
      sendResponse(response)
      inFlightTasks.removeValue(forKey: callId)
    }
    inFlightTasks[callId] = task
  }

  // MARK: - Helpers

  /// Resize and compress image to base64 JPEG for low-latency transmission over mobile network
  private func encodeSnapshotForTransmission(_ image: UIImage?, maxDimension: CGFloat = 800, quality: CGFloat = 0.65) -> String? {
    guard let image = image else { return nil }
    let size = image.size
    var targetSize = size
    if max(size.width, size.height) > maxDimension {
      let scale = maxDimension / max(size.width, size.height)
      targetSize = CGSize(width: size.width * scale, height: size.height * scale)
    }

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
    let resizedImage = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: targetSize))
    }

    guard let jpegData = resizedImage.jpegData(compressionQuality: quality) else { return nil }
    return jpegData.base64EncodedString()
  }

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
