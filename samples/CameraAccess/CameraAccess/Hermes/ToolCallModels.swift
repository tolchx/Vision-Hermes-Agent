import UIKit
import Foundation

// MARK: - Gemini Tool Call (parsed from server JSON)

struct GeminiFunctionCall {
  let id: String
  let name: String
  let args: [String: Any]
}

struct GeminiToolCall {
  let functionCalls: [GeminiFunctionCall]

  init?(json: [String: Any]) {
    guard let toolCall = json["toolCall"] as? [String: Any],
          let calls = toolCall["functionCalls"] as? [[String: Any]] else {
      return nil
    }
    self.functionCalls = calls.compactMap { call in
      guard let id = call["id"] as? String,
            let name = call["name"] as? String else { return nil }
      let args = call["args"] as? [String: Any] ?? [:]
      return GeminiFunctionCall(id: id, name: name, args: args)
    }
  }
}

// MARK: - Gemini Tool Call Cancellation

struct GeminiToolCallCancellation {
  let ids: [String]

  init?(json: [String: Any]) {
    guard let cancellation = json["toolCallCancellation"] as? [String: Any],
          let ids = cancellation["ids"] as? [String] else {
      return nil
    }
    self.ids = ids
  }
}

// MARK: - Tool Result

enum ToolResult {
  case success(String)
  case failure(String)

  var responseValue: [String: Any] {
    switch self {
    case .success(let result):
      return ["result": result]
    case .failure(let error):
      return ["error": error]
    }
  }
}

// MARK: - Tool Call Status (for UI)

/// Icon + short name mapping for each tool
enum ToolIcon {
  static func icon(for toolName: String) -> String {
    switch toolName {
    case "execute": return "bolt.fill"
    case "gemelo_guardar_respuesta": return "person.text.rectangle.fill"
    case "guardar_nota_rapida": return "square.and.pencil"
    case "buscar_en_vault": return "magnifyingglass"
    case "guardar_observacion": return "eye.fill"
    case "exportar_chat_md": return "doc.text.fill"
    case "consultar_estado_hermes": return "server.rack"
    case "controlar_tarea_hermes": return "hand.raised.fill"
    case "enviar_reporte_telegram": return "paperplane.fill"
    case "ejecutar_script_remoto": return "terminal.fill"
    case "resumen_walk_and_talk": return "figure.walk"
    case "guardar_referencia_visual": return "sparkles.tv"
    case "consultar_briefing_diario": return "sun.max.fill"
    default: return "link.circle.fill"
    }
  }

  static func shortName(for toolName: String) -> String {
    switch toolName {
    case "execute": return "Ejecutar"
    case "gemelo_guardar_respuesta": return "Gemelo"
    case "guardar_nota_rapida": return "Nota"
    case "buscar_en_vault": return "Buscar"
    case "guardar_observacion": return "Observar"
    case "exportar_chat_md": return "Exportar"
    case "consultar_estado_hermes": return "Estado Hermes"
    case "controlar_tarea_hermes": return "Control Tarea"
    case "enviar_reporte_telegram": return "Telegram"
    case "ejecutar_script_remoto": return "Terminal"
    case "resumen_walk_and_talk": return "Walk & Talk"
    case "guardar_referencia_visual": return "Field Scout"
    case "consultar_briefing_diario": return "Briefing"
    default: return toolName.replacingOccurrences(of: "_", with: " ").capitalized
    }
  }
}

enum ToolExecutionState: Equatable {
  case executing
  case completed(result: String)
  case failed(error: String)
  case cancelled
}

struct ActiveToolCallInfo: Identifiable, Equatable {
  let id: String
  let toolName: String
  let args: [String: Any]
  var state: ToolExecutionState
  var snapshotImage: UIImage?
  let timestamp: Date

  static func == (lhs: ActiveToolCallInfo, rhs: ActiveToolCallInfo) -> Bool {
    lhs.id == rhs.id && lhs.toolName == rhs.toolName && lhs.state == rhs.state
  }
}

enum ToolCallStatus: Equatable {
  case idle
  case executing(String)
  case completed(String)
  case failed(String, String)
  case cancelled(String)

  var displayText: String {
    switch self {
    case .idle: return ""
    case .executing(let name): return ToolIcon.shortName(for: name)
    case .completed(let name): return "✓ \(ToolIcon.shortName(for: name))"
    case .failed(let name, let err): return "✗ \(ToolIcon.shortName(for: name)): \(err)"
    case .cancelled(let name): return "— \(ToolIcon.shortName(for: name))"
    }
  }

  var isActive: Bool {
    if case .executing = self { return true }
    return false
  }
}

// MARK: - Tool Declarations (for Gemini setup message)

enum ToolDeclarations {

  /// Returns ALL function declarations registered for Gemini.
  static func allDeclarations() -> [[String: Any]] {
    return [
      execute,
      gemeloGuardarRespuesta,
      guardarNotaRapida,
      buscarEnVault,
      guardarObservacion,
      consultarEstadoHermes,
      controlarTareaHermes,
      enviarReporteTelegram,
      ejecutarScriptRemoto,
      resumenWalkAndTalk,
      guardarReferenciaVisual,
      consultarBriefingDiario,
    ]
  }

  // ── 1. execute (existing, unchanged) ──────────────────────────

  static let execute: [String: Any] = [
    "name": "execute",
    "description": "Your only way to take action beyond answering questions. You have no memory, storage, or ability to do anything on your own -- use this tool for: sending messages, searching the web, adding to lists, setting reminders, creating notes, research, drafts, scheduling, smart home control, app interactions, or any request that goes beyond just answering. When in doubt, use this tool.",
    "parameters": [
      "type": "object",
      "properties": [
        "task": [
          "type": "string",
          "description": "Clear, detailed description of what to do. Include all relevant context: names, content, platforms, quantities, etc."
        ]
      ],
      "required": ["task"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 2. gemelo_guardar_respuesta ──────────────────────────────

  static let gemeloGuardarRespuesta: [String: Any] = [
    "name": "gemelo_guardar_respuesta",
    "description": "Guarda una respuesta del Avatar Personal del usuario en Obsidian. Usar cuando el usuario responda una pregunta profunda sobre su personalidad, valores o historia. REQUIERE: categoria, pregunta y respuesta.",
    "parameters": [
      "type": "object",
      "properties": [
        "categoria": [
          "type": "string",
          "description": "Categoría temática: Filosofía de Vida | Memorias | Relaciones | Creatividad | Miedo | Aspiraciones | Identidad | Tecnología | Ética | Muerte"
        ],
        "pregunta": [
          "type": "string",
          "description": "La pregunta exacta que se le hizo al usuario"
        ],
        "respuesta": [
          "type": "string",
          "description": "Transcripción completa o resumen detallado de lo que dijo el usuario"
        ],
        "analisis_emocion": [
          "type": "string",
          "description": "Emoción detectada durante la respuesta: reflexivo, entusiasta, nostálgico, vulnerable, serio, pensativo, etc."
        ],
        "frases_clave": [
          "type": "array",
          "items": ["type": "string"],
          "description": "2-5 frases textuales que más lo representan en esta respuesta"
        ],
        "nuevo_rasgo": [
          "type": "string",
          "description": "Si se detectó un rasgo de personalidad nuevo que no estaba documentado antes, describirlo aquí (opcional)"
        ]
      ],
      "required": ["categoria", "pregunta", "respuesta"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 3. guardar_nota_rapida ───────────────────────────────────

  static let guardarNotaRapida: [String: Any] = [
    "name": "guardar_nota_rapida",
    "description": "Guarda una nota rápida en Obsidian. Usar cuando el usuario dice algo que quiere recordar: ideas, tareas, inspiración, algo que vio, algo que pensó. Crea un archivo Markdown en la carpeta 📥 Inbox del vault.",
    "parameters": [
      "type": "object",
      "properties": [
        "titulo": [
          "type": "string",
          "description": "Título corto y descriptivo de la nota"
        ],
        "contenido": [
          "type": "string",
          "description": "Contenido completo de la nota. Puede incluir descripciones de lo que se ve por cámara, ideas, reflexiones, etc."
        ],
        "carpeta": [
          "type": "string",
          "description": "Carpeta donde guardar (opcional, default: 📥 Inbox). Valores comunes: 📥 Inbox, 🧠 Ideas, 🎯 TouchDesigner, 👤 Perfil Personal"
        ]
      ],
      "required": ["titulo", "contenido"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 4. buscar_en_vault ───────────────────────────────────────

  static let buscarEnVault: [String: Any] = [
    "name": "buscar_en_vault",
    "description": "Busca información en el vault de Obsidian del usuario. Usar cuando pregunte algo que pueda estar en sus notas: conceptos de TouchDesigner, proyectos, sesiones pasadas, memoria de Hermes, etc. Devuelve fragmentos relevantes de las notas.",
    "parameters": [
      "type": "object",
      "properties": [
        "consulta": [
          "type": "string",
          "description": "Términos de búsqueda. Pueden ser palabras clave, frases, nombres de proyectos, conceptos técnicos, etc."
        ],
        "limite": [
          "type": "integer",
          "description": "Máximo de resultados a devolver (default: 5, max: 20)"
        ]
      ],
      "required": ["consulta"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 5. guardar_observacion ───────────────────────────────────

  static let guardarObservacion: [String: Any] = [
    "name": "guardar_observacion",
    "description": "Guarda una observación del mundo real captada por la cámara de las gafas. Gemini describe lo que ve y Hermes lo guarda como nota en Obsidian con timestamp y contexto visual. Usar cuando el usuario ve algo interesante, un lugar, un objeto, una persona, una obra de arte, etc. y quiere registrarlo.",
    "parameters": [
      "type": "object",
      "properties": [
        "titulo": [
          "type": "string",
          "description": "Título descriptivo de lo que se está viendo"
        ],
        "descripcion": [
          "type": "string",
          "description": "Descripción detallada de lo que se ve a través de la cámara: objetos, colores, texto, personas, ambiente, ubicación estimada"
        ],
        "contexto": [
          "type": "string",
          "description": "Contexto de por qué esto es relevante: lo que dijo el usuario al verlo, por qué llamó su atención, qué quiere recordar"
        ],
        "tags": [
          "type": "array",
          "items": ["type": "string"],
          "description": "Tags para categorizar la observación (ej: arte, instalacion, inspiracion, referencia, lugar, persona)"
        ]
      ],
      "required": ["titulo", "descripcion"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 7. consultar_estado_hermes ────────────────────────────────
  static let consultarEstadoHermes: [String: Any] = [
    "name": "consultar_estado_hermes",
    "description": "Consulta a Hermes qué sesiones están activas, qué tareas está ejecutando en segundo plano, qué subagentes o procesos tiene en marcha, o el estado general de su memoria. USAR SIEMPRE que el usuario pregunte qué está haciendo Hermes, qué sesiones hay activas, qué tareas están corriendo, o el estado de sus procesos.",
    "parameters": [
      "type": "object",
      "properties": [
        "tipo_consulta": [
          "type": "string",
          "description": "Tipo de consulta: sesiones_activas | tareas_fondo | estado_general | memoria_reciente",
          "enum": ["sesiones_activas", "tareas_fondo", "estado_general", "memoria_reciente"]
        ],
        "detalle": [
          "type": "string",
          "description": "Pregunta o aclaración específica del usuario (opcional)"
        ]
      ],
      "required": ["tipo_consulta"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 8. controlar_tarea_hermes ────────────────────────────────
  static let controlarTareaHermes: [String: Any] = [
    "name": "controlar_tarea_hermes",
    "description": "Envía una orden de control a Hermes para cancelar, pausar o detener una tarea, subagente o proceso en segundo plano. USAR cuando el usuario pida cancelar, parar o abortar una tarea anterior o un proceso de Hermes.",
    "parameters": [
      "type": "object",
      "properties": [
        "accion": [
          "type": "string",
          "description": "Acción a realizar: cancelar | pausar | reanudar",
          "enum": ["cancelar", "pausar", "reanudar"]
        ],
        "objetivo": [
          "type": "string",
          "description": "Qué cancelar o pausar: 'ultima_tarea', o el nombre/id del proceso o tarea a detener"
        ]
      ],
      "required": ["accion"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 6. exportar_chat_md (local-only, no Hermes needed) ──────

  static let exportarChatMd: [String: Any] = [
    "name": "exportar_chat_md",
    "description": "Exporta el historial de la conversación actual como archivo Markdown y lo guarda en el vault de Obsidian y/o lo comparte. Usar cuando el usuario pida guardar toda la conversación, exportar el chat, o tener un registro permanente de lo hablado.",
    "parameters": [
      "type": "object",
      "properties": [
        "titulo": [
          "type": "string",
          "description": "Título para el archivo exportado"
        ],
        "guardar_en_vault": [
          "type": "boolean",
          "description": "Si es true, además de exportar localmente, se envía al vault de Obsidian vía Hermes"
        ]
      ],
      "required": ["titulo"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 9. enviar_reporte_telegram ──────────────────────────────

  static let enviarReporteTelegram: [String: Any] = [
    "name": "enviar_reporte_telegram",
    "description": "Envía un reporte formateado en Markdown, resumen de reunión, observación visual, brainstorm o alerta directamente a Telegram (chat privado o canal). Opcionalmente incluye la captura actual de la cámara de las gafas (POV). USAR cuando el usuario pida enviar algo a Telegram, mandar un resumen al celular o compartir una foto/reporte por Telegram.",
    "parameters": [
      "type": "object",
      "properties": [
        "tipo_reporte": [
          "type": "string",
          "description": "Tipo de reporte: resumen_reunion | nota_rapida | observacion_visual | brainstorm | alerta",
          "enum": ["resumen_reunion", "nota_rapida", "observacion_visual", "brainstorm", "alerta"]
        ],
        "titulo": [
          "type": "string",
          "description": "Título claro y conciso del reporte"
        ],
        "contenido_md": [
          "type": "string",
          "description": "Cuerpo del reporte formateado en Markdown (puntos clave, conclusiones, to-dos)"
        ],
        "incluir_foto_pov": [
          "type": "boolean",
          "description": "Si es true (default), adjunta la foto actual capturada por las gafas (POV) al mensaje de Telegram"
        ],
        "canal_o_chat": [
          "type": "string",
          "description": "Destino en Telegram si el usuario especifica uno (ej: 'personal', 'trabajo', 'notas'). Opcional."
        ]
      ],
      "required": ["tipo_reporte", "titulo", "contenido_md"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 10. ejecutar_script_remoto ──────────────────────────────

  static let ejecutarScriptRemoto: [String: Any] = [
    "name": "ejecutar_script_remoto",
    "description": "Ejecuta un comando de consola, script de Python, Node.js, Git, Docker o pipeline de TouchDesigner en la computadora del usuario. Responde por las gafas con una síntesis breve en audio y envía el log completo o diff a Telegram.",
    "parameters": [
      "type": "object",
      "properties": [
        "comando_o_script": [
          "type": "string",
          "description": "Comando exacto de consola o script a ejecutar (ej: 'git status', 'docker ps', 'python scripts/render.py')"
        ],
        "directorio_trabajo": [
          "type": "string",
          "description": "Directorio o proyecto en la máquina donde ejecutar el comando (opcional)"
        ],
        "enviar_log_a_telegram": [
          "type": "boolean",
          "description": "Si es true (default), envía el log completo y salida de consola a Telegram para revisarlo en el móvil"
        ],
        "modo_ejecucion": [
          "type": "string",
          "description": "Modo de ejecución: sincrono (espera resultado) o segundo_plano (inicia y avisa)",
          "enum": ["sincrono", "segundo_plano"]
        ]
      ],
      "required": ["comando_o_script"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 11. resumen_walk_and_talk ───────────────────────────────

  static let resumenWalkAndTalk: [String: Any] = [
    "name": "resumen_walk_and_talk",
    "description": "Sintetiza una caminata de lluvia de ideas, debate o reflexión con el usuario. Extrae ideas principales, action items con prioridades y guarda la nota en Obsidian además de despachar el informe formateado a Telegram.",
    "parameters": [
      "type": "object",
      "properties": [
        "titulo": [
          "type": "string",
          "description": "Título temático de la caminata o sesión"
        ],
        "ideas_clave": [
          "type": "array",
          "items": ["type": "string"],
          "description": "Lista de las ideas centrales, conceptos o decisiones acordadas"
        ],
        "action_items": [
          "type": "array",
          "items": ["type": "string"],
          "description": "Lista de tareas pendientes, próximos pasos o to-dos concretos"
        ],
        "resumen_ejecutivo": [
          "type": "string",
          "description": "Resumen narrativo de 1 a 2 párrafos de la sesión"
        ],
        "guardar_en_obsidian": [
          "type": "boolean",
          "description": "Si guarda la nota en la carpeta 🧠 Ideas de Obsidian (default: true)"
        ],
        "enviar_a_telegram": [
          "type": "boolean",
          "description": "Si envía el reporte formateado a Telegram (default: true)"
        ]
      ],
      "required": ["titulo", "ideas_clave", "resumen_ejecutivo"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 12. guardar_referencia_visual ───────────────────────────

  static let guardarReferenciaVisual: [String: Any] = [
    "name": "guardar_referencia_visual",
    "description": "Scouting visual en la calle para proyectos creativos, arte generativo o TouchDesigner. Captura la imagen POV de las gafas, analiza la estructura visual y sugiere técnicas técnicas de nodos de TouchDesigner (Feedback TOP, GLSL shaders, CHOPs, Noise), guardándolo en Obsidian y enviándolo a Telegram.",
    "parameters": [
      "type": "object",
      "properties": [
        "titulo": [
          "type": "string",
          "description": "Nombre de la referencia visual o concepto"
        ],
        "descripcion_visual": [
          "type": "string",
          "description": "Descripción detallada de la luz, color, composición, movimiento y geometría observada"
        ],
        "sugerencia_touchdesigner": [
          "type": "string",
          "description": "Sugerencia técnica concreta para recrear el efecto en TouchDesigner (operadores TOPs/CHOPs/SOPs, shaders, feedback loops)"
        ],
        "tags": [
          "type": "array",
          "items": ["type": "string"],
          "description": "Tags para organizar la referencia (ej: shader, generative, lighting, motion, stage)"
        ],
        "enviar_a_telegram": [
          "type": "boolean",
          "description": "Si envía la referencia y foto a Telegram (default: true)"
        ]
      ],
      "required": ["titulo", "descripcion_visual", "sugerencia_touchdesigner"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 13. consultar_briefing_diario ───────────────────────────

  static let consultarBriefingDiario: [String: Any] = [
    "name": "consultar_briefing_diario",
    "description": "Solicita a Hermes un briefing de voz matutino o de salida a la calle. Consulta las notas del día en Obsidian, tareas pendientes, procesos en la PC y últimos commits, devolviendo un audio-resumen ejecutivo de 30-45 segundos.",
    "parameters": [
      "type": "object",
      "properties": [
        "alcance": [
          "type": "string",
          "description": "Alcance del briefing: general | pendientes_obsidian | alertas_pc | ultimos_commits",
          "enum": ["general", "pendientes_obsidian", "alertas_pc", "ultimos_commits"]
        ]
      ],
      "required": ["alcance"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]
}

// MARK: - Structured task helpers (for building Hermes task descriptions)

extension ToolDeclarations {

  /// Build a structured task string for a gemelo_guardar_respuesta call
  static func gemeloTask(
    categoria: String, pregunta: String, respuesta: String,
    analisis: String? = nil, frases: [String]? = nil, rasgo: String? = nil
  ) -> String {
    var task = """
    [GEMELO_GUARDAR]
    Categoría: \(categoria)
    Pregunta: \(pregunta)
    Respuesta: \(respuesta)
    """
    if let a = analisis { task += "\nAnálisis emoción: \(a)" }
    if let f = frases, !f.isEmpty { task += "\nFrases clave: \(f.joined(separator: " | "))" }
    if let r = rasgo { task += "\nNuevo rasgo: \(r)" }
    return task
  }

  /// Build a structured task string for a guardar_nota_rapida call
  static func notaTask(titulo: String, contenido: String, carpeta: String? = nil) -> String {
    let folder = carpeta ?? "📥 Inbox"
    return """
    [NOTA_RAPIDA]
    Título: \(titulo)
    Carpeta: \(folder)
    Contenido: \(contenido)
    """
  }

  /// Build a structured task string for a buscar_en_vault call
  static func busquedaTask(consulta: String, limite: Int = 5) -> String {
    return """
    [BUSCAR_VAULT]
    Consulta: \(consulta)
    Límite: \(limite)
    """
  }

  /// Build a structured task string for a guardar_observacion call
  static func observacionTask(titulo: String, descripcion: String, contexto: String? = nil, tags: [String]? = nil) -> String {
    var task = """
    [OBSERVACION]
    Título: \(titulo)
    Descripción: \(descripcion)
    """
    if let c = contexto { task += "\nContexto: \(c)" }
    if let t = tags, !t.isEmpty { task += "\nTags: \(t.joined(separator: ", "))" }
    return task
  }

  /// Build a structured task string for exporting chat to vault
  static func exportarChatTask(titulo: String, contenidoMD: String) -> String {
    return """
    [EXPORTAR_CHAT]
    Título: \(titulo)
    ---
    \(contenidoMD)
    """
  }

  /// Build a structured task string for consultar_estado_hermes
  static func estadoHermesTask(tipo: String, detalle: String? = nil, locationContext: String? = nil) -> String {
    var task = """
    [ESTADO_HERMES]
    Tipo de consulta: \(tipo)
    """
    if let d = detalle, !d.isEmpty { task += "\nDetalle: \(d)" }
    if let loc = locationContext, !loc.isEmpty { task += "\n\(loc)" }
    task += "\nPor favor informa detalladamente: sesiones activas, subagentes en ejecución, tareas en segundo plano y estado actual."
    return task
  }

  /// Build a structured task string for controlar_tarea_hermes
  static func controlarTareaTask(accion: String, objetivo: String? = nil) -> String {
    let target = objetivo ?? "ultima_tarea"
    return """
    [CONTROL_TAREA]
    Acción: \(accion)
    Objetivo: \(target)
    Por favor ejecuta la acción inmediatamente y reporta el resultado.
    """
  }

  /// Build a structured task string for enviar_reporte_telegram
  static func telegramReporteTask(
    tipo: String,
    titulo: String,
    contenidoMD: String,
    fotoBase64: String? = nil,
    canal: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [REPORTE_TELEGRAM]
    Tipo: \(tipo)
    Título: \(titulo)
    """
    if let ch = canal, !ch.isEmpty { task += "\nCanal/Destino: \(ch)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += "\nContenido Markdown:\n\(contenidoMD)"
    if let img = fotoBase64, !img.isEmpty {
      task += "\n[ADJUNTO_FOTO_POV_BASE64:\(img)]"
    }
    task += "\nPor favor formatea y envía de inmediato este mensaje/foto a Telegram y confirma el envío."
    return task
  }

  /// Build a structured task string for ejecutar_script_remoto
  static func ejecutarScriptTask(
    comando: String,
    directorio: String? = nil,
    enviarLogTelegram: Bool = true,
    modo: String = "sincrono"
  ) -> String {
    var task = """
    [EJECUTAR_SCRIPT_REMOTO]
    Comando: \(comando)
    Modo: \(modo)
    Enviar Log a Telegram: \(enviarLogTelegram ? "Sí" : "No")
    """
    if let dir = directorio, !dir.isEmpty { task += "\nDirectorio: \(dir)" }
    task += """
    \nInstrucciones para Hermes:
    1. Ejecuta el comando de forma segura en la computadora.
    2. Devuelve una respuesta breve de 1 a 2 frases para que Gemini se la lea al usuario en sus gafas.
    3. Si 'Enviar Log a Telegram' es Sí, envía el log completo, diff o salida formateada a Telegram.
    """
    return task
  }

  /// Build a structured task string for resumen_walk_and_talk
  static func walkAndTalkTask(
    titulo: String,
    ideas: [String],
    actions: [String],
    resumen: String,
    guardarObsidian: Bool = true,
    enviarTelegram: Bool = true,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [WALK_AND_TALK_RESUMEN]
    Título: \(titulo)
    Guardar en Obsidian: \(guardarObsidian ? "Sí (🧠 Ideas)" : "No")
    Enviar a Telegram: \(enviarTelegram ? "Sí" : "No")
    """
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += "\nResumen Ejecutivo:\n\(resumen)"
    if !ideas.isEmpty {
      task += "\nIdeas Clave:\n" + ideas.map { "- \($0)" }.joined(separator: "\n")
    }
    if !actions.isEmpty {
      task += "\nAction Items & To-Dos:\n" + actions.map { "- [ ] \($0)" }.joined(separator: "\n")
    }
    task += "\nPor favor procesa y guarda la nota en Obsidian y despacha el reporte formateado a Telegram."
    return task
  }

  /// Build a structured task string for guardar_referencia_visual
  static func referenciaVisualTask(
    titulo: String,
    descripcion: String,
    touchdesigner: String,
    tags: [String]? = nil,
    fotoBase64: String? = nil,
    enviarTelegram: Bool = true,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [REFERENCIA_VISUAL_TOUCHDESIGNER]
    Título: \(titulo)
    Descripción Visual: \(descripcion)
    Sugerencia TouchDesigner: \(touchdesigner)
    Enviar a Telegram: \(enviarTelegram ? "Sí" : "No")
    """
    if let t = tags, !t.isEmpty { task += "\nTags: \(t.joined(separator: ", "))" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    if let img = fotoBase64, !img.isEmpty {
      task += "\n[ADJUNTO_FOTO_POV_BASE64:\(img)]"
    }
    task += "\nPor favor guarda esta referencia en Obsidian (🎯 TouchDesigner) y envíala con foto a Telegram."
    return task
  }

  /// Build a structured task string for consultar_briefing_diario
  static func briefingDiarioTask(alcance: String, locationContext: String? = nil) -> String {
    var task = """
    [BRIEFING_DIARIO]
    Alcance: \(alcance)
    """
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += """
    \nPor favor consulta las notas del día en Obsidian, tareas pendientes, procesos en la máquina y commits recientes.
    Devuelve un briefing ejecutivo condensado de 3 a 4 oraciones ideal para ser leído en voz alta por las gafas.
    """
    return task
  }
}
