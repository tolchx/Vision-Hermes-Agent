---
description: How to automatically summarize chat sessions in iOS apps using Gemini when the app enters the background or when a conversation finishes.
---
# iOS Auto-Session Summaries

When building AI voice or text assistants, the chat history interface often defaults to showing the first or last message of a thread as a preview. This is barely legible and lacks context. 

A much better user experience is to **auto-summarize** the entire thread into a short title or overview when the conversation concludes, using a fast flash LLM tier (like `gemini-2.5-flash`).

## 1. When to trigger an Auto-Summary?
You cannot reliable expect a user to hit an explicit "End Session" button. They will simply stop talking, swipe up to background the app, or tap "New Chat". You must wire the summarizer into the application lifecycle.

### A. When App goes to Background (`scenePhase`)
In your root SwiftUI `App` or root tab View:
```swift
@Environment(\.scenePhase) private var scenePhase

var body: some View {
    ContentView()
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                // User just locked their phone or swiped away
                ConversationManager.shared.attemptSummarizeCurrentConversation()
            }
        }
}
```

### B. When a New Chat is Started
If the user navigates away from the active thread to start a new one, summarize the previous one.
```swift
func startNewConversation() {
    attemptSummarizeCurrentConversation()
    self.currentThreadId = UUID()
}
```

## 2. Implementation: The Summarizer Service
Run the summazrizar in a `Task` asynchronously. Do not block the UI thread. Use a generic, fast model and pass the last N messages to save tokens. Ask the model to reply in the language the user primarily spoke.

```swift
class SessionSummarizer {
    static let shared = SessionSummarizer()
    
    // Using a fast model, not the expensive Live/Pro models
    private let geminiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    func summarize(conversation: Conversation) async -> String? {
        guard conversation.messages.count > 2 else { return nil } // Skip trivial chats
        
        let apiKey = SettingsManager.shared.settings.apiKey
        guard !apiKey.isEmpty else { return nil }
        
        // Grab last N messages
        let recentMessages = conversation.messages.suffix(50)
        let threadText = recentMessages.map { "\($0.role == .user ? "User" : "AI"): \($0.content)" }.joined(separator: "\n")
        
        let prompt = """
        Provide a very concise, 1-2 sentence summary of this conversation. 
        Focus on what the user was asking or trying to accomplish.
        IMPORTANT: Write the summary in the same language as the conversation!
        Do NOT write "The user asked..." just write the summary directly.
        
        Conversation:
        \(threadText)
        """
        
        // Construct the basic Gemini REST payload
        let payload: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        let url = URL(string: "\(geminiUrl)?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = root["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        } catch {
            return nil
        }
    }
}
```

## 3. UI Implementation
In your `ConversationListView` or `HistoryView`, conditionally show the summary if it was generated. Otherwise, fallback to the last message.

```swift
VStack(alignment: .leading) {
    Text("Jan 14 at 2:30 PM").font(.caption).foregroundColor(.secondary)
    
    if let summary = conversation.summary {
        Text(summary)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(2)
    } else if let lastMessage = conversation.messages.last {
        Text(lastMessage.text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }
}
```
