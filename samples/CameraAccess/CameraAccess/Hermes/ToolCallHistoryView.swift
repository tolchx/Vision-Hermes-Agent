import SwiftUI

// MARK: - Tool Call History View

struct ToolCallHistoryView: View {
  @ObservedObject var bridge: HermesBridge

  private let maxDisplay = 20

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // Header
      HStack {
        Image(systemName: "clock.arrow.circlepath")
          .font(.system(size: 12))
          .foregroundColor(.purple.opacity(0.8))
        Text("Recent Tool Calls")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.white.opacity(0.7))
        Spacer()
        Text("\(bridge.toolCallHistory.count)")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundColor(.white.opacity(0.4))
      }
      .padding(.bottom, 4)

      if bridge.toolCallHistory.isEmpty {
        Text("No tool calls yet")
          .font(.system(size: 12))
          .foregroundColor(.white.opacity(0.3))
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 8)
      } else {
        ScrollView {
          LazyVStack(spacing: 4) {
            ForEach(displayEntries) { entry in
              ToolCallHistoryRow(entry: entry)
            }
          }
        }
        .frame(maxHeight: 200)
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.black.opacity(0.3))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    )
  }

  private var displayEntries: [ToolCallHistoryEntry] {
    Array(bridge.toolCallHistory.suffix(maxDisplay).reversed())
  }
}

// MARK: - Tool Call History Row

struct ToolCallHistoryRow: View {
  let entry: ToolCallHistoryEntry

  var body: some View {
    HStack(spacing: 8) {
      // Status icon
      statusIcon
        .frame(width: 16)

      // Tool name
      Text(entry.toolName)
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundColor(.white)
        .lineLimit(1)

      Spacer(minLength: 4)

      // Detail
      Text(detailLabel)
        .font(.system(size: 10))
        .foregroundColor(.white.opacity(0.4))
        .lineLimit(1)

      // Timestamp
      Text(entry.formattedTime)
        .font(.system(size: 9, design: .monospaced))
        .foregroundColor(.white.opacity(0.3))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(backgroundColor)
    )
  }

  @ViewBuilder
  private var statusIcon: some View {
    switch entry.status {
    case "completed":
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 12))
        .foregroundColor(.green)
    case "failed":
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 12))
        .foregroundColor(.red)
    case "executing":
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
        .scaleEffect(0.6)
    case "cancelled":
      Image(systemName: "minus.circle.fill")
        .font(.system(size: 12))
        .foregroundColor(.orange)
    default:
      Image(systemName: "circle.fill")
        .font(.system(size: 6))
        .foregroundColor(.gray)
    }
  }

  private var detailLabel: String {
    if entry.detail.count > 25 {
      return String(entry.detail.prefix(25)) + "..."
    }
    return entry.detail
  }

  private var backgroundColor: Color {
    switch entry.status {
    case "completed": return Color.green.opacity(0.08)
    case "failed": return Color.red.opacity(0.1)
    case "executing": return Color.yellow.opacity(0.08)
    case "cancelled": return Color.orange.opacity(0.08)
    default: return Color.white.opacity(0.03)
    }
  }
}
