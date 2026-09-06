import SwiftUI
import Foundation

// MARK: - GeminiStatusBar (Rediseñada: punto único expandible)
// Muestra un solo punto de estado global. Al tocarlo, despliega detalles.

struct GeminiStatusBar: View {
  @ObservedObject var geminiVM: GeminiSessionViewModel
  @State private var isExpanded = false

  var body: some View {
    let state = overallState

    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        isExpanded.toggle()
      }
    } label: {
      HStack(spacing: 8) {
        // Círculo de estado principal
        Circle()
          .fill(state.color)
          .frame(width: 10, height: 10)
          .overlay(
            Circle()
              .stroke(state.color.opacity(0.3), lineWidth: 3)
              .scaleEffect(state.isPulsing ? 1.5 : 1.0)
              .opacity(state.isPulsing ? 0 : 0.6)
          )

        if isExpanded {
          // Detalles expandidos
          HStack(spacing: 10) {
            // Gemini
            HStack(spacing: 4) {
              Circle().fill(geminiColor).frame(width: 6, height: 6)
              Text(geminiLetter)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            // Hermes
            HStack(spacing: 4) {
              Circle().fill(hermesColor).frame(width: 6, height: 6)
              Text(hermesLetter)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
            }

            // Speaker toggle
            Button {
              geminiVM.toggleSpeaker()
            } label: {
              Image(systemName: geminiVM.isSpeakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 10))
                .foregroundColor(geminiVM.isSpeakerOn ? .cyan : .gray)
            }
            .buttonStyle(.plain)

            // Model speaking indicator
            if geminiVM.isModelSpeaking {
              Image(systemName: "waveform")
                .font(.system(size: 10))
                .foregroundColor(.cyan)
            }
          }
          .transition(.opacity.combined(with: .move(edge: .leading)))
        }
      }
      .padding(.horizontal, isExpanded ? 12 : 10)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(.ultraThinMaterial)
          .overlay(
            Capsule()
              .stroke(state.color.opacity(0.3), lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
  }

  // Estado global: peor estado entre Gemini + Hermes
  private var overallState: (color: Color, isPulsing: Bool) {
    // Prioridad: rojo > amarillo > verde > gris
    let gemState = (geminiVM.connectionState, geminiVM.hermesConnectionState)

    if case .error = gemState.0 { return (.red, false) }
    if case .unreachable = gemState.1 { return (.red, false) }
    if case .connecting = gemState.0 { return (.yellow, true) }
    if case .checking = gemState.1 { return (.yellow, true) }
    if case .settingUp = gemState.0 { return (.yellow, true) }
    if case .ready = gemState.0, case .connected = gemState.1 { return (.green, false) }
    if case .ready = gemState.0 { return (.green, false) }
    return (.gray, false)
  }

  private var geminiColor: Color {
    switch geminiVM.connectionState {
    case .ready: return .green
    case .connecting, .settingUp: return .yellow
    case .error: return .red
    case .disconnected: return .gray
    }
  }

  private var geminiLetter: String {
    switch geminiVM.connectionState {
    case .ready: return "G"
    case .connecting, .settingUp: return "~"
    case .error: return "!"
    case .disconnected: return "-"
    }
  }

  private var hermesColor: Color {
    switch geminiVM.hermesConnectionState {
    case .connected: return .green
    case .checking: return .yellow
    case .unreachable: return .red
    case .notConfigured: return .gray
    }
  }

  private var hermesLetter: String {
    switch geminiVM.hermesConnectionState {
    case .connected: return "H"
    case .checking: return "~"
    case .unreachable: return "!"
    case .notConfigured: return "-"
    }
  }
}

// MARK: - ToolCallStatusView (iconos + texto corto)

struct ToolCallStatusView: View {
  let status: ToolCallStatus

  var body: some View {
    if status != .idle {
      HStack(spacing: 8) {
 switch status {
        case .executing(let name):
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            .scaleEffect(0.7)
          Image(systemName: ToolIcon.icon(for: name))
            .font(.system(size: 14))
            .foregroundColor(.cyan)
          Text(ToolIcon.shortName(for: name))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)

        case .completed(let name):
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.system(size: 14))
          Image(systemName: ToolIcon.icon(for: name))
            .font(.system(size: 12))
            .foregroundColor(.green.opacity(0.8))
          Text(ToolIcon.shortName(for: name))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.green)

        case .failed(let name, let error):
          Image(systemName: "exclamationmark.circle.fill")
            .foregroundColor(.red)
            .font(.system(size: 14))
          Image(systemName: ToolIcon.icon(for: name))
            .font(.system(size: 12))
            .foregroundColor(.red.opacity(0.8))
          Text(shortError(error))
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.red)
            .lineLimit(1)

        case .cancelled(let name):
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.yellow)
            .font(.system(size: 14))
          Text(ToolIcon.shortName(for: name))
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.yellow)

        case .idle:
          EmptyView()
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(
        Capsule()
          .fill(.ultraThinMaterial)
          .overlay(
            Capsule()
              .stroke(Color.white.opacity(0.1), lineWidth: 1)
          )
      )
      .transition(.scale.combined(with: .opacity))
    }
  }

  private func shortError(_ error: String) -> String {
    if error.hasPrefix("HTTP") { return error }
    if error.count > 30 { return String(error.prefix(28)) + "…" }
    return error
  }
}


// MARK: - GenerativeToolCardView (Tarjetas Generativas UI Interactivas)

struct GenerativeToolCardView: View {
  let toolInfo: ActiveToolCallInfo
  var onDismiss: (() -> Void)? = nil

  @State private var isExpanded: Bool = true
  @State private var autoCollapseTask: Task<Void, Never>? = nil

  private var toolName: String { toolInfo.toolName }
  private var args: [String: Any] { toolInfo.args }

  private var accentColor: Color {
    switch toolName {
    case "guardar_nota_rapida": return DS.Color.accentPurple
    case "buscar_en_vault": return DS.Color.accentCyan
    case "guardar_observacion": return Color.orange
    case "gemelo_guardar_respuesta": return Color.pink
    case "consultar_estado_hermes": return Color.teal
    case "controlar_tarea_hermes": return Color.red
    case "enviar_reporte_telegram": return Color(red: 0.0, green: 0.55, blue: 0.9)
    case "ejecutar_script_remoto": return Color(red: 0.1, green: 0.85, blue: 0.4)
    case "resumen_walk_and_talk": return Color(red: 0.65, green: 0.35, blue: 0.95)
    case "guardar_referencia_visual": return Color(red: 1.0, green: 0.6, blue: 0.1)
    case "consultar_briefing_diario": return Color(red: 1.0, green: 0.8, blue: 0.2)
    case "delegar_investigacion_profunda": return Color(red: 0.45, green: 0.35, blue: 0.95)
    case "capturar_paleta_y_texturas": return Color(red: 0.95, green: 0.25, blue: 0.65)
    case "inspeccionar_pantalla_o_pizarra": return Color(red: 0.1, green: 0.8, blue: 0.8)
    case "recordar_contacto_o_networking": return Color(red: 0.2, green: 0.85, blue: 0.5)
    case "registrar_gasto_o_habito": return Color(red: 0.95, green: 0.75, blue: 0.2)
    case "repasar_conceptos_vault": return Color(red: 1.0, green: 0.5, blue: 0.3)
    case "monitorear_proceso_o_render": return Color(red: 0.2, green: 0.6, blue: 1.0)
    case "control_ambiente_pc": return Color(red: 0.6, green: 0.4, blue: 0.85)
    case "donde_deje_mi_objeto": return Color(red: 0.95, green: 0.2, blue: 0.5)
    default: return DS.Color.accentCyan
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Header: Icon + Tool Name + Status Badge + Actions
      HStack(spacing: 8) {
        // Icon Circle
        ZStack {
          Circle()
            .fill(accentColor.opacity(0.2))
            .frame(width: 32, height: 32)
          Image(systemName: ToolIcon.icon(for: toolName))
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(accentColor)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(cardTitle)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)

          HStack(spacing: 6) {
            statusBadge
            if let folder = args["carpeta"] as? String {
              Text(folder)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
          }
        }

        Spacer()

        // Toggle Expand
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
          }
        } label: {
          Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
            .font(.system(size: 18))
            .foregroundColor(.white.opacity(0.5))
        }
        .buttonStyle(.plain)

        // Dismiss Button
        if let onDismiss {
          Button(action: onDismiss) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 18))
              .foregroundColor(.white.opacity(0.4))
          }
          .buttonStyle(.plain)
        }
      }

      // Expandable Body
      if isExpanded {
        VStack(alignment: .leading, spacing: 8) {
          Divider().background(Color.white.opacity(0.1))

          switch toolName {
          case "guardar_nota_rapida":
            notaView

          case "buscar_en_vault":
            buscarView

          case "guardar_observacion":
            observacionView

          case "gemelo_guardar_respuesta":
            gemeloView

          case "consultar_estado_hermes":
            hermesStatusView

          case "controlar_tarea_hermes":
            controlarTareaView

          case "enviar_reporte_telegram":
            telegramReporteView

          case "ejecutar_script_remoto":
            scriptRemotoView

          case "resumen_walk_and_talk":
            walkAndTalkView

          case "guardar_referencia_visual":
            referenciaVisualView

          case "consultar_briefing_diario":
            briefingDiarioView

          case "delegar_investigacion_profunda":
            investigacionProfundaView

          case "capturar_paleta_y_texturas":
            paletaTexturasView

          case "inspeccionar_pantalla_o_pizarra":
            inspeccionPantallaView

          case "recordar_contacto_o_networking":
            contactoNetworkingView

          case "registrar_gasto_o_habito":
            registroGastoHabitoView

          case "repasar_conceptos_vault":
            repasoConceptosVaultView

          case "monitorear_proceso_o_render":
            monitoreoProcesoView

          case "control_ambiente_pc":
            controlAmbienteView

          case "donde_deje_mi_objeto":
            dondeDejeObjetoView

          default:
            genericTaskView
          }

          // Result view if completed
          if case .completed(let result) = toolInfo.state, !result.isEmpty, toolName != "buscar_en_vault" {
            HStack(alignment: .top, spacing: 6) {
              Image(systemName: "sparkle")
                .font(.system(size: 10))
                .foregroundColor(accentColor)
                .padding(.top, 2)
              Text(result.prefix(160) + (result.count > 160 ? "…" : ""))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.75))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
          } else if case .failed(let err) = toolInfo.state {
            Text("Error: \(err)")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.red.opacity(0.9))
          }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 18)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 18)
            .stroke(accentColor.opacity(0.35), lineWidth: 1.2)
        )
        .shadow(color: accentColor.opacity(0.15), radius: 8, x: 0, y: 3)
    )
    .onAppear {
      scheduleAutoCollapse()
    }
    .onChange(of: toolInfo.state) {
      if case .completed = toolInfo.state {
        scheduleAutoCollapse(delay: 4.0)
      }
    }
  }

  // MARK: - Subviews by Tool

  private var cardTitle: String {
    switch toolName {
    case "guardar_nota_rapida": return "Nota en Obsidian"
    case "buscar_en_vault": return "Búsqueda en Vault"
    case "guardar_observacion": return "Observación Visual"
    case "gemelo_guardar_respuesta": return "Avatar Personal"
    case "exportar_chat_md": return "Exportar Chat MD"
    case "consultar_estado_hermes": return "Estado de Hermes (Cloudflare)"
    case "controlar_tarea_hermes": return "Control de Tarea"
    case "enviar_reporte_telegram": return "Reporte Telegram"
    case "ejecutar_script_remoto": return "Terminal Remoto"
    case "resumen_walk_and_talk": return "Walk & Talk"
    case "guardar_referencia_visual": return "Field Scout (TouchDesigner)"
    case "consultar_briefing_diario": return "Briefing Diario"
    case "delegar_investigacion_profunda": return "Investigación Autónoma"
    case "capturar_paleta_y_texturas": return "Paleta & Texturas"
    case "inspeccionar_pantalla_o_pizarra": return "Inspección de Código"
    case "recordar_contacto_o_networking": return "Contacto de Networking"
    case "registrar_gasto_o_habito": return "Registro Rápido"
    case "repasar_conceptos_vault": return "Walk & Learn (Vault)"
    case "monitorear_proceso_o_render": return "Monitor de Render / PC"
    case "control_ambiente_pc": return "Control Remoto PC"
    case "donde_deje_mi_objeto": return "¿Dónde dejé mi objeto?"
    default: return ToolIcon.shortName(for: toolName)
    }
  }

  @ViewBuilder
  private var statusBadge: some View {
    switch toolInfo.state {
    case .executing:
      HStack(spacing: 4) {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
          .scaleEffect(0.6)
        Text("Guardando...")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(accentColor)
      }
    case .completed:
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 11))
          .foregroundColor(.green)
        Text("Listo")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.green)
      }
    case .failed:
      HStack(spacing: 4) {
        Image(systemName: "exclamationmark.circle.fill")
          .font(.system(size: 11))
          .foregroundColor(.red)
        Text("Falló")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.red)
      }
    case .cancelled:
      HStack(spacing: 4) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 11))
          .foregroundColor(.yellow)
        Text("Cancelado")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.yellow)
      }
    }
  }

  private var notaView: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let titulo = args["titulo"] as? String {
        Text(titulo)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white)
      }
      if let contenido = args["contenido"] as? String {
        Text(contenido)
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(3)
      }
    }
  }

  private var buscarView: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let query = args["consulta"] as? String {
        HStack(spacing: 4) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 10))
            .foregroundColor(accentColor)
          Text("\"\(query)\"")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
        }
      }

      if case .completed(let result) = toolInfo.state {
        Text(result.prefix(200) + (result.count > 200 ? "…" : ""))
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.8))
          .padding(8)
          .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)))
      }
    }
  }

  private var observacionView: some View {
    HStack(alignment: .top, spacing: 10) {
      if let image = toolInfo.snapshotImage {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 70, height: 70)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
      }

      VStack(alignment: .leading, spacing: 4) {
        if let titulo = args["titulo"] as? String {
          Text(titulo)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
        }
        if let desc = args["descripcion"] as? String {
          Text(desc)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(2)
        }
        if let tags = args["tags"] as? [String], !tags.isEmpty {
          HStack(spacing: 4) {
            ForEach(tags.prefix(3), id: \.self) { tag in
              Text("#\(tag)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.orange)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
          }
        }
      }
    }
  }

  private var gemeloView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let cat = args["categoria"] as? String {
          Text(cat)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(Color.pink)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.pink.opacity(0.15)))
        }
        if let emocion = args["analisis_emocion"] as? String {
          Text("🎭 \(emocion)")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        }
      }

      if let pregunta = args["pregunta"] as? String {
        Text("P: \(pregunta)")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.9))
      }
      if let respuesta = args["respuesta"] as? String {
        Text("R: \(respuesta)")
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.75))
          .lineLimit(2)
      }
    }
  }

  private var hermesStatusView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let tipo = args["tipo_consulta"] as? String {
          Text(tipo.replacingOccurrences(of: "_", with: " ").uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(Color.teal)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.teal.opacity(0.15)))
        }

        HStack(spacing: 4) {
          Circle().fill(Color.green).frame(width: 6, height: 6)
          Text("Cloudflare Tunnel")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
        }
      }

      if let detalle = args["detalle"] as? String, !detalle.isEmpty {
        Text(detalle)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.9))
      }

      if case .completed(let result) = toolInfo.state {
        VStack(alignment: .leading, spacing: 4) {
          Text(result)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white.opacity(0.85))
            .lineLimit(6)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.35)))
      }
    }
  }

  private var controlarTareaView: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        if let accion = args["accion"] as? String {
          Text(accion.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.red)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.red.opacity(0.15)))
        }
        if let objetivo = args["objetivo"] as? String {
          Text("Objetivo: \(objetivo)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
        }
      }
    }
  }

  private var genericTaskView: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let task = args["task"] as? String {
        Text(task)
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(3)
      }
    }
  }

  private var telegramReporteView: some View {
    HStack(alignment: .top, spacing: 10) {
      if let image = toolInfo.snapshotImage {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 70, height: 70)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            ZStack(alignment: .bottomTrailing) {
              RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1)
              Image(systemName: "camera.fill")
                .font(.system(size: 9))
                .foregroundColor(.white)
                .padding(4)
                .background(Circle().fill(Color.black.opacity(0.6)))
                .padding(3)
            }
          )
      }

      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 5) {
          if let tipo = args["tipo_reporte"] as? String {
            Text(tipo.replacingOccurrences(of: "_", with: " ").uppercased())
              .font(.system(size: 9, weight: .bold))
              .foregroundColor(accentColor)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Capsule().fill(accentColor.opacity(0.15)))
          }

          HStack(spacing: 3) {
            Image(systemName: "paperplane.fill")
              .font(.system(size: 8))
              .foregroundColor(.white.opacity(0.8))
            Text(args["canal_o_chat"] as? String ?? "Telegram")
              .font(.system(size: 9, weight: .medium))
              .foregroundColor(.white.opacity(0.8))
          }
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Capsule().fill(Color.white.opacity(0.1)))
        }

        if let titulo = args["titulo"] as? String {
          Text(titulo)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
        }

        if let contenido = args["contenido_md"] as? String {
          Text(contenido)
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(2)
        }
      }
    }
  }

  private var scriptRemotoView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        HStack(spacing: 4) {
          Circle().fill(accentColor).frame(width: 6, height: 6)
          Text("PC Remota")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        }

        if let modo = args["modo_ejecucion"] as? String {
          Text(modo == "segundo_plano" ? "⏳ Segundo Plano" : "⚡ Síncrono")
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(accentColor.opacity(0.15)))
        }

        if let log = args["enviar_log_a_telegram"] as? Bool, log {
          Text("📲 Log a Telegram")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.blue.opacity(0.2)))
        }
      }

      if let comando = args["comando_o_script"] as? String {
        HStack(spacing: 4) {
          Text("$")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(accentColor)
          Text(comando)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.white)
            .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
      }

      if let dir = args["directorio_trabajo"] as? String, !dir.isEmpty {
        Text("📁 \(dir)")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.5))
      }
    }
  }

  private var walkAndTalkView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Text("🚶‍♂️ Sesión de Caminata")
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(accentColor)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Capsule().fill(accentColor.opacity(0.15)))

        HStack(spacing: 4) {
          Text("🧠 Obsidian + 📲 Telegram")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.08)))
      }

      if let titulo = args["titulo"] as? String {
        Text(titulo)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white)
      }

      if let resumen = args["resumen_ejecutivo"] as? String {
        Text(resumen)
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(2)
      }

      if let actions = args["action_items"] as? [String], !actions.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(actions.prefix(2), id: \.self) { item in
            HStack(spacing: 4) {
              Image(systemName: "checkmark.square")
                .font(.system(size: 9))
                .foregroundColor(accentColor)
              Text(item)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(1)
            }
          }
        }
      }
    }
  }

  private var referenciaVisualView: some View {
    HStack(alignment: .top, spacing: 10) {
      if let image = toolInfo.snapshotImage {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 70, height: 70)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
      }

      VStack(alignment: .leading, spacing: 4) {
        if let titulo = args["titulo"] as? String {
          Text(titulo)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
        }

        if let td = args["sugerencia_touchdesigner"] as? String {
          Text("💡 TD: \(td)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(accentColor)
            .lineLimit(2)
        }

        if let tags = args["tags"] as? [String], !tags.isEmpty {
          HStack(spacing: 4) {
            ForEach(tags.prefix(3), id: \.self) { tag in
              Text("#\(tag)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(accentColor)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(accentColor.opacity(0.15)))
            }
          }
        }
      }
    }
  }

  private var briefingDiarioView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: "sun.max.fill")
            .font(.system(size: 10))
            .foregroundColor(accentColor)
          Text("Briefing del Día")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Capsule().fill(accentColor.opacity(0.2)))

        if let alcance = args["alcance"] as? String {
          Text(alcance.uppercased())
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
      }

      if case .completed(let result) = toolInfo.state {
        Text(result)
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(4)
          .padding(8)
          .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)))
      }
    }
  }

  private var investigacionProfundaView: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let tema = args["tema"] as? String {
        Text(tema)
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(2)
      }

      if let objetivo = args["objetivo"] as? String {
        Text("🎯 \(objetivo)")
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(2)
      }

      HStack(spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: "cpu.fill")
            .font(.system(size: 9))
          Text("Subagente PC")
            .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(accentColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(accentColor.opacity(0.15)))

        if let prof = args["profundidad"] as? String {
          Text(prof.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }

        Spacer()

        HStack(spacing: 4) {
          Image(systemName: "paperplane.fill")
            .font(.system(size: 9))
          Text("Telegram")
            .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.cyan)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.cyan.opacity(0.15)))
      }
    }
  }

  private var paletaTexturasView: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let titulo = args["titulo"] as? String {
        Text(titulo)
          .font(.system(size: 13, weight: .semibold))
          .foregroundColor(.white)
      }

      if let hexList = args["paleta_hex"] as? [String], !hexList.isEmpty {
        HStack(spacing: 6) {
          ForEach(Array(hexList.prefix(5)), id: \.self) { hex in
            VStack(spacing: 3) {
              RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: hex))
                .frame(width: 38, height: 24)
                .overlay(
                  RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
              Text(hex.uppercased())
                .font(.system(size: 8, weight: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            }
          }
        }
      }

      if let td = args["sugerencia_touchdesigner"] as? String {
        Text("💡 TD: \(td)")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(accentColor)
          .lineLimit(2)
      }
    }
  }

  private var inspeccionPantallaView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let contexto = args["contexto"] as? String {
          Text(contexto)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(accentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(accentColor.opacity(0.15)))
        }

        if let accion = args["accion_requerida"] as? String {
          Text(accion.replacingOccurrences(of: "_", with: " "))
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
      }

      if let analisis = args["analisis_visual"] as? String {
        Text(analisis)
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(3)
      }

      if let codigo = args["codigo_o_diagrama"] as? String, !codigo.isEmpty {
        Text(codigo.prefix(120) + (codigo.count > 120 ? "…" : ""))
          .font(.system(size: 10, design: .monospaced))
          .foregroundColor(accentColor)
          .padding(6)
          .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.4)))
          .lineLimit(2)
      }
    }
  }

  private var contactoNetworkingView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let nombre = args["nombre"] as? String {
          Text(nombre)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
        }

        if let rol = args["rol_o_empresa"] as? String {
          Text("• \(rol)")
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.7))
            .lineLimit(1)
        }
      }

      if let charla = args["contexto_charla"] as? String {
        Text(charla)
          .font(.system(size: 11))
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(2)
      }

      if let comp = args["compromiso_o_proximo_paso"] as? String {
        HStack(spacing: 4) {
          Image(systemName: "calendar.badge.clock")
            .font(.system(size: 9))
            .foregroundColor(accentColor)
          Text(comp)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(accentColor)
            .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(accentColor.opacity(0.12)))
      }
    }
  }

  private var registroGastoHabitoView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        if let valor = args["valor"] as? String {
          Text(valor)
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundColor(accentColor)
        }

        if let concepto = args["concepto"] as? String {
          Text(concepto)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
        }
      }

      HStack(spacing: 6) {
        if let tipo = args["tipo_registro"] as? String {
          Text(tipo.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(accentColor.opacity(0.15)))
        }

        if let cat = args["categoria"] as? String {
          Text(cat)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }

        if let pago = args["medio_pago"] as? String {
          Text(pago)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
        }
      }
    }
  }

  private var repasoConceptosVaultView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let tema = args["tema_o_carpeta"] as? String {
          Text(tema)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
        }

        if let modo = args["modo"] as? String {
          Text(modo.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(accentColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(accentColor.opacity(0.15)))
        }
      }

      HStack(spacing: 4) {
        Image(systemName: "figure.walk")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.6))
        Text("Walk & Learn activo — Preguntas por voz en tus gafas")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.7))
      }
    }
  }

  private var monitoreoProcesoView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let proc = args["proceso"] as? String {
          HStack(spacing: 4) {
            Circle()
              .fill(Color.green)
              .frame(width: 6, height: 6)
            Text(proc.uppercased())
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.white)
          }
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(Capsule().fill(Color.green.opacity(0.2)))
        }

        if let accion = args["accion"] as? String {
          Text(accion.replacingOccurrences(of: "_", with: " "))
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
      }

      if let cond = args["condicion_aviso"] as? String {
        Text("🔔 Alerta: \(cond)")
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(accentColor)
      }
    }
  }

  private var controlAmbienteView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let accion = args["accion"] as? String {
          Text(accion.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
        }

        if let obj = args["objetivo"] as? String {
          Text("→ \(obj)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(accentColor)
        }
      }
      Text("Comando enviado a la PC de casa")
        .font(.system(size: 10))
        .foregroundColor(.white.opacity(0.6))
    }
  }

  private var dondeDejeObjetoView: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        if let obj = args["objeto"] as? String {
          Text(obj.capitalized)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(accentColor)
        }

        if let lugar = args["contexto_lugar"] as? String {
          Text("• \(lugar)")
            .font(.system(size: 11))
            .foregroundColor(.white.opacity(0.7))
        }
      }

      HStack(spacing: 4) {
        Image(systemName: "clock.arrow.circlepath")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.6))
        Text("Buscando en últimas 24 escenas de cámara...")
          .font(.system(size: 10))
          .foregroundColor(.white.opacity(0.7))
      }
    }
  }

  private func scheduleAutoCollapse(delay: Double = 5.0) {
    autoCollapseTask?.cancel()
    autoCollapseTask = Task {
      try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }
      await MainActor.run {
        withAnimation(.spring()) {
          self.isExpanded = false
        }
      }
    }
  }
}

// MARK: - StatusPill (mantenido para compatibilidad, pero ya no se usa directamente)

struct StatusPill: View {
  let color: Color
  let text: String
  var isPulsing: Bool = false

  @State private var pulseAnim = false

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
        .overlay(
          Circle()
            .stroke(color.opacity(0.4), lineWidth: 3)
            .scaleEffect(isPulsing && pulseAnim ? 1.6 : 1.0)
            .opacity(isPulsing && pulseAnim ? 0 : 0.6)
        )

      Text(text)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.black.opacity(0.6))
    .cornerRadius(16)
    .onAppear {
      guard isPulsing else { return }
      withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
        pulseAnim = true
      }
    }
    .onChange(of: isPulsing) {
      if isPulsing {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
          pulseAnim = true
        }
      } else {
        pulseAnim = false
      }
    }
  }
}

// MARK: - Legacy views (mantenidos para compatibilidad, no se renderizan en la nueva UI)

struct TranscriptView: View {
  let userText: String
  let aiText: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if !userText.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "person.fill")
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.5))
          Text(userText)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.7))
        }
      }
      if !aiText.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "sparkles")
            .font(.system(size: 10))
            .foregroundColor(.purple.opacity(0.7))
          Text(aiText)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Color.black.opacity(0.6))
    .cornerRadius(12)
  }
}

struct SpeakingIndicator: View {
  @State private var animating = false

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<4, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1.5)
          .fill(
            LinearGradient(
              colors: [Color.cyan, Color.purple],
              startPoint: .bottom,
              endPoint: .top
            )
          )
          .frame(width: 3, height: animating ? height(for: index) : 4)
          .animation(
            .easeInOut(duration: 0.4)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.12),
            value: animating
          )
      }
    }
    .onAppear { animating = true }
    .onDisappear { animating = false }
  }

  private func height(for index: Int) -> CGFloat {
    let heights: [CGFloat] = [12, 20, 16, 10]
    return heights[index % heights.count]
  }
}

// MARK: - Voice Waveform Animation

struct VoiceWaveformView: View {
  let isActive: Bool

  @State private var phase: Double = 0
  private let barCount = 24
  private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

  var body: some View {
    GeometryReader { geometry in
      let totalWidth = geometry.size.width
      let barSpacing: CGFloat = 3
      let barWidth = max(3, (totalWidth - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount))

      HStack(spacing: barSpacing) {
        ForEach(0..<barCount, id: \.self) { index in
          RoundedRectangle(cornerRadius: barWidth / 2)
            .fill(
              LinearGradient(
                colors: [Color.cyan.opacity(0.8), Color.purple.opacity(0.9)],
                startPoint: .bottom,
                endPoint: .top
              )
            )
            .frame(width: barWidth, height: isActive ? barHeight(for: index) : 2)
            .animation(.interpolatingSpring(stiffness: 80, damping: 12), value: phase)
        }
      }
      .frame(maxHeight: .infinity, alignment: .center)
    }
    .frame(height: 48)
    .padding(.horizontal, 24)
    .onReceive(timer) { _ in
      guard isActive else { return }
      withAnimation(.linear(duration: 0.1)) {
        phase += 0.15
      }
    }
  }

  private func barHeight(for index: Int) -> CGFloat {
    guard isActive else { return 2 }
    let frequency = 0.4
    let amplitude: CGFloat = 18
    let offset: CGFloat = 6
    let normalizedIndex = CGFloat(index) / CGFloat(barCount)
    let value = Darwin.sin(Double(normalizedIndex) * .pi * 2 * frequency + Double(phase) * 2) +
                Darwin.sin(Double(normalizedIndex) * .pi * 3 + Double(phase) * 1.5) * 0.5
    return max(3, amplitude * (1 + value * 0.6) + offset)
  }
}

// MARK: - ConnectionHealthIndicator (eliminado de la UI, mantenido para compatibilidad)

struct ConnectionHealthIndicator: View {
  let latencyMs: Int?
  let connectionState: HermesConnectionState

  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(indicatorColor)
        .frame(width: 6, height: 6)

      if let latency = latencyMs {
        Text("\\(latency)ms")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundColor(indicatorColor)
      } else if case .connected = connectionState {
        Text("~ms")
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundColor(.green)
      } else {
        Text(dotText)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(indicatorColor)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Capsule().fill(Color.black.opacity(0.5)))
  }

  private var indicatorColor: Color {
    if let latency = latencyMs {
      if latency < 500 { return .green }
      if latency < 2000 { return .yellow }
      return .red
    }
    switch connectionState {
    case .connected: return .green
    case .checking: return .yellow
    case .unreachable: return .red
    case .notConfigured: return .gray
    }
  }

  private var dotText: String {
    switch connectionState {
    case .notConfigured: return "N/A"
    case .checking: return "..."
    case .unreachable: return "ERR"
    case .connected: return "OK"
    }
  }
}

// MARK: - Color Hex Initializer Helper

extension Color {
  init(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch cleaned.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 128, 128, 128)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

