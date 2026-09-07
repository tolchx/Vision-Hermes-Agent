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
      let lower = error.lowercased()
      if lower.contains("timed out") || lower.contains("tiempo") {
        return ["result": "Hermes en la PC está procesando la tarea en segundo plano. Comunica a Tolch por voz que la tarea ya está en marcha en su computadora y que el reporte completo se enviará a Telegram."]
      } else {
        return ["result": "Error al consultar a Hermes en la PC: \(error). Comunica brevemente a Tolch por voz que hubo un problema de conexión con su servidor de Hermes."]
      }
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
    case "delegar_investigacion_profunda": return "brain.head.profile"
    case "capturar_paleta_y_texturas": return "paintpalette.fill"
    case "inspeccionar_pantalla_o_pizarra": return "chevron.left.forwardslash.chevron.right"
    case "recordar_contacto_o_networking": return "person.crop.circle.badge.plus"
    case "registrar_gasto_o_habito": return "creditcard.fill"
    case "repasar_conceptos_vault": return "books.vertical.fill"
    case "monitorear_proceso_o_render": return "gauge.with.needle.fill"
    case "control_ambiente_pc": return "macwindow"
    case "donde_deje_mi_objeto": return "location.magnifyingglass"
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
    case "delegar_investigacion_profunda": return "Investigación"
    case "capturar_paleta_y_texturas": return "Paleta & Textura"
    case "inspeccionar_pantalla_o_pizarra": return "Inspección Código"
    case "recordar_contacto_o_networking": return "Contacto CRM"
    case "registrar_gasto_o_habito": return "Registro Diario"
    case "repasar_conceptos_vault": return "Repaso Vault"
    case "monitorear_proceso_o_render": return "Monitor Render"
    case "control_ambiente_pc": return "Control PC"
    case "donde_deje_mi_objeto": return "Buscar Objeto"
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
      delegarInvestigacionProfunda,
      capturarPaletaYTexturas,
      inspeccionarPantallaOPizarra,
      recordarContactoONetworking,
      registrarGastoOHabito,
      repasarConceptosVault,
      monitorearProcesoORender,
      controlAmbientePC,
      dondeDejeMiObjeto,
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
    "description": "Guarda una respuesta del Gemelo Digital de Tolch en Obsidian. Usar cuando Tolch responda una pregunta profunda sobre su personalidad, valores o historia. REQUIERE: categoria, pregunta y respuesta.",
    "parameters": [
      "type": "object",
      "properties": [
        "categoria": [
          "type": "string",
          "description": "Categoría temática: Filosofía de Vida | Memorias | Relaciones | Creatividad | Miedo | Aspiraciones | Identidad | Tecnología | Ética | Muerte"
        ],
        "pregunta": [
          "type": "string",
          "description": "La pregunta exacta que se le hizo a Tolch"
        ],
        "respuesta": [
          "type": "string",
          "description": "Transcripción completa o resumen detallado de lo que dijo Tolch"
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
    "description": "Guarda una nota rápida en Obsidian. Usar cuando Tolch dice algo que quiere recordar: ideas, tareas, inspiración, algo que vio, algo que pensó. Crea un archivo Markdown en la carpeta 📥 Inbox del vault.",
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
    "description": "Busca información en el vault de Obsidian de Tolch. Usar cuando pregunte algo que pueda estar en sus notas: conceptos de TouchDesigner, proyectos, sesiones pasadas, memoria de Hermes, etc. Devuelve fragmentos relevantes de las notas.",
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
    "description": "Guarda una observación del mundo real captada por la cámara de las gafas. Gemini describe lo que ve y Hermes lo guarda como nota en Obsidian con timestamp y contexto visual. Usar cuando Tolch ve algo interesante, un lugar, un objeto, una persona, una obra de arte, etc. y quiere registrarlo.",
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
          "description": "Contexto de por qué esto es relevante: lo que dijo Tolch al verlo, por qué llamó su atención, qué quiere recordar"
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
    "description": "Consulta a Hermes en la PC qué sesiones están activas, qué proyectos o trabajos se vieron o realizaron hoy ('qué proyectos vimos hoy', 'qué estuvimos haciendo con Hermes hoy'), si estás conectado ('conéctate a Hermes', 'estás conectado'), o tareas en segundo plano. USAR SIEMPRE que Tolch pregunte qué está haciendo Hermes, qué proyectos vimos hoy, o si estás conectado a Hermes.",
    "parameters": [
      "type": "object",
      "properties": [
        "tipo_consulta": [
          "type": "string",
          "description": "Tipo de consulta: proyectos_de_hoy | sesiones_activas | conexion_y_estado | tareas_fondo | estado_general | memoria_reciente",
          "enum": ["proyectos_de_hoy", "sesiones_activas", "conexion_y_estado", "tareas_fondo", "estado_general", "memoria_reciente"]
        ],
        "detalle": [
          "type": "string",
          "description": "Pregunta o aclaración específica de Tolch (ej: 'qué proyectos vimos hoy', 'estás conectado a Hermes')"
        ]
      ],
      "required": ["tipo_consulta"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 8. controlar_tarea_hermes ────────────────────────────────
  static let controlarTareaHermes: [String: Any] = [
    "name": "controlar_tarea_hermes",
    "description": "Envía una orden de control a Hermes para cancelar, pausar o detener una tarea, subagente o proceso en segundo plano. USAR cuando Tolch pida cancelar, parar o abortar una tarea anterior o un proceso de Hermes.",
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
    "description": "Exporta el historial de la conversación actual como archivo Markdown y lo guarda en el vault de Obsidian y/o lo comparte. Usar cuando Tolch pida guardar toda la conversación, exportar el chat, o tener un registro permanente de lo hablado.",
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
    "description": "Envía un reporte formateado en Markdown, resumen de reunión, observación visual, brainstorm o alerta directamente a Telegram (chat privado o canal). Opcionalmente incluye la captura actual de la cámara de las gafas (POV). USAR cuando Tolch pida enviar algo a Telegram, mandar un resumen al celular o compartir una foto/reporte por Telegram.",
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
          "description": "Destino en Telegram si Tolch especifica uno (ej: 'personal', 'trabajo', 'notas'). Opcional."
        ]
      ],
      "required": ["tipo_reporte", "titulo", "contenido_md"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 10. ejecutar_script_remoto ──────────────────────────────

  static let ejecutarScriptRemoto: [String: Any] = [
    "name": "ejecutar_script_remoto",
    "description": "Ejecuta un comando de consola, script de Python, Node.js, Git, Docker o pipeline de TouchDesigner en la computadora de Tolch en casa. Responde por las gafas con una síntesis breve en audio y envía el log completo o diff a Telegram.",
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
    "description": "Sintetiza una caminata de lluvia de ideas, debate o reflexión con Tolch. Extrae ideas principales, action items con prioridades y guarda la nota en Obsidian además de despachar el informe formateado a Telegram.",
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

  // ── 14. delegar_investigacion_profunda ──────────────────────────

  static let delegarInvestigacionProfunda: [String: Any] = [
    "name": "delegar_investigacion_profunda",
    "description": "Delega una investigación técnica, búsqueda de papers/repositorios o análisis profundo a un subagente autónomo de Hermes en la PC. Gemini confirma con 1 frase por las gafas y el subagente entrega el reporte completo con código y enlaces a Telegram y Obsidian. USAR cuando Tolch pida investigar un tema a fondo, buscar código o prototipar algo mientras está en movimiento.",
    "parameters": [
      "type": "object",
      "properties": [
        "tema": [
          "type": "string",
          "description": "Tema o problema tecnológico a investigar a fondo (ej: 'Optimización de shaders GLSL de fluidos en TouchDesigner')"
        ],
        "objetivo": [
          "type": "string",
          "description": "Entregable concreto esperado (ej: 'Código de ejemplo, benchmarks y repos de GitHub')"
        ],
        "entregar_en": [
          "type": "string",
          "description": "Destino principal de la entrega: 'telegram', 'obsidian', o 'ambos' (por defecto: ambos)"
        ],
        "profundidad": [
          "type": "string",
          "description": "Nivel de profundidad: 'rapida' (2-5 min), 'exhaustiva' (10-15 min), 'con_codigo' (desarrolla un prototipo funcional)"
        ]
      ],
      "required": ["tema", "objetivo"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 15. capturar_paleta_y_texturas ───────────────────────────

  static let capturarPaletaYTexturas: [String: Any] = [
    "name": "capturar_paleta_y_texturas",
    "description": "Field Scout cromático y de texturas. Gemini analiza visualmente la escena actual de la cámara de las gafas, extrae los 3 a 5 colores principales en formato hexadecimal (#RRGGBB), analiza balance lumínico y sugiere operadores de TouchDesigner o shaders (Ramp TOP, Noise, Feedback). Guarda la paleta en Obsidian y la envía a Telegram con la foto.",
    "parameters": [
      "type": "object",
      "properties": [
        "titulo": [
          "type": "string",
          "description": "Título descriptivo de la referencia (ej: 'Iluminación Neón Ciberpunk en Vidriera')"
        ],
        "tipo": [
          "type": "string",
          "description": "Tipo de análisis: 'paleta_color', 'textura_shader', o 'ambos'"
        ],
        "paleta_hex": [
          "type": "array",
          "items": ["type": "string"],
          "description": "Lista de 3 a 5 códigos HEX representativos detectados en la escena (ej: ['#FF0055', '#00E5FF', '#1A0B2E'])"
        ],
        "analisis_estetico": [
          "type": "string",
          "description": "Descripción de la iluminación, contraste, tipo de ruido visual o composición espacial"
        ],
        "sugerencia_touchdesigner": [
          "type": "string",
          "description": "Operadores (TOPs, CHOPs) o técnicas recomendadas en TouchDesigner (ej: 'Feedback TOP con Slope y Ramp TOP')"
        ]
      ],
      "required": ["titulo", "paleta_hex", "sugerencia_touchdesigner"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 16. inspeccionar_pantalla_o_pizarra ───────────────────────

  static let inspeccionarPantallaOPizarra: [String: Any] = [
    "name": "inspeccionar_pantalla_o_pizarra",
    "description": "Inspecciona mediante la cámara de las gafas una pantalla de computadora (terminal con error, código fuente en IDE) o una pizarra con diagramas/notas. Gemini transcribe el error o diagrama, explica la solución o lo traduce a sintaxis Mermaid / código, y Hermes lo guarda en Obsidian o ejecuta el parche.",
    "parameters": [
      "type": "object",
      "properties": [
        "contexto": [
          "type": "string",
          "description": "Qué se está observando (ej: 'Error en consola de Python', 'Diagrama de arquitectura en pizarra', 'Shader GLSL en TouchDesigner')"
        ],
        "accion_requerida": [
          "type": "string",
          "description": "Acción a realizar: 'explicar_error', 'convertir_a_mermaid', 'generar_parche_git', 'guardar_apuntes'"
        ],
        "analisis_visual": [
          "type": "string",
          "description": "Detalle técnico de lo leído en pantalla o pizarra por Gemini"
        ],
        "codigo_o_diagrama": [
          "type": "string",
          "description": "Código sugerido, diagrama en sintaxis Mermaid o solución en texto (opcional)"
        ]
      ],
      "required": ["contexto", "accion_requerida", "analisis_visual"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 17. recordar_contacto_o_networking ───────────────────────

  static let recordarContactoONetworking: [String: Any] = [
    "name": "recordar_contacto_o_networking",
    "description": "Registra una interacción de networking o contacto nuevo después de una conversación. Guarda el nombre, rol, temas tratados, compromisos asumidos, fecha y ubicación GPS en Obsidian (🤝 Contactos) y agenda un recordatorio de seguimiento en Telegram.",
    "parameters": [
      "type": "object",
      "properties": [
        "nombre": [
          "type": "string",
          "description": "Nombre de la persona o contacto (ej: 'Martín Gómez')"
        ],
        "rol_o_empresa": [
          "type": "string",
          "description": "Puesto, empresa o proyecto de la persona (ej: 'Director de Arte en Estudio Lumina')"
        ],
        "contexto_charla": [
          "type": "string",
          "description": "Resumen de lo conversado, intereses compartidos o sinergias identificadas"
        ],
        "compromiso_o_proximo_paso": [
          "type": "string",
          "description": "Acción prometida o acordada (ej: 'Escribirle el martes para enviarle demo de TouchDesigner')"
        ],
        "tags": [
          "type": "array",
          "items": ["type": "string"],
          "description": "Etiquetas temáticas (ej: ['networking', 'arte-digital', 'cliente'])"
        ]
      ],
      "required": ["nombre", "contexto_charla"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 18. registrar_gasto_o_habito ─────────────────────────────

  static let registrarGastoOHabito: [String: Any] = [
    "name": "registrar_gasto_o_habito",
    "description": "Registra rápidamente por voz un gasto financiero, hábito personal (agua, lectura, ejercicio) o métrica diaria. Hermes agrega la entrada con fecha y hora en las notas de registro de Obsidian (Dataview) y Gemini responde confirmando el total acumulado.",
    "parameters": [
      "type": "object",
      "properties": [
        "tipo_registro": [
          "type": "string",
          "description": "Tipo: 'gasto', 'ingreso', 'habito', 'metrica'"
        ],
        "valor": [
          "type": "string",
          "description": "Monto o cantidad (ej: '$4500', '20 minutos', '2 litros')"
        ],
        "concepto": [
          "type": "string",
          "description": "Descripción de la transacción o actividad (ej: 'Café con medialunas', 'Entrenamiento tren superior')"
        ],
        "categoria": [
          "type": "string",
          "description": "Categoría opcional (ej: 'Alimentación', 'Transporte', 'Salud', 'Educación')"
        ],
        "medio_pago": [
          "type": "string",
          "description": "Medio de pago si es gasto (ej: 'Efectivo', 'Tarjeta Débito', 'MercadoPago')"
        ]
      ],
      "required": ["tipo_registro", "valor", "concepto"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 19. repasar_conceptos_vault ──────────────────────────────

  static let repasarConceptosVault: [String: Any] = [
    "name": "repasar_conceptos_vault",
    "description": "Modo 'Walk & Learn'. Hermes consulta las notas del Vault de Obsidian sobre un tema solicitado y extrae conceptos o preguntas clave. Gemini actúa como un tutor interactivo por voz mientras Tolch camina, haciéndole preguntas socráticas breves y profundizando según sus respuestas.",
    "parameters": [
      "type": "object",
      "properties": [
        "tema_o_carpeta": [
          "type": "string",
          "description": "Tema o carpeta de Obsidian a repasar (ej: 'TouchDesigner', 'Filosofía', 'Arquitectura de Software')"
        ],
        "modo": [
          "type": "string",
          "description": "Modo de repaso: 'pregunta_socratica', 'resumen_audio', 'flashcard'"
        ],
        "concepto_especifico": [
          "type": "string",
          "description": "Concepto o nota específica si Tolch quiere enfocarse en algo puntual (opcional)"
        ]
      ],
      "required": ["tema_o_carpeta"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 20. monitorear_proceso_o_render ──────────────────────────

  static let monitorearProcesoORender: [String: Any] = [
    "name": "monitorear_proceso_o_render",
    "description": "Supervisa en tiempo real el progreso de renders de TouchDesigner, contenedores de Docker, scripts de Python o el uso de GPU/CPU en la computadora de casa. Permite consultar el porcentaje de avance o programar una notificación a Telegram cuando el render finalice.",
    "parameters": [
      "type": "object",
      "properties": [
        "proceso": [
          "type": "string",
          "description": "Proceso a inspeccionar: 'touchdesigner', 'docker', 'python', 'gpu', 'todos'"
        ],
        "accion": [
          "type": "string",
          "description": "Acción: 'consultar_progreso', 'notificar_al_terminar', 'cancelar'"
        ],
        "condicion_aviso": [
          "type": "string",
          "description": "Condición para avisar (ej: 'al terminar el render', 'si la GPU supera 85 grados')"
        ]
      ],
      "required": ["proceso", "accion"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 21. control_ambiente_pc ──────────────────────────────────

  static let controlAmbientePC: [String: Any] = [
    "name": "control_ambiente_pc",
    "description": "Ejecuta acciones de control del sistema en la computadora de casa a distancia: bloquear la pantalla, suspender el equipo, silenciar el audio, o abrir una aplicación/proyecto específico (ej: archivo .toe de TouchDesigner o el Vault de Obsidian).",
    "parameters": [
      "type": "object",
      "properties": [
        "accion": [
          "type": "string",
          "description": "Acción: 'bloquear_pantalla', 'suspender', 'abrir_app_o_proyecto', 'silenciar_audio', 'ejecutar_atajo'"
        ],
        "objetivo": [
          "type": "string",
          "description": "Nombre de la aplicación, archivo de proyecto o atajo a ejecutar (ej: 'TouchDesigner Mapping.toe', 'Spotify')"
        ]
      ],
      "required": ["accion"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]

  // ── 22. donde_deje_mi_objeto ─────────────────────────────────

  static let dondeDejeMiObjeto: [String: Any] = [
    "name": "donde_deje_mi_objeto",
    "description": "Memoria visual temporal para objetos cotidianos (llaves, billetera, mochila, lentes). Consulta el buffer temporal de fotogramas recientes capturados por las gafas, identifica cuándo y dónde fue visto el objeto por última vez y le informa a Tolch verbalmente y con foto a Telegram.",
    "parameters": [
      "type": "object",
      "properties": [
        "objeto": [
          "type": "string",
          "description": "Nombre del objeto a localizar (ej: 'llaves', 'billetera', 'mochila', 'cargador')"
        ],
        "contexto_lugar": [
          "type": "string",
          "description": "Lugar o ambiente donde cree haberlo dejado (opcional, ej: 'en casa', 'en el auto', 'en la oficina')"
        ]
      ],
      "required": ["objeto"]
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
    if tipo == "proyectos_de_hoy" || (detalle?.lowercased().contains("proyecto") ?? false) {
      task += "\nTolch te pregunta a través de las gafas Meta Ray-Ban qué proyectos o trabajos vimos con Hermes hoy. Revisa las sesiones de hoy, notas y cron jobs, y responde en 2 o 3 frases claras y concisas para ser leídas por voz."
    } else if tipo == "conexion_y_estado" || (detalle?.lowercased().contains("conecta") ?? false) {
      task += "\nTolch te pregunta a través de las gafas si la conexión con Hermes está activa. Confirma brevemente que estás conectado y listo para asistirle."
    } else {
      task += "\nPor favor responde en 1 a 3 frases concisas para ser leídas por voz a través de las gafas Meta Ray-Ban: informa sobre las sesiones activas, tareas en segundo plano y estado actual."
    }
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
    2. Devuelve una respuesta breve de 1 a 2 frases para que Gemini se la lea a Tolch en sus gafas.
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

  /// Build a structured task string for delegar_investigacion_profunda
  static func investigacionProfundaTask(
    tema: String,
    objetivo: String,
    entregarEn: String? = nil,
    profundidad: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [INVESTIGACION_PROFUNDA]
    Tema: \(tema)
    Objetivo: \(objetivo)
    Entregar en: \(entregarEn ?? "ambos (Telegram y Obsidian)")
    Profundidad: \(profundidad ?? "con_codigo")
    """
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += """
    \nINSTRUCCIÓN CRÍTICA DE RESPUESTA:
    Tolch te está hablando desde las gafas Meta Ray-Ban.
    1. Responde INMEDIATAMENTE en 1 o 2 frases breves confirmando que iniciaste la investigación y que le enviarás el reporte y código a Telegram.
    2. Ejecuta la investigación, el prototipo y el informe en segundo plano y envía todo el resultado completo a Telegram y Obsidian.
    3. NO ejecutes múltiples ciclos de herramientas síncronas antes de emitir tu primera respuesta hablada.
    """
    return task
  }

  /// Build a structured task string for capturar_paleta_y_texturas
  static func paletaTexturasTask(
    titulo: String,
    tipo: String? = nil,
    paletaHex: [String],
    analisisEstetico: String? = nil,
    sugerenciaTD: String,
    fotoBase64: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [FIELD_SCOUT_PALETA]
    Título: \(titulo)
    Tipo: \(tipo ?? "ambos")
    Paleta HEX: \(paletaHex.joined(separator: ", "))
    Sugerencia TouchDesigner: \(sugerenciaTD)
    """
    if let a = analisisEstetico, !a.isEmpty { task += "\nAnálisis Estético: \(a)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    if let img = fotoBase64, !img.isEmpty { task += "\n[ADJUNTO_FOTO_POV_BASE64:\(img)]" }
    task += """
    \nPor favor guarda esta paleta y notas en Obsidian (🎯 TouchDesigner/Paletas) con bloques de color y sugerencia de nodos, y despacha la muestra con foto a Telegram.
    """
    return task
  }

  /// Build a structured task string for inspeccionar_pantalla_o_pizarra
  static func inspeccionPantallaPizarraTask(
    contexto: String,
    accionRequerida: String,
    analisisVisual: String,
    codigoODiagrama: String? = nil,
    fotoBase64: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [INSPECCION_VISUAL_CODE]
    Contexto: \(contexto)
    Acción Requerida: \(accionRequerida)
    Análisis Visual: \(analisisVisual)
    """
    if let c = codigoODiagrama, !c.isEmpty { task += "\nCódigo o Diagrama:\n\(c)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    if let img = fotoBase64, !img.isEmpty { task += "\n[ADJUNTO_FOTO_POV_BASE64:\(img)]" }
    task += """
    \nInstrucciones para Hermes:
    - Si la acción es 'convertir_a_mermaid', guarda el diagrama en Obsidian.
    - Si la acción es 'generar_parche_git' o 'explicar_error', analiza el código en tu entorno local y envía la explicación detallada o diff a Telegram.
    - Devuelve una síntesis hablada de 1 a 2 frases para las gafas.
    """
    return task
  }

  /// Build a structured task string for recordar_contacto_o_networking
  static func recordarContactoTask(
    nombre: String,
    rolOEmpresa: String? = nil,
    contextoCharla: String,
    compromisoOProximoPaso: String? = nil,
    tags: [String]? = nil,
    fotoBase64: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [CRM_NETWORKING]
    Nombre: \(nombre)
    Contexto de la Charla: \(contextoCharla)
    """
    if let r = rolOEmpresa, !r.isEmpty { task += "\nRol / Empresa: \(r)" }
    if let comp = compromisoOProximoPaso, !comp.isEmpty { task += "\nCompromiso / Próximo Paso: \(comp)" }
    if let t = tags, !t.isEmpty { task += "\nTags: \(t.joined(separator: ", "))" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    if let img = fotoBase64, !img.isEmpty { task += "\n[ADJUNTO_FOTO_POV_BASE64:\(img)]" }
    task += """
    \nPor favor crea la ficha de contacto en Obsidian (🤝 Contactos/\(nombre).md), y agenda un recordatorio en Telegram para el próximo paso.
    """
    return task
  }

  /// Build a structured task string for registrar_gasto_o_habito
  static func registroGastoHabitoTask(
    tipoRegistro: String,
    valor: String,
    concepto: String,
    categoria: String? = nil,
    medioPago: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [REGISTRO_DIARIO]
    Tipo: \(tipoRegistro)
    Valor: \(valor)
    Concepto: \(concepto)
    """
    if let c = categoria, !c.isEmpty { task += "\nCategoría: \(c)" }
    if let m = medioPago, !m.isEmpty { task += "\nMedio de Pago: \(m)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += """
    \nPor favor agrega esta entrada a la tabla correspondiente en Obsidian (📊 Finanzas o Registro Diario). Devuelve una confirmación concisa con el total del día para ser hablada por las gafas.
    """
    return task
  }

  /// Build a structured task string for repasar_conceptos_vault
  static func repasoConceptosVaultTask(
    temaOCarpeta: String,
    modo: String? = nil,
    conceptoEspecifico: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [WALK_AND_LEARN_VAULT]
    Tema o Carpeta: \(temaOCarpeta)
    Modo: \(modo ?? "pregunta_socratica")
    """
    if let c = conceptoEspecifico, !c.isEmpty { task += "\nConcepto Específico: \(c)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += """
    \nPor favor busca en las notas de Obsidian sobre este tema y devuelve 2 a 3 conceptos clave con una pregunta socrática breve para que Gemini se la haga a Tolch por las gafas.
    """
    return task
  }

  /// Build a structured task string for monitorear_proceso_o_render
  static func monitorearProcesoTask(
    proceso: String,
    accion: String,
    condicionAviso: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [MONITOR_PROCESO_PC]
    Proceso: \(proceso)
    Acción: \(accion)
    """
    if let c = condicionAviso, !c.isEmpty { task += "\nCondición de Aviso: \(c)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += """
    \nPor favor inspecciona el estado de los procesos locales en la PC (TouchDesigner render, contenedores Docker, scripts Python, uso GPU).
    Devuelve un estado condensado en 1 o 2 frases para las gafas y, si se solicitó notificación, programa el mensaje a Telegram al terminar.
    """
    return task
  }

  /// Build a structured task string for control_ambiente_pc
  static func controlAmbientePCTask(
    accion: String,
    objetivo: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [CONTROL_AMBIENTE_PC]
    Acción: \(accion)
    """
    if let obj = objetivo, !obj.isEmpty { task += "\nObjetivo: \(obj)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación: \(loc)" }
    task += """
    \nEjecuta la orden de control de forma segura en la computadora y responde con 1 frase de confirmación para las gafas.
    """
    return task
  }

  /// Build a structured task string for donde_deje_mi_objeto
  static func dondeDejeObjetoTask(
    objeto: String,
    contextoLugar: String? = nil,
    timelineContext: String? = nil,
    locationContext: String? = nil
  ) -> String {
    var task = """
    [BUSQUEDA_OBJETO_TEMPORAL]
    Objeto buscado: \(objeto)
    """
    if let c = contextoLugar, !c.isEmpty { task += "\nContexto de Lugar: \(c)" }
    if let loc = locationContext, !loc.isEmpty { task += "\nUbicación Actual: \(loc)" }
    if let tl = timelineContext, !tl.isEmpty { task += "\n\(tl)" }
    task += """
    \nInstrucciones:
    1. Analiza el historial de escenas recientes capturadas por las gafas para estimar cuándo y dónde pudo haber quedado el objeto.
    2. Responde a las gafas con una frase directa e intuitiva (ej: "Las llaves fueron vistas hace unos 15 minutos cerca de la mesa del living").
    3. Si hay un fotograma relevante, envía la confirmación con la foto a Telegram.
    """
    return task
  }
}

