import Foundation

class ChatHistoryManager: ObservableObject {
    static let shared = ChatHistoryManager()

    @Published var sessions: [ChatSession] = []
    @Published var currentSession: ChatSession?

    private let fileManager = FileManager.default
    private let fileName = "chat_history.json"

    private init() {
        loadSessions()
    }

    private var historyURL: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }

    /// Start a new session (or resume the last incomplete one)
    func startNewSession(title: String = "New Session") {
        let session = ChatSession(title: title)
        currentSession = session
        sessions.insert(session, at: 0)
        persist()
    }

    /// Add a message to the current session
    func addMessage(role: Role, text: String) {
        guard var session = currentSession else {
            startNewSession()
            addMessage(role: role, text: text)
            return
        }
        let msg = ChatMessage(role: role, text: text)
        session.messages.append(msg)
        currentSession = session
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        persist()
    }

    /// Update current session title from Gemini's first message
    func updateCurrentSessionTitle(_ title: String) {
        guard var session = currentSession else { return }
        session.title = title
        currentSession = session
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        persist()
    }

    func saveSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        if currentSession?.id == session.id {
            currentSession = session
        }
        persist()
    }

    func deleteSession(at offsets: IndexSet) {
        let removedIds = offsets.map { sessions[$0].id }
        sessions.remove(atOffsets: offsets)
        if let cur = currentSession, removedIds.contains(cur.id) {
            currentSession = sessions.first
        }
        persist()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll(where: { $0.id == id })
        if currentSession?.id == id {
            currentSession = sessions.first
        }
        persist()
    }

    func updateSessionTitle(id: UUID, newTitle: String) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].title = newTitle
            if currentSession?.id == id {
                currentSession = sessions[index]
            }
            persist()
        }
    }

    // MARK: - Markdown Export

    /// Export the current session as a Markdown string
    func exportCurrentSessionAsMD(title: String? = nil) -> String {
        guard let session = currentSession else {
            return "# Chat export\n\n*No hay sesión activa*"
        }
        return exportSessionAsMD(session, customTitle: title)
    }

    /// Export a specific session as Markdown string
    func exportSessionAsMD(_ session: ChatSession, customTitle: String? = nil) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale(identifier: "es-AR")

        let title = customTitle ?? session.title
        let dateStr = dateFormatter.string(from: session.date)
        let messageCount = session.messages.count

        var md = """
        # \(title)

        **Fecha:** \(dateStr)  **Mensajes:** \(messageCount)

        ---

        """

        for msg in session.messages {
            let role = msg.role == .user ? "👤 **User**" : "🤖 **Gemini**"
            let timeStr = DateFormatter.localizedString(from: msg.timestamp, dateStyle: .none, timeStyle: .short)
            md += "\n### \(role) · \(timeStr)\n\n\(msg.text)\n\n---\n"
        }

        md += "\n*Exportado desde VisionHermes — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))*\n"
        return md
    }

    /// Save markdown to a local file and return the URL
    func saveMDToFile(_ content: String, title: String) -> URL? {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let safeTitle = title.replacingOccurrences(of: "[/:]", with: "-", options: .regularExpression)
        let fileName = "\(safeTitle)-\(Date().timeIntervalSince1970).md"
        let fileURL = documentsDir.appendingPathComponent(fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            NSLog("[ChatHistory] Saved MD: %@", fileURL.path)
            return fileURL
        } catch {
            NSLog("[ChatHistory] Failed to save MD: %@", error.localizedDescription)
            return nil
        }
    }

    // MARK: - Cleanup

    func clearHistory() {
        sessions.removeAll()
        currentSession = nil
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            print("Failed to save chat history: \(error.localizedDescription)")
        }
    }

    private func loadSessions() {
        guard fileManager.fileExists(atPath: historyURL.path) else { return }
        do {
            let data = try Data(contentsOf: historyURL)
            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
            currentSession = sessions.first
        } catch {
            print("Failed to load chat history: \(error.localizedDescription)")
        }
    }
}
