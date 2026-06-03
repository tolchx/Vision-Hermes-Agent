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
    default: return toolName.replacingOccurrences(of: "_", with: " ").capitalized
    }
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
}
