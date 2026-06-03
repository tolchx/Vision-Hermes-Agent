import SwiftUI

struct LogView: View {
    @ObservedObject private var logStore = LogStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var filterLevel: LogStore.LogLevel? = nil

    var filteredEntries: [LogStore.LogEntry] {
        var entries = logStore.entries
        if let level = filterLevel {
            entries = entries.filter { $0.level == level }
        }
        if !searchText.isEmpty {
            entries = entries.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        return entries
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    Spacer()
                    Text("App Log")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { logStore.clear() }) {
                        Text("Clear")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Level filter chips
                HStack(spacing: 6) {
                    ForEach(LogStore.LogLevel.allCases, id: \.self) { level in
                        Button {
                            withAnimation(.spring()) {
                                filterLevel = filterLevel == level ? nil : level
                            }
                        } label: {
                            Text(level.rawValue.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(filterLevel == level ? .white : levelColor(level))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(filterLevel == level ? levelColor(level).opacity(0.3) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(filterLevel == level ? levelColor(level).opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }

                    if filterLevel != nil {
                        Button("Clear") {
                            withAnimation(.spring()) { filterLevel = nil }
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 6)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                    TextField("Search logs...", text: $searchText)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 12))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 4)

                // Entry count
                Text("\(filteredEntries.count) of \(logStore.entries.count) entries")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.bottom, 4)

                // Log list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            if filteredEntries.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text.magnifyingglass")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("No log entries")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    if !searchText.isEmpty {
                                        Text("Try a different search term")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 80)
                            } else {
                                ForEach(filteredEntries) { entry in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(entry.formattedTime)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.gray)
                                            .frame(width: 70, alignment: .leading)

                                        Text(entry.message)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(entryColor(entry.level))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.2))
                                    .id(entry.id)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .onChange(of: logStore.entries.count) {
                        guard filterLevel == nil && searchText.isEmpty else { return }
                        if let last = logStore.entries.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }
                .background(Color.black.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private func entryColor(_ level: LogStore.LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .white
        case .warn: return .yellow
        case .error: return .red
        }
    }

    private func levelColor(_ level: LogStore.LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warn: return .yellow
        case .error: return .red
        }
    }
}
