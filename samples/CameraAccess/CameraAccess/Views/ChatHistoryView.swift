import SwiftUI

struct ChatHistoryView: View {
    @StateObject var historyManager = ChatHistoryManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var editingSessionId: UUID?
    @State private var newTitle: String = ""
    @State private var showExportSuccess = false
    @State private var exportMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()

                List {
                    ForEach(historyManager.sessions) { session in
                        NavigationLink(destination: ChatSessionDetailView(session: session)) {
                            VStack(alignment: .leading, spacing: 4) {
                                if editingSessionId == session.id {
                                    HStack {
                                        TextField("Session Title", text: $newTitle, onCommit: {
                                            historyManager.updateSessionTitle(id: session.id, newTitle: newTitle)
                                            editingSessionId = nil
                                        })
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .foregroundColor(.black)

                                        Button("Done") {
                                            historyManager.updateSessionTitle(id: session.id, newTitle: newTitle)
                                            editingSessionId = nil
                                        }
                                    }
                                } else {
                                    Text(session.title)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text(session.date, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))

                                    Text("\(session.messages.count) messages")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                historyManager.deleteSession(id: session.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                editingSessionId = session.id
                                newTitle = session.title
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                exportSession(session)
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .tint(.cyan)

                            Button {
                                exportSessionToVault(session)
                            } label: {
                                Label("To Vault", systemImage: "tray.and.arrow.down")
                            }
                            .tint(.purple)
                        }
                        .listRowBackground(Color.white.opacity(0.1))
                    }
                    .onDelete(perform: historyManager.deleteSession)
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            exportCurrentSession()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .foregroundColor(.cyan)

                        EditButton()
                            .foregroundColor(.white)
                    }
                }
            }
            .overlay {
                if showExportSuccess {
                    VStack {
                        Spacer()
                        Text(exportMessage)
                            .font(.subheadline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .padding(.bottom, 40)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.easeInOut, value: showExportSuccess)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showExportSuccess = false }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Export Actions

    private func exportCurrentSession() {
        guard let session = historyManager.currentSession else {
            showToast("No active session")
            return
        }
        exportSession(session)
    }

    private func exportSession(_ session: ChatSession) {
        let md = historyManager.exportSessionAsMD(session)
        guard let fileURL = historyManager.saveMDToFile(md, title: session.title) else {
            showToast("Failed to save file")
            return
        }

        // Present share sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            showToast("Exported: \(fileURL.lastPathComponent)")
            return
        }
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }

    private func exportSessionToVault(_ session: ChatSession) {
        let md = historyManager.exportSessionAsMD(session)
        let safeTitle = session.title.replacingOccurrences(of: "[/:]", with: "-", options: .regularExpression)

        // Send to Hermes gateway as a vault task
        let taskDesc = ToolDeclarations.exportarChatTask(titulo: safeTitle, contenidoMD: md)

        // We need HermesBridge to handle this
        Task {
            let bridge = HermesBridge()
            let result = await bridge.delegateTask(task: taskDesc, toolName: "exportar_chat_md")
            switch result {
            case .success(let msg):
                showToast("Saved to vault ✅")
                NSLog("[ChatHistory] Vault export success: %@", msg)
            case .failure(let err):
                showToast("Vault error: \(err)")
                NSLog("[ChatHistory] Vault export failed: %@", err)
            }
        }
    }

    private func showToast(_ message: String) {
        exportMessage = message
        withAnimation { showExportSuccess = true }
    }
}

struct ChatSessionDetailView: View {
    let session: ChatSession
    @State private var showExportOptions = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(session.messages) { message in
                        VStack(spacing: 2) {
                            ChatMessageBubble(text: message.text, isUser: message.role == .user)
                            Text(message.timestamp, style: .time)
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        exportMD()
                    } label: {
                        Label("Export as MD", systemImage: "doc.text")
                    }

                    Button {
                        exportMDToVault()
                    } label: {
                        Label("Send to Vault", systemImage: "tray.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.cyan)
                }
            }
        }
        .overlay {
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: showToast)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showToast = false }
                    }
                }
            }
        }
    }

    private func exportMD() {
        let md = ChatHistoryManager.shared.exportSessionAsMD(session)
        guard let fileURL = ChatHistoryManager.shared.saveMDToFile(md, title: session.title) else {
            toastMessage = "Failed to save"
            withAnimation { showToast = true }
            return
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            toastMessage = "Saved: \(fileURL.lastPathComponent)"
            withAnimation { showToast = true }
            return
        }
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        rootVC.present(activityVC, animated: true)
    }

    private func exportMDToVault() {
        let md = ChatHistoryManager.shared.exportSessionAsMD(session)
        let safeTitle = session.title.replacingOccurrences(of: "[/:]", with: "-", options: .regularExpression)
        let taskDesc = ToolDeclarations.exportarChatTask(titulo: safeTitle, contenidoMD: md)

        Task {
            let bridge = HermesBridge()
            let result = await bridge.delegateTask(task: taskDesc, toolName: "exportar_chat_md")
            switch result {
            case .success:
                toastMessage = "✅ Saved to vault"
            case .failure(let err):
                toastMessage = "❌ \(err)"
            }
            withAnimation { showToast = true }
        }
    }
}

struct ChatHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ChatHistoryView()
    }
}
