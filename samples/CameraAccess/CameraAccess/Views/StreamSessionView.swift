/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamSessionView.swift
//
// Central navigation hub that displays the streaming session view.
//

import MWDATCamera
import MWDATCore
import SwiftUI
import UIKit

struct StreamSessionView: View {
  let wearables: WearablesInterface
  @ObservedObject private var wearablesViewModel: WearablesViewModel
  @StateObject private var viewModel: StreamSessionViewModel
  @StateObject private var geminiVM = GeminiSessionViewModel()
  @StateObject private var webrtcVM = WebRTCSessionViewModel()
  @State private var isMenuOpen: Bool = false
  @State private var showSettings: Bool = false

  init(wearables: WearablesInterface, wearablesVM: WearablesViewModel) {
    self.wearables = wearables
    self.wearablesViewModel = wearablesVM
    self._viewModel = StateObject(wrappedValue: StreamSessionViewModel(wearables: wearables))
  }

  var body: some View {
    ZStack {
      // 1. Main View (Background)
      Group {
          StreamView(viewModel: viewModel, wearablesVM: wearablesViewModel, geminiVM: geminiVM, webrtcVM: webrtcVM, isMenuOpen: $isMenuOpen)
      }
      .scaleEffect(isMenuOpen ? 0.95 : 1.0)
      .blur(radius: isMenuOpen ? 2 : 0)
      .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isMenuOpen)
      .disabled(isMenuOpen)

      // 2. Lateral Menu (Overlay)
      HamburgerMenuView(
        isOpen: $isMenuOpen,
        showSettings: $showSettings,
        viewModel: viewModel,
        wearablesVM: wearablesViewModel,
        geminiVM: geminiVM
      )
    }
    .task {
      viewModel.geminiSessionVM = geminiVM
      viewModel.webrtcSessionVM = webrtcVM
      geminiVM.streamingMode = viewModel.streamingMode

      if !viewModel.isStreaming {
          await viewModel.handleStartStreaming()
      }
    }
    .onChange(of: viewModel.streamingMode) { _, newMode in
      geminiVM.streamingMode = newMode
    }
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
      geminiVM.startWakeWordDetection()
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      geminiVM.stopWakeWordDetection()
    }
    .alert("Error", isPresented: $viewModel.showError) {
      Button("OK") {
        viewModel.dismissError()
      }
    } message: {
      Text(viewModel.errorMessage)
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// HamburgerMenuView — inline para compatibilidad con Xcode project
// ═══════════════════════════════════════════════════════════════

struct HamburgerMenuView: View {
    @Binding var isOpen: Bool
    @Binding var showSettings: Bool
    @ObservedObject var viewModel: StreamSessionViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    @ObservedObject var geminiVM: GeminiSessionViewModel
    @State private var showHistory = false
    @State private var functionsExpanded = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Dimmed background
                if isOpen {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isOpen = false } }
                }

                // Menu Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack {
                            Image(systemName: "visionpro")
                                .font(.system(size: 28))
                                .foregroundColor(DS.Color.accentCyan)
                                .neonCyan(radius: 12, intensity: 0.5)

                            Text("VisionHermes")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.top, 50)

                        // ── Status Section ──
                        VStack(alignment: .leading, spacing: 10) {
                            DSSectionHeader(title: "Estado")

                            HStack(spacing: 12) {
                                StatusPillCyan(
                                    label: "Gemini",
                                    state: geminiStatusState,
                                    detail: geminiStatusDetail
                                )
                                StatusPillCyan(
                                    label: "Hermes",
                                    state: hermesStatusState,
                                    detail: hermesStatusDetail
                                )
                            }

                            MenuStatusRow(
                                icon: wearablesVM.registrationState == .registered ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                                iconColor: wearablesVM.registrationState == .registered ? DS.Color.accentCyan : .orange,
                                title: "Meta AI",
                                subtitle: wearablesVM.registrationState == .registered ? "Conectado" : "Desconectado"
                            )

                            MenuStatusRow(
                                icon: viewModel.hasActiveDevice ? "eyeglasses" : "antenna.radiowaves.left.and.right",
                                iconColor: viewModel.hasActiveDevice ? DS.Color.accentCyan : .gray,
                                title: "Dispositivo",
                                subtitle: viewModel.hasActiveDevice ? "Gafas encontradas" : "Buscando..."
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(DS.Color.borderSubtle, lineWidth: 1)
                                )
                        )

                        // ── Streaming Controls (side by side) ──
                        VStack(alignment: .leading, spacing: 10) {
                            DSSectionHeader(title: "Streaming")

                            HStack(spacing: 8) {
                                // Gafas
                                MiniControlButton(
                                    icon: "eyeglasses",
                                    title: "Gafas",
                                    isActive: viewModel.streamingMode == .glasses && viewModel.isStreaming,
                                    isDisabled: wearablesVM.registrationState != .registered,
                                    color: DS.Color.accentCyan
                                ) {
                                    Task {
                                        if viewModel.streamingMode == .glasses && viewModel.isStreaming {
                                            await viewModel.stopSession()
                                        } else {
                                            await viewModel.handleStartStreaming()
                                        }
                                        withAnimation { isOpen = false }
                                    }
                                }

                                // iPhone
                                MiniControlButton(
                                    icon: "iphone",
                                    title: "iPhone",
                                    isActive: viewModel.streamingMode == .iPhone && viewModel.isStreaming,
                                    color: DS.Color.accentPurple
                                ) {
                                    Task {
                                        if viewModel.streamingMode == .iPhone && viewModel.isStreaming {
                                            await viewModel.stopSession()
                                        } else {
                                            await viewModel.handleStartIPhone()
                                        }
                                        withAnimation { isOpen = false }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(DS.Color.borderSubtle, lineWidth: 1)
                                )
                        )

                        // ── Funciones (colapsable) ──
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    functionsExpanded.toggle()
                                }
                            } label: {
                                HStack {
                                    DSSectionHeader(title: "Funciones")
                                    Spacer()
                                    Image(systemName: functionsExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(DS.Color.textTertiary)
                                }
                                .padding(.trailing, 4)
                            }
                            .buttonStyle(.plain)

                            if functionsExpanded {
                                MenuFeatureRow(icon: "person.text.rectangle.fill", color: DS.Color.accentCyan,
                                    title: "🧬 Gemelo Digital",
                                    subtitle: "Preguntas profundas sobre tu personalidad")
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                MenuFeatureRow(icon: "square.and.pencil", color: DS.Color.accentPurple,
                                    title: "📝 Notas por Voz",
                                    subtitle: "Guardá ideas directo al vault")
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                MenuFeatureRow(icon: "magnifyingglass", color: DS.Color.accentCyan,
                                    title: "🔍 Buscar en Vault",
                                    subtitle: "Buscá en tu memoria de Obsidian")
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                MenuFeatureRow(icon: "doc.text.fill", color: DS.Color.accentPurple,
                                    title: "📄 Exportar Chat",
                                    subtitle: "Guardá la charla como Markdown")
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                                        .stroke(DS.Color.borderSubtle, lineWidth: 1)
                                )
                        )

                        Divider()
                            .background(DS.Color.borderCyan.opacity(0.3))

                        // ── Actions ──
                        VStack(spacing: 8) {
                            MenuActionButton(icon: "clock.arrow.circlepath", color: DS.Color.accentCyan, title: "Historial de Charlas") {
                                withAnimation { isOpen = false }
                                showHistory = true
                            }

                            MenuActionButton(icon: "gearshape.fill", color: .white, title: "Configuración") {
                                withAnimation { isOpen = false }
                                showSettings = true
                            }

                            MenuActionButton(icon: "power", color: .red, title: "Desconectar dispositivo") {
                                wearablesVM.disconnectGlasses()
                                withAnimation { isOpen = false }
                            }
                        }

                        Spacer()

                        Text("VisionHermes v1.2.0")
                            .font(.footnote)
                            .foregroundColor(DS.Color.textTertiary)
                            .padding(.bottom, 30)
                    }
                    .padding(.horizontal, 24)
                }
                .frame(width: geometry.size.width * 0.82)
                .background(
                    ZStack {
                        DS.Color.background.opacity(0.92).ignoresSafeArea()
                        LinearGradient(
                            colors: [
                                DS.Color.accentCyan.opacity(0.03),
                                DS.Color.accentPurple.opacity(0.02),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ).ignoresSafeArea()
                    }.ignoresSafeArea()
                )
                .offset(x: isOpen ? 0 : -geometry.size.width * 0.82)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isOpen)
            }
        }
        .sheet(isPresented: $showHistory) {
            ChatHistoryView()
        }
    }

    // MARK: - Status helpers

    private var geminiStatusState: StatusPillState {
        switch geminiVM.connectionState {
        case .ready: return .connected
        case .connecting, .settingUp: return .connecting
        case .error: return .error
        case .disconnected: return .offline
        }
    }

    private var geminiStatusDetail: String {
        switch geminiVM.connectionState {
        case .ready: return "Conectado"
        case .connecting: return "Conectando..."
        case .settingUp: return "Iniciando..."
        case .error(let e): return e
        case .disconnected: return "Desconectado"
        }
    }

    private var hermesStatusState: StatusPillState {
        switch geminiVM.hermesConnectionState {
        case .connected: return .connected
        case .checking: return .connecting
        case .unreachable: return .error
        case .notConfigured: return .offline
        }
    }

    private var hermesStatusDetail: String {
        switch geminiVM.hermesConnectionState {
        case .connected: return "Conectado"
        case .checking: return "Verificando..."
        case .unreachable(let e): return e
        case .notConfigured: return "No configurado"
        }
    }
}

// MARK: - Status helper types

enum StatusPillState { case connected, connecting, error, offline }

struct StatusPillCyan: View {
    let label: String
    let state: StatusPillState
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(indicatorColor.opacity(0.3), lineWidth: 2)
                        .scaleEffect(state == .connecting ? 1.5 : 1.0)
                        .opacity(state == .connecting ? 0 : 0.6)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(detail)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DS.Color.surfaceLight)
        )
    }

    private var indicatorColor: Color {
        switch state {
        case .connected: return DS.Color.accentCyan
        case .connecting: return .yellow
        case .error: return .red
        case .offline: return .gray
        }
    }
}

struct MenuStatusRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 14))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text(subtitle)
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            Spacer()
        }
    }
}

struct MenuControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var isDisabled: Bool = false
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isActive ? color : .white)
                    .frame(width: 28)
                Text(title)
                    .font(.headline)
                    .foregroundColor(isDisabled ? .gray : .white)
                Spacer()
                Text(isActive ? "DETENER" : "INICIAR")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isActive ? Color.red.opacity(0.8) : color.opacity(0.3))
                    )
                    .foregroundColor(isActive ? .white : color)
            }
            .foregroundColor(isDisabled ? .gray : .white)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DS.Color.surfaceLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? color.opacity(0.4) : DS.Color.border, lineWidth: 1)
                    )
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

struct MenuFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 13))
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }
}

/// Streaming button compacto (side by side)
struct MiniControlButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var isDisabled: Bool = false
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isActive ? color : .white)
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(isDisabled ? .gray : .white)
                Text(isActive ? "DETENER" : "INICIAR")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isActive ? Color.red.opacity(0.8) : color.opacity(0.3))
                    )
                    .foregroundColor(isActive ? .white : color)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DS.Color.surfaceLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? color.opacity(0.4) : DS.Color.border, lineWidth: 1)
                    )
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

struct MenuActionButton: View {
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 26)
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(color.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DS.Color.surfaceLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DS.Color.borderSubtle, lineWidth: 1)
                    )
            )
        }
    }
}
