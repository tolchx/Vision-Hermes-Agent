---
description: How to build a long-term Spatial Memory map on iOS by connecting photos, context, and a Vector Database index to Apple CoreLocation data.
---
# iOS Spatial Memory & RAG

Standard AI assistants treat every new session as a blank slate. True "magic" happens when smart glasses have **Long-Term Spatial Memory**. You can say, *"Remember I parked my car here"*, and three hours later ask, *"Where did I park my car?"* to be guided back.

This requires building a small Retrieval-Augmented Generation (RAG) system running entirely on the iPhone, indexed by GPS coordinates and time.

## 1. The Core Architecture

The system involves three pieces:
1. **The CoreLocation Manager**: To stamp memories with exact Lat/Lng coordinates.
2. **The Memory Store**: A localized database (SQLite, CoreData, or simple JSON) storing memories. For larger-scale matching (e.g. "my red car"), you might want a lightweight Vector DB like Chroma or an embedded vector extension.
3. **The `MemoryManager` Service**: Exposes APIs for the AI backend (`OpenClaw`) to call via standard function-calling (tools).

## 2. Defining the `MemoryItem`

A memory is a localized event. When the user says *"Remember this"*, the AI automatically triggers the `store_memory` tool.

```swift
import Foundation
import CoreLocation

struct MemoryItem: Codable, Identifiable {
    let id: UUID
    let text: String              // e.g., "The user parked their red car."
    let latitude: Double          
    let longitude: Double
    let altitude: Double?         // Helpful if parked in a multi-story garage!
    let timestamp: Date
    let photoPath: String?        // Path to image if the user took a photo
}

class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    
    @Published var memories: [MemoryItem] = []
    
    // In a real app, use CoreData or SQLite. For simple prototypes, JSON works.
    private let saveURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("memories.json")
    
    init() {
        loadMemories()
    }
    
    func storeMemory(text: String, location: CLLocation, photoData: Data? = nil) {
        var path: String? = nil
        if let photoData = photoData {
            path = savePhoto(photoData)
        }
        
        let item = MemoryItem(
            id: UUID(),
            text: text,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitude: location.altitude,
            timestamp: Date(),
            photoPath: path
        )
        
        memories.append(item)
        saveMemories()
    }
}
```

## 3. Retrieving Memories (Geofencing / Semantic Mapping)

When the user asks *"Where is my car?"*, the AI triggers the `retrieve_memory` tool.

There are two ways to retrieve:
1. **Time-based**: "What was the last thing I asked you to remember today?" (Sort by Date).
2. **Semantic Context**: "Where did I park my Honda?"

To handle semantic context without a heavy Vector DB on iOS, the AI tool can pass the `query` ("parked car"). You then feed the query + the user's *entire memory bank* to a fast, cheap LLM pass (like Gemini 1.5 Flash or an SLM) to find the match, before responding to the user.

```swift
extension MemoryManager {
    func searchMemories(query: String) -> [MemoryItem] {
        // Naive text search for prototype
        let lowerQuery = query.lowercased()
        let results = memories.filter { $0.text.lowercased().contains(lowerQuery) }
        
        // Return top 5 most recent matches
        return Array(results.sorted(by: { $0.timestamp > $1.timestamp }).prefix(5))
    }
}
```

## 4. Injecting Relevant Local Memories

When the user walks into an area where they have stored a memory (e.g., they walk into a restaurant they reviewed three months ago), the app can **proactively inject** that context into the System Prompt.

```swift
// Check for memories within 50 meters of the user's current GPS location
func getNearbyMemoriesSystemPrompt(currentLocation: CLLocation) -> String {
    let nearby = memories.filter { memory in
        let memLoc = CLLocation(latitude: memory.latitude, longitude: memory.longitude)
        return currentLocation.distance(from: memLoc) < 50.0 // 50 meters
    }
    
    guard !nearby.isEmpty else { return "" }
    
    var prompt = "The user has past memories near this location:\n"
    for mem in nearby {
         prompt += "- On \(mem.timestamp.formatted()), the user noted: \(mem.text)\n"
    }
    return prompt
}
```

In your main AI routing code, prepend this block to the prompt:
*"What should I order here?"* -> The AI reads the nearby memory and says, *"Last time you were here, you said the Paella was amazing. Want to try that again?"*
