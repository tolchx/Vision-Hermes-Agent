/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// CustomButton.swift
//
// Reusable button component used throughout the CameraAccess app for consistent styling.
//

import SwiftUI

// MARK: - Glass Button (Primary CTA with icon)
struct GlassButton: View {
    let title: String
    var icon: String? = nil
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(27)
            .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Original Meta CustomButton (kept for compatibility)
struct CustomButton: View {
  let title: String
  let style: ButtonStyle
  let isDisabled: Bool
  let action: () -> Void

  enum ButtonStyle {
    case primary, secondary, destructive

    var backgroundColor: Color {
      switch self {
      case .primary:
        return .appPrimary
      case .secondary:
        return Color(white: 0.25)
      case .destructive:
        return .destructiveBackground
      }
    }

    var foregroundColor: Color {
      switch self {
      case .primary, .secondary:
        return .white
      case .destructive:
        return .destructiveForeground
      }
    }
  }

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(style.foregroundColor)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(style.backgroundColor)
        .cornerRadius(30)
    }
    .disabled(isDisabled)
    .opacity(isDisabled ? 0.6 : 1.0)
  }
}
