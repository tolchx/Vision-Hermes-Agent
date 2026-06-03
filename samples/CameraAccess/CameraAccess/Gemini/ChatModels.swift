import Foundation

enum Role: String, Codable {
    case user
    case ai
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: Role, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    let date: Date
    var messages: [ChatMessage]
    
    init(id: UUID = UUID(), title: String, date: Date = Date(), messages: [ChatMessage] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.messages = messages
    }
}
