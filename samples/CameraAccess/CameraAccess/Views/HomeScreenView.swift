/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// HomeScreenView.swift
//
// Welcome screen. Cards en carrusel horizontal para dejar espacio a botones de conexión.
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel
  @State private var showSettings = false
  @State private var showHistory = false
  @State private var hasAppeared = false
  @State private var currentCard = 0

  private let cards: [(icon: String, color: Color, title: String, text: String)] = [
    ("person.text.rectangle.fill", DS.Color.accentCyan,
     "🧬 Avatar Personal",
     "Preguntas profundas sobre tu vida, valores y personalidad. Cada respuesta se guarda en tu vault."),
    ("square.and.pencil", DS.Color.accentPurple,
     "📝 Notas por Voz",
     "Guardá ideas, inspiración y observaciones en tu vault con solo hablar."),
    ("magnifyingglass", DS.Color.accentCyan,
     "🔍 Buscar en tu Memoria",
     "Preguntale a Gemini cualquier cosa y busca automáticamente en tu vault de Obsidian."),
    ("doc.text.fill", DS.Color.accentPurple,
     "📄 Exportar Conversaciones",
     "Cada charla se guarda. Exportalas como Markdown o enviarlas directo a tu vault."),
  ]

  var body: some View {
    ZStack {
      AnimatedBackground()

      VStack(spacing: 0) {
        // Top bar
        HStack {
          Spacer()
          HStack(spacing: 6) {
            Button { showHistory = true } label: {
              Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .padding(10)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().stroke(DS.Color.borderCyan, lineWidth: 1))
            }
            Button { showSettings = true } label: {
              Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .padding(10)
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().stroke(DS.Color.border, lineWidth: 1))
            }
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)

        Spacer()

        // Logo: visionpro icon + "VisionHermes" (sin glow)
        VStack(spacing: 8) {
          Image(systemName: "visionpro")
            .font(.system(size: 48))
            .foregroundColor(DS.Color.accentCyan)

          Text("VisionHermes")
            .font(.title.bold())
            .foregroundColor(.white)
        }
        .offset(y: hasAppeared ? 0 : -20)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.1), value: hasAppeared)
        .padding(.bottom, 20)

        // Carrusel horizontal
        VStack(spacing: 12) {
          TabView(selection: $currentCard) {
            ForEach(0..<cards.count, id: \.self) { i in
              CarouselCard(
                icon: cards[i].icon,
                color: cards[i].color,
                title: cards[i].title,
                text: cards[i].text
              )
              .tag(i)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .frame(height: 140)

          // Puntos indicadores
          HStack(spacing: 6) {
            ForEach(0..<cards.count, id: \.self) { i in
              Circle()
                .fill(i == currentCard ? DS.Color.accentCyan : DS.Color.textTertiary)
                .frame(width: 6, height: 6)
                .animation(.spring(), value: currentCard)
            }
          }
        }
        .padding(.horizontal, 20)
        .offset(y: hasAppeared ? 0 : 20)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: hasAppeared)

        Spacer()

        // Bottom actions — siempre visibles
        VStack(spacing: 14) {
          Text("Conectá tus Meta Ray-Ban o usá el iPhone para empezar")
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 32)

          GlassButton(
            title: viewModel.registrationState == .registering ? "Conectando..." : "Conectar mis gafas",
            icon: "eyeglasses",
            isDisabled: viewModel.registrationState == .registering
          ) {
            viewModel.connectGlasses()
          }

          Button {
            viewModel.skipToIPhoneMode = true
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "iphone")
                .font(.system(size: 14))
              Text("Continuar en iPhone")
                .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
              RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)
                .overlay(
                  RoundedRectangle(cornerRadius: 25)
                    .stroke(DS.Color.borderCyan, lineWidth: 1)
                )
            )
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .offset(y: hasAppeared ? 0 : 30)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.3), value: hasAppeared)
      }
    }
    .onAppear { hasAppeared = true }
    .sheet(isPresented: $showSettings) { SettingsView() }
    .sheet(isPresented: $showHistory) { ChatHistoryView() }
  }
}

// MARK: - Carousel Card

struct CarouselCard: View {
  let icon: String
  let color: Color
  let title: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [color.opacity(0.3), color.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 40, height: 40)

        Image(systemName: icon)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(color)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)

        Text(text)
          .font(.system(size: 13))
          .foregroundColor(.white.opacity(0.55))
          .fixedSize(horizontal: false, vertical: true)
          .lineLimit(3)
      }

      Spacer()
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(DS.Color.borderSubtle, lineWidth: 1)
        )
    )
    .padding(.horizontal, 4)
  }
}
